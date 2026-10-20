// --- TGIF! Shiny Golden Rain (Bitcoin & Ingot Edition) ---
// 最高の金曜日！強い光沢を放つ黄金（細長いインゴット、ビットコイン、リング）

#define MAX_STEPS 100
#define MAX_DIST 80.0
#define SURF_DIST 0.0015

// 2D回転行列
mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// 乱数生成
float hash(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43258.5453);
}

// 2Dボックス距離関数（ビットコイン模様用）
float sdBox2D(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// ビットコインの「₿」マークの2D距離関数
float sdBitcoinLogo(vec2 p) {
    // 少し右に傾ける（本物のロゴ風）
    p *= rot(0.2);
    p *= 1.15; // サイズ調整

    // 縦の2本線（上下に突き出る棒）
    float bars = min(
        sdBox2D(p - vec2(-0.07, 0.0), vec2(0.028, 0.34)),
        sdBox2D(p - vec2( 0.05, 0.0), vec2(0.028, 0.34))
    );

    // Bの左側の太い柱
    float spine = sdBox2D(p - vec2(-0.14, 0.0), vec2(0.045, 0.24));

    // Bの上下のループ（穴あきリング）
    vec2 pTop = p - vec2(-0.02, 0.115);
    pTop.x *= 0.85;
    float topLoop = abs(length(pTop) - 0.085) - 0.04;

    vec2 pBot = p - vec2(-0.01, -0.115);
    pBot.x *= 0.8;
    float botLoop = abs(length(pBot) - 0.095) - 0.042;

    float loops = max(min(topLoop, botLoop), -(p.x + 0.14));

    return min(min(bars, spine), loops);
}

// 細長く少し台形になったリアルなインゴット（金塊）
float sdIngot(vec3 p) {
    // 上に向かって少し細くなる台形（テーパー加工）
    p.xz *= 1.0 + p.y * 0.6;
    // 細長いプロポーションに変更（長さ0.95、高さ0.14、幅0.26）
    vec3 b = vec3(0.95, 0.14, 0.26);
    float r = 0.035;
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// ビットコイン模様付きのコイン
float sdCoin(vec3 p, float r, float h) {
    float rad = length(p.xz);
    
    // 外側の円柱
    vec2 d1 = abs(vec2(rad, p.y)) - vec2(r, h);
    float outCyl = min(max(d1.x, d1.y), 0.0) + length(max(d1, 0.0));
    
    // 内側の凹み
    vec2 d2 = abs(vec2(rad, p.y)) - vec2(r * 0.82, h * 1.5);
    float inCyl = min(max(d2.x, d2.y), 0.0) + length(max(d2, 0.0));
    
    // 中央のベース面
    vec2 dCenter = abs(vec2(rad, p.y)) - vec2(r * 0.82, h * 0.6);
    float center = min(max(dCenter.x, dCenter.y), 0.0) + length(max(dCenter, 0.0));

    float baseCoin = min(max(outCyl, -inCyl), center);

    // ビットコインのレリーフ（両面に浮き彫り）
    float dLogo2D = sdBitcoinLogo(p.xz / r) * r;
    vec2 dRelief = vec2(dLogo2D, abs(p.y) - h * 0.88);
    float relief = min(max(dRelief.x, dRelief.y), 0.0) + length(max(dRelief, 0.0)) - 0.005;

    // 側面のギザギザ（コインのエッジ加工）
    float ridges = sin(atan(p.z, p.x) * 40.0) * 0.004 * smoothstep(r * 0.9, r, rad);

    return min(baseCoin + ridges, relief);
}

// リング（指輪）
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
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
        // 40%の確率で細長いインゴット
        d = sdIngot(q);
    } else if (h < 0.78) {
        // 38%の確率でビットコイン
        vec3 cq = q;
        cq.yz *= rot(1.5708);
        d = sdCoin(cq, 0.65, 0.08);
    } else {
        // 22%の確率でリング
        d = sdTorus(q, vec2(0.5, 0.12));
    }

    return d;
}

