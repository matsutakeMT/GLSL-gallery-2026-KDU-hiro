import { createRenderer } from "./engine/engine.js";

function getShaderId() {
  const params = new URLSearchParams(location.search);
  return params.get("id");
}

function setInfo(info, { title, author, description }) {
  info.innerHTML = "";

  const heading = document.createElement("div");
  heading.className = "info-heading";
  heading.textContent = author ? `${title} — ${author}` : title;
  info.appendChild(heading);

  if (description) {
    const desc = document.createElement("div");
    desc.className = "info-description";
    desc.textContent = description;
    info.appendChild(desc);
  }
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

  setInfo(info, { title: meta.title || id, author: meta.author, description: meta.description });

  const renderer = createRenderer(canvas, source, { pixelRatio: window.devicePixelRatio || 1 });
  renderer.start();
}

main();
