// docs/shaders/list.json の各シェーダーを headless Chromium で開き、
// docs/assets/thumbs/<id>.png を生成する (.gitignore 対象)。
import { readFile, mkdir } from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const docsDir = path.join(__dirname, "..", "docs");
const listPath = path.join(docsDir, "shaders", "list.json");
const thumbsDir = path.join(docsDir, "assets", "thumbs");

const THUMB_WIDTH = 480;
const THUMB_HEIGHT = 270;
const SETTLE_MS = 600; // let the animation run briefly before capturing a frame
const PER_SHADER_TIMEOUT_MS = 30000; // one stuck/broken shader must not hang the whole run

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`timed out after ${ms}ms: ${label}`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

const MIME_TYPES = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".json": "application/json",
  ".css": "text/css",
  ".glsl": "text/plain",
  ".png": "image/png",
};

// view.html loads its JS as an ES module, which browsers refuse to fetch
// over file://. Serve docs/ over plain HTTP so puppeteer can actually run it.
function startServer(rootDir) {
  const server = http.createServer(async (req, res) => {
    try {
      const urlPath = decodeURIComponent(req.url.split("?")[0]);
      const filePath = path.join(rootDir, urlPath === "/" ? "index.html" : urlPath);
      const data = await readFile(filePath);
      res.writeHead(200, { "Content-Type": MIME_TYPES[path.extname(filePath)] || "application/octet-stream" });
      res.end(data);
    } catch {
      res.writeHead(404);
      res.end("not found");
    }
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function main() {
  const list = JSON.parse(await readFile(listPath, "utf-8"));
  if (!list.length) {
    console.log("no shaders to render");
    return;
  }

  await mkdir(thumbsDir, { recursive: true });

  const server = await startServer(docsDir);
  const { port } = server.address();

  // Headless Chromium has no GPU, so WebGL needs to be forced onto SwiftShader's
  // software rasterizer; without these flags the canvas silently renders black.
  // --no-sandbox / --disable-dev-shm-usage are needed for Chrome to launch at
  // all inside GitHub Actions' containerized runners.
  const browser = await puppeteer.launch({
    args: [
      "--enable-unsafe-swiftshader",
      "--use-gl=angle",
      "--use-angle=swiftshader",
      "--no-sandbox",
      "--disable-dev-shm-usage",
    ],
  });
  const failed = [];
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: THUMB_WIDTH, height: THUMB_HEIGHT });

    for (const shader of list) {
      try {
        await withTimeout(renderThumb(page, port, shader), PER_SHADER_TIMEOUT_MS, shader.id);
      } catch (err) {
        // One broken/slow shader must not block the rest from getting thumbnails.
        console.warn(`skip thumb for "${shader.id}": ${err.message}`);
        failed.push(shader.id);
      }
    }
  } finally {
    await browser.close();
    server.close();
  }

  if (failed.length) {
    console.warn(`${failed.length}/${list.length} thumbnail(s) failed: ${failed.join(", ")}`);
  }
}

async function renderThumb(page, port, shader) {
  const url = `http://127.0.0.1:${port}/view.html?id=${encodeURIComponent(shader.id)}`;
  await page.goto(url, { waitUntil: "networkidle0" });
  await new Promise((r) => setTimeout(r, SETTLE_MS));

  // Hide the viewer's UI chrome (back link, info box) so the thumbnail
  // shows only the rendered shader.
  await page.evaluate(() => {
    document.querySelectorAll(".viewer .back, .viewer .info").forEach((el) => {
      el.style.display = "none";
    });
  });

  const canvas = await page.$("#canvas");
  const outPath = path.join(thumbsDir, `${shader.id}.png`);
  await canvas.screenshot({ path: outPath });
  console.log(`thumb: ${shader.id} -> ${path.relative(process.cwd(), outPath)}`);
}

// Individual failures are logged above and don't fail the process: a broken
// shader should degrade to a missing thumbnail, not block every other
// shader's thumbnail (and the whole Pages deploy) from shipping.
main().catch((err) => {
  console.error(err);
  process.exit(1);
});
