// docs/shaders/list.json の各シェーダーを 1920x1080 / 15秒・MP4 に変換し
// docs/movie/<id>.mp4 として書き出す。要 ffmpeg (PATH に通っていること)。
//
// 各フレームは requestAnimationFrame 任せの実時間録画ではなく、
// view.html?capture=1 が公開する window.__renderer.renderOnce(t) を
// 固定タイムステップで直接呼び出して撮影するので、マシンの速度に関わらず
// 常に同じ滑らかさの動画になる(1フレームの描画がどれだけ遅くても結果は同じ)。
import { readFile, mkdir } from "node:fs/promises";
import http from "node:http";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const docsDir = path.join(__dirname, "..", "docs");
const listPath = path.join(docsDir, "shaders", "list.json");
const movieDir = path.join(docsDir, "movie");

const WIDTH = 1920;
const HEIGHT = 1080;
const FPS = Number(process.env.MOVIE_FPS) || 30;
const DURATION_SEC = Number(process.env.MOVIE_DURATION) || 5;
const TOTAL_FRAMES = Math.round(FPS * DURATION_SEC);
const PER_SHADER_TIMEOUT_MS = 20 * 60 * 1000; // full-HD software rendering can be slow

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

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`timed out after ${ms}ms: ${label}`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function checkFfmpeg() {
  return new Promise((resolve, reject) => {
    const proc = spawn("ffmpeg", ["-version"]);
    proc.on("error", () =>
      reject(
        new Error(
          "ffmpeg が見つかりません。インストールして PATH に通してから再実行してください " +
            "(例: winget install Gyan.FFmpeg / choco install ffmpeg / apt-get install ffmpeg / brew install ffmpeg)。"
        )
      )
    );
    proc.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg -version exited with code ${code}`))));
  });
}

async function encodeMovie(page, port, shader) {
  const url = `http://127.0.0.1:${port}/view.html?id=${encodeURIComponent(shader.id)}&capture=1`;
  await page.goto(url, { waitUntil: "networkidle0" });
  await page.waitForFunction("window.__renderer !== undefined", { timeout: 15000 });

  const outPath = path.join(movieDir, `${shader.id}.mp4`);
  const ffmpeg = spawn(
    "ffmpeg",
    [
      "-y",
      "-f", "image2pipe",
      "-vcodec", "mjpeg",
      "-r", String(FPS),
      "-i", "-",
      "-c:v", "libx264",
      "-pix_fmt", "yuv420p",
      "-movflags", "+faststart",
      "-r", String(FPS),
      outPath,
    ],
    { stdio: ["pipe", "ignore", "pipe"] }
  );

  let ffmpegErr = "";
  ffmpeg.stderr.on("data", (d) => (ffmpegErr += d.toString()));
  const ffmpegDone = new Promise((resolve, reject) => {
    ffmpeg.on("error", reject);
    ffmpeg.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg exited with ${code}: ${ffmpegErr.slice(-2000)}`))));
  });

  for (let i = 0; i < TOTAL_FRAMES; i++) {
    const t = i / FPS;
    await page.evaluate((time) => window.__renderer.renderOnce(time), t);
    const frame = await page.screenshot({ type: "jpeg", quality: 90 });
    if (!ffmpeg.stdin.write(frame)) {
      await new Promise((resolve) => ffmpeg.stdin.once("drain", resolve));
    }
  }
  ffmpeg.stdin.end();
  await ffmpegDone;

  console.log(`movie: ${shader.id} -> ${path.relative(process.cwd(), outPath)} (${TOTAL_FRAMES} frames @ ${FPS}fps, ${DURATION_SEC}s)`);
}

async function main() {
  await checkFfmpeg();

  const list = JSON.parse(await readFile(listPath, "utf-8"));
  if (!list.length) {
    console.log("no shaders to render");
    return;
  }

  await mkdir(movieDir, { recursive: true });

  const server = await startServer(docsDir);
  const { port } = server.address();

  // Headless Chromium has no GPU, so WebGL needs to be forced onto SwiftShader's
  // software rasterizer; --no-sandbox / --disable-dev-shm-usage are needed for
  // Chrome to launch at all inside GitHub Actions' containerized runners.
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
    await page.setViewport({ width: WIDTH, height: HEIGHT, deviceScaleFactor: 1 });

    for (const shader of list) {
      try {
        await withTimeout(encodeMovie(page, port, shader), PER_SHADER_TIMEOUT_MS, shader.id);
      } catch (err) {
        // One broken/slow shader must not block the rest from getting a movie.
        console.warn(`skip movie for "${shader.id}": ${err.message}`);
        failed.push(shader.id);
      }
    }
  } finally {
    await browser.close();
    server.close();
  }

  if (failed.length) {
    console.warn(`${failed.length}/${list.length} movie(s) failed: ${failed.join(", ")}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