// 法線（ビットコインの細かい模様をくっきり出すため精度を向上）
vec3 GetNormal(vec3 p) {
    vec2 e = vec2(0.002, 0);
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

    // --- 暖かくリッチな背景の生成 ---
    vec3 bgCol = mix(vec3(0.3, 0.05, 0.0), vec3(1.0, 0.6, 0.1), uv.y * 0.5 + 0.5);
    bgCol += vec3(1.0, 0.8, 0.3) * max(0.0, 1.0 - length(uv) * 1.2) * 0.5;

    // パーティクル（金粉）エフェクト
    float dust = fract(sin(dot(uv, vec2(12.9898, 78.233)) + iTime * 0.5) * 43258.5453);
    if (dust > 0.99) bgCol += vec3(1.0, 0.9, 0.5) * 2.0;

    // カメラ設定
    vec3 ro = vec3(0, 0, -6);
    vec3 rd = normalize(vec3(uv, 1.0));

    // カメラの微細な揺れ
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

    // オブジェクトにヒットした場合（鏡面ハイポリッシュ・ゴールド）
    if(d0 < MAX_DIST) {
        vec3 p = ro + rd * d0;
        vec3 n = GetNormal(p);
        vec3 v = -rd;

        // 2つの光源を設定して金属の立体感と輝きを強調
        vec3 lightDir1 = normalize(vec3(1.0, 2.0, -1.5));
        vec3 lightDir2 = normalize(vec3(-1.5, -1.0, -1.0));
        vec3 ref = reflect(rd, n);

        // 金属特有コントラストの強いスタジオ反射（暗い影と鋭い反射縞）
        float envBand = sin(ref.y * 8.0 + ref.x * 4.0) * 0.5 + 0.5;
        envBand = pow(envBand, 3.0);
        float envMask = smoothstep(-0.8, 0.8, ref.y);
        vec3 envCol = mix(vec3(0.18, 0.04, 0.0), vec3(1.3, 1.0, 0.45), envMask);
        envCol += vec3(1.0, 0.85, 0.4) * envBand * 0.9; // キラッと光る金属の映り込み

        // スペキュラハイライト（鋭い光沢＋豊かな広がりの2層構造）
        vec3 halfVec1 = normalize(lightDir1 + v);
        float specSharp = pow(max(dot(n, halfVec1), 0.0), 180.0); // ピカッと光る鋭い芯
        float specBroad = pow(max(dot(n, halfVec1), 0.0), 24.0);  // 金属のツヤ

        vec3 halfVec2 = normalize(lightDir2 + v);
        float specSub = pow(max(dot(n, halfVec2), 0.0), 64.0);    // 照り返しハイライト

        // フレネル（輪郭の強い輝き）
        float fresnel = pow(1.0 - max(dot(n, v), 0.0), 3.5);

        // ベースの黄金色（彩度とコントラストを高めた純金カラー）
        vec3 goldBase = vec3(1.0, 0.72, 0.12);

        // 色の合成
        col = goldBase * envCol * 1.25;
        col += vec3(1.0, 0.85, 0.35) * specBroad * 1.4;
        col += vec3(1.0, 0.98, 0.9)  * specSharp * 5.0; // 強烈な白い輝き
        col += vec3(1.0, 0.8, 0.3)   * specSub   * 1.2;
        col += vec3(1.0, 0.9, 0.5)   * fresnel   * 2.0;

        // 遠くのオブジェクトを背景色に溶け込ませる（フォグ）
        float fog = 1.0 - exp(-0.003 * d0 * d0);
        col = mix(col, bgCol, fog);
    }

    // 全体の色調補正（ガンマ補正＋コントラスト）
    col = pow(col, vec3(0.4545));
    col = smoothstep(0.0, 1.05, col);

    fragColor = vec4(col, 1.0);
}