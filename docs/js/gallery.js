async function loadList() {
  const res = await fetch("shaders/list.json", { cache: "no-store" });
  if (!res.ok) return [];
  return res.json();
}

function cardTemplate(shader) {
  const a = document.createElement("a");
  a.className = "card";
  a.href = `view.html?id=${encodeURIComponent(shader.id)}`;

  const thumbWrap = document.createElement("div");
  thumbWrap.className = "thumb";

  const img = document.createElement("img");
  img.loading = "lazy";
  img.alt = shader.title || shader.id;
  img.src = `assets/thumbs/${shader.id}.png`;
  img.onerror = () => {
    img.remove();
    thumbWrap.textContent = "";
  };
  thumbWrap.appendChild(img);

  const meta = document.createElement("div");
  meta.className = "meta";
  meta.innerHTML = `
    <div class="title">${shader.title || shader.id}</div>
    <div class="author">${shader.author || ""}</div>
  `;

  a.appendChild(thumbWrap);
  a.appendChild(meta);
  return a;
}

async function main() {
  const grid = document.getElementById("grid");
  const shaders = await loadList();

  if (!shaders.length) {
    grid.innerHTML = '<p class="empty">まだシェーダーが登録されていません。docs/shaders/ に追加してください。</p>';
    return;
  }

  for (const shader of shaders) {
    grid.appendChild(cardTemplate(shader));
  }
}

main();
