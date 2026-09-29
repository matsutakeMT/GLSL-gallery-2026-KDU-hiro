// docs/shaders/list.json の各シェーダーを headless Chromium で開き、
// docs/assets/thumbs/<id>.png を生成する (.gitignore 対象)。
import { readFile, mkdir } from "node:fs/promises";
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

async function main() {
  const list = JSON.parse(await readFile(listPath, "utf-8"));
  if (!list.length) {
    console.log("no shaders to render");
    return;
  }

  await mkdir(thumbsDir, { recursive: true });

  const browser = await puppeteer.launch();
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: THUMB_WIDTH, height: THUMB_HEIGHT });

    for (const shader of list) {
      const url = `file://${path.join(docsDir, "view.html")}?id=${encodeURIComponent(shader.id)}`;
      await page.goto(url, { waitUntil: "networkidle0" });
      await new Promise((r) => setTimeout(r, SETTLE_MS));

      const outPath = path.join(thumbsDir, `${shader.id}.png`);
      await page.screenshot({ path: outPath });
      console.log(`thumb: ${shader.id} -> ${path.relative(process.cwd(), outPath)}`);
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
