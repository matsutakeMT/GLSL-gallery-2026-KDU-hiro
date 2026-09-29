// site/shaders/<id>/shader.json を走査して site/shaders/list.json を生成する。
// site/shaders/list.json は .gitignore 対象 (GitHub Actions が生成する)。
import { readdir, readFile, writeFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const shadersDir = path.join(__dirname, "..", "site", "shaders");
const listPath = path.join(shadersDir, "list.json");

async function isDirectory(p) {
  try {
    return (await stat(p)).isDirectory();
  } catch {
    return false;
  }
}

async function main() {
  const entries = await readdir(shadersDir);
  const shaders = [];

  for (const entry of entries) {
    const dir = path.join(shadersDir, entry);
    if (!(await isDirectory(dir))) continue;

    const shaderJsonPath = path.join(dir, "shader.json");
    try {
      const raw = await readFile(shaderJsonPath, "utf-8");
      const meta = JSON.parse(raw);
      shaders.push({
        id: meta.id || entry,
        title: meta.title || entry,
        author: meta.author || "",
        description: meta.description || "",
        tags: meta.tags || [],
        created: meta.created || null,
      });
    } catch (err) {
      console.warn(`skip "${entry}": ${err.message}`);
    }
  }

  shaders.sort((a, b) => (a.created || "").localeCompare(b.created || ""));

  await writeFile(listPath, JSON.stringify(shaders, null, 2) + "\n", "utf-8");
  console.log(`wrote ${shaders.length} shader(s) to ${path.relative(process.cwd(), listPath)}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
