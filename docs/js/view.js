import { createRenderer } from "./engine/engine.js";

function getShaderId() {
  const params = new URLSearchParams(location.search);
  return params.get("id");
}

async function main() {
  const id = getShaderId();
  const info = document.getElementById("info");
  const canvas = document.getElementById("canvas");

  if (!id) {
    info.textContent = "シェーダーIDが指定されていません。";
    return;
  }

  const shaderJsonRes = await fetch(`shaders/${id}/shader.json`, { cache: "no-store" });
  if (!shaderJsonRes.ok) {
    info.textContent = `shader.json が見つかりません: ${id}`;
    return;
  }
  const meta = await shaderJsonRes.json();

  const imagePath = meta.buffers?.image || "image.glsl";
  const glslRes = await fetch(`shaders/${id}/${imagePath}`, { cache: "no-store" });
  if (!glslRes.ok) {
    info.textContent = `シェーダーソースが見つかりません: ${imagePath}`;
    return;
  }
  const source = await glslRes.text();

  info.textContent = `${meta.title || id} — ${meta.author || ""}`;

  const renderer = createRenderer(canvas, source, { pixelRatio: window.devicePixelRatio || 1 });
  renderer.start();
}

main();
