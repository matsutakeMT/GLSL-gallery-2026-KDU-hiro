# GLSL Gallery 2026 (KDU hiro)

学生の GLSL 作品を並べて公開するギャラリー。`docs/` 配下だけが GitHub Pages で公開される。

## 構成

```
docs/                       # ← ここだけが公開される
├── index.html              # ギャラリー(一覧)ページ
├── view.html                # 個別シェーダーの表示ページ
├── css/
├── js/
│   └── engine/              # WebGL レンダラー本体
├── shaders/
│   ├── list.json            # ※Actions が生成(コミットしない)
│   └── <id>/
│       ├── shader.json
│       └── image.glsl ...
└── assets/
    ├── textures/
    └── thumbs/               # ※Actions が生成(コミットしない)

scripts/
├── build-list.mjs           # docs/shaders を走査して list.json を生成
└── build-thumbs.mjs         # puppeteer でサムネイル画像を生成

.github/workflows/deploy.yml # push時に list.json / thumbs をビルドして GitHub Pages に公開
```

## シェーダーを追加する

1. `docs/shaders/<id>/` ディレクトリを作る(`<id>` は URL に使われる英数字推奨)。
2. `shader.json` を書く:

```json
{
  "id": "your-id",
  "title": "作品タイトル",
  "author": "作者名",
  "description": "説明",
  "tags": ["tag1", "tag2"],
  "created": "2026-09-29",
  "buffers": { "image": "image.glsl" }
}
```

3. `image.glsl` に Shadertoy 形式のフラグメントシェーダーを書く(`mainImage(out vec4 fragColor, in vec2 fragCoord)` を実装)。利用可能な uniform は `iResolution` / `iTime` / `iMouse`。

## ローカルでの確認

```bash
npm install
npm run build:list    # docs/shaders/list.json を生成
npm run build:thumbs   # docs/assets/thumbs/*.png を生成 (puppeteer が必要)
```

その後 `docs/` を任意の静的サーバーで配信して確認する(例: `npx serve docs`)。

## デプロイ

`main` ブランチへの push で GitHub Actions が `list.json` とサムネイルを再生成し、`docs/` を GitHub Pages にデプロイする。リポジトリの Settings → Pages で Source を "GitHub Actions" に設定しておくこと。
