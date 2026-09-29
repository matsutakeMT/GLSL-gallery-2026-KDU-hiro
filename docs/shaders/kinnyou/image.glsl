// --- TGIF! Warm Golden Rain ---
// 最高の金曜日！暖かな光と降り注ぐ黄金（インゴット、コイン、リング）
// Pure GLSL, fully functional with fixed sdCoin SDF.

#define MAX_STEPS 100
#define MAX_DIST 80.0
#define SURF_DIST 0.002

// 2D回転行列
mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// 乱数生成
float hash(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43258.5453);
}

// 丸みを帯びたインゴット（金塊）
float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

// フチのあるリアルなコイン（修正済み）
float sdCoin(vec3 p, float r, float h) {
    // 外側の円柱
    vec2 d1 = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    float outCyl = min(max(d1.x, d1.y), 0.0) + length(max(d1, 0.0));
    // 内側の凹み
    vec2 d2 = abs(vec2(length(p.xz), p.y)) - vec2(r * 0.8, h * 1.5);
    float inCyl = min(max(d2.x, d2.y), 0.0) + length(max(d2, 0.0));
    // 中央
    vec2 dCenter = abs(vec2(length(p.xz), p.y)) - vec2(r * 0.7, h * 0.6);
    float center = min(max(dCenter.x, dCenter.y), 0.0) + length(max(dCenter, 0.0));

    return min(max(outCyl, -inCyl), center);
}

// リング（指輪）
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz)-t.x,p.y);
    return length(q)-t.y;
}

// 空間全体の距離関数（グリッド状に配置）
float GetDist(vec3 p) {
    vec3 rep = vec3(4.0, 5.0, 4.0);
    vec3 q = p;

    // 物体が上から下へ落下するアニメーション
    q.y -= iTime * 3.5;

    // 空間をグリッド状に分割
    vec3 id = floor(q / rep);
    q = mod(q, rep) - 0.5 * rep;

    // グリッドごとにランダムな値を生成
    float h = hash(id);

    // ランダムな方向に回転
    q.xy *= rot(iTime * (h * 2.0 - 1.0) * 1.5 + h * 10.0);
    q.xz *= rot(iTime * (hash(id + 1.0) * 2.0 - 1.0) * 1.5 + h * 20.0);

    float d = MAX_DIST;

    // 乱数（0.0〜1.0）によって出現するアイテムを分岐
    if (h < 0.4) {
        // 40%の確率でインゴット
        d = sdRoundBox(q, vec3(0.7, 0.15, 0.35), 0.05);
    } else if (h < 0.75) {
        // 35%の確率でコイン
        vec3 cq = q;
        cq.yz *= rot(1.5708);
        d = sdCoin(cq, 0.6, 0.08);
    } else {
        // 25%の確率でリング
        d = sdTorus(q, vec2(0.5, 0.12));
    }

    return d;
}

// 法線（光の反射計算用）
vec3 GetNormal(vec3 p) {
    vec2 e = vec2(0.01, 0);
    return normalize(vec3(
        GetDist(p + e.xyy) - GetDist(p - e.xyy),
        GetDist(p + e.yxy) - GetDist(p - e.yxy),
        GetDist(p + e.yyx) - GetDist(p - e.yyx)
    ));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // ピクセル座標の正規化
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // --- 暖かくリッチな背景の生成（グローとダスト付き） ---
    // 上が明るいオレンジ、下が暗い琥珀色のグラデーション
    vec3 bgCol = mix(vec3(0.3, 0.05, 0.0), vec3(1.0, 0.6, 0.1), uv.y * 0.5 + 0.5);

    // 画面中央をぼんやり光らせる
    bgCol += vec3(1.0, 0.8, 0.3) * max(0.0, 1.0 - length(uv) * 1.2) * 0.5;

    // パーティクル（金粉）エフェクト
    float dust = fract(sin(dot(uv, vec2(12.9898, 78.233)) + iTime * 0.5) * 43258.5453);
    if (dust > 0.99) bgCol += vec3(1.0, 0.9, 0.5) * 2.0;

    // カメラ設定
    vec3 ro = vec3(0, 0, -6);
    vec3 rd = normalize(vec3(uv, 1.0));

    // カメラの微細な揺れ（浮遊感）
    ro.x += sin(iTime * 0.4) * 0.5;
    ro.y += cos(iTime * 0.3) * 0.3;
    rd.xy *= rot(sin(iTime * 0.2) * 0.1);

    // レイマーチング
    float d0 = 0.0;
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d0;
        float dS = GetDist(p);
        d0 += dS;
        if(d0 > MAX_DIST || abs(dS) < SURF_DIST) break;
    }

    vec3 col = bgCol;

    // オブジェクトにヒットした場合（リッチなマットゴールド）
    if(d0 < MAX_DIST) {
        vec3 p = ro + rd * d0;
        vec3 n = GetNormal(p);
        vec3 v = -rd;

        // ライティング
        vec3 lightDir = normalize(vec3(1.0, 2.0, -1.0));
        vec3 ref = reflect(rd, n);

        // 環境反射マスク
        float envMask = smoothstep(-1.0, 1.0, ref.y);
        vec3 envCol = mix(vec3(0.4, 0.1, 0.0), vec3(1.0, 0.9, 0.5), envMask);

        // スペキュラハイライト
        vec3 halfVec = normalize(lightDir + v);
        float spec = pow(max(dot(n, halfVec), 0.0), 64.0);

        // フレネル（輪郭光）
        float fresnel = pow(1.0 - max(dot(n, v), 0.0), 4.0);

        // ベースの黄金色
        vec3 goldBase = vec3(1.0, 0.75, 0.15);

        // 色の合成
        col = goldBase * envCol * 1.2;
        col += vec3(1.0, 0.9, 0.7) * spec * 2.5;
        col += vec3(1.0, 0.8, 0.3) * fresnel * 1.5;

        // 遠くのオブジェクトを背景色に溶け込ませる（フォグ）
        float fog = 1.0 - exp(-0.003 * d0 * d0);
        col = mix(col, bgCol, fog);
    }

    // 全体の色調補正（ガンマ補正＋コントラスト）
    col = pow(col, vec3(0.4545));
    col = smoothstep(0.0, 1.1, col);

    fragColor = vec4(col, 1.0);
}
