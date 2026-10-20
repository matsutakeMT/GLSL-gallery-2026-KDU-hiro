// --- TGIF! Luxury Mirror Gold & Detailed Bitcoin Edition ---
// 最高の金曜日！高精細ビットコイン（回路基板＆鏡面₿ロゴ）と純金インゴット

#define MAX_STEPS 110
#define MAX_DIST 80.0
#define SURF_DIST 0.0012

// 2D回転行列
mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// 乱数生成（3D / 2D）
float hash(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 2Dボックス距離関数
float sdBox2D(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// --- 高精細ビットコイン「₿」ロゴの2D距離関数 ---
float sdBitcoinLogo(vec2 p) {
    // 本物のコインのようにわずかに右へ傾ける
    p *= rot(-0.08);
    p *= 1.05;

    // 1. 左側の太い縦柱
    float spine = sdBox2D(p - vec2(-0.14, 0.0), vec2(0.06, 0.33));

    // 2. 左側上下のセリフ（角張った出っ張り）
    float serifTop = sdBox2D(p - vec2(-0.175,  0.285), vec2(0.095, 0.045));
    float serifBot = sdBox2D(p - vec2(-0.175, -0.285), vec2(0.095, 0.045));
    float serifs = min(serifTop, serifBot);

    // 3. Bの上下2つのループ（下側を少し大きく）
    vec2 pTop = p - vec2(-0.02, 0.15);
    pTop.x *= 0.82;
    float topOuter = length(pTop) - 0.18;
    float topInner = length(pTop - vec2(0.01, 0.0)) - 0.082;
    float topLoop = max(topOuter, -topInner);

    vec2 pBot = p - vec2(0.00, -0.155);
    pBot.x *= 0.78;
    float botOuter = length(pBot) - 0.195;
    float botInner = length(pBot - vec2(0.01, 0.0)) - 0.092;
    float botLoop = max(botOuter, -botInner);

    // ループの左側を柱の位置でカットし、中央の仕切りバーを繋ぐ
    float midBar = sdBox2D(p - vec2(-0.04, 0.0), vec2(0.12, 0.042));
    float loops = max(min(min(topLoop, botLoop), midBar), -(p.x + 0.14));

    // 4. 上下に突き出る2本の縦バー（Bの穴の内部は貫通させない）
    float bar1 = sdBox2D(p - vec2(-0.065, 0.0), vec2(0.036, 0.45));
    float bar2 = sdBox2D(p - vec2( 0.065, 0.0), vec2(0.036, 0.45));
    float bars = max(min(bar1, bar2), 0.27 - abs(p.y));

    return min(min(spine, serifs), min(loops, bars));
}

// --- コイン表面の精密ディテール（回路基板模様＋外周刻印＋₿ロゴ） ---
// 戻り値 x: 高さの凹凸, y: マテリアル種別(1.0=鏡面, 0.0=彫刻溝)
vec2 getCoinSurface(vec2 uv) {
    float rad = length(uv);
    if (rad > 1.0) return vec2(0.0, 1.0);

    float dB = sdBitcoinLogo(uv);

    // 外周の鏡面リム（縁）
    if (rad > 0.88) {
        float rimBevel = smoothstep(0.88, 0.90, rad) * (1.0 - smoothstep(0.98, 1.0, rad));
        return vec2(0.85 + rimBevel * 0.15, 1.0);
    }

    // 「₿」ロゴ本体（一段高い鏡面レリーフ＋細い二重フチ取り）
    if (dB < 0.0) {
        float edgeRim = smoothstep(-0.025, -0.008, dB) * (1.0 - smoothstep(-0.008, 0.0, dB));
        return vec2(0.90 + edgeRim * 0.15, 1.0);
    }

    // 外周のテキスト＆ギアブロック刻印帯 (0.76 < rad <= 0.88)
    float ang = atan(uv.y, uv.x);
    if (rad > 0.76) {
        float ring1 = smoothstep(0.01, 0.0, abs(rad - 0.865));
        float ring2 = smoothstep(0.01, 0.0, abs(rad - 0.775));
        // 文字・破線ブロック風の細かい凹凸
        float ticks = step(0.35, sin(ang * 48.0)) * smoothstep(0.79, 0.80, rad) * smoothstep(0.85, 0.84, rad);
        float subTicks = step(0.1, sin(ang * 96.0 + rad * 40.0)) * 0.5;
        float h = 0.25 + (ring1 + ring2) * 0.35 + ticks * subTicks * 0.35;
        return vec2(h, 0.3);
    }

    // 内側フィールド：回路基板（サーキット）の同心円ライン＆ICパッド模様
    float concentric = sin(rad * 160.0);
    float sector = floor((ang + 3.14159) * 12.0 / 6.28318);
    float trackGate = hash2(vec2(floor(rad * 25.0), sector));

    // 角度ごとに途切れる同心円トラックと放射状の回路ライン
    float tracks = smoothstep(-0.2, 0.4, concentric) * step(0.25, trackGate);
    float radialLines = smoothstep(0.97, 0.995, cos(ang * 24.0)) * step(0.6, trackGate);

    // Bの穴の内部や周囲にある細かい縦ストライプ回路
    float vLines = smoothstep(0.3, 0.7, sin(uv.x * 140.0)) * step(0.5, sin(uv.y * 60.0));
    float innerMask = smoothstep(0.45, 0.2, rad);

    float circuit = mix(max(tracks, radialLines), vLines, innerMask * 0.6);

    // ロゴのすぐ周囲の彫り込み（ロゴをくっきり浮き上がらせる）
    float logoShadow = smoothstep(0.0, 0.03, dB);

    float h = (0.15 + circuit * 0.38) * logoShadow;
    return vec2(h, 0.2 + circuit * 0.4);
}

// --- 細長く美しい台形インゴット（欠け防止補正済み） ---
float sdIngot(vec3 p) {
    // 上下に向かってわずかに絞る台形（リップシッツ補正で欠けを完全に防止）
    vec3 q = p;
    q.xz *= 1.0 + clamp(q.y, -0.2, 0.2) * 0.45;
    vec3 b = vec3(0.98, 0.14, 0.30);
    float r = 0.04;
    vec3 d = abs(q) - b;
    return (length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0) - r) * 0.75;
}

// インゴット表面の刻印と曲面感（ピロー効果）
float getIngotBump(vec3 p) {
    vec2 uv = p.xz / vec2(0.98, 0.30);
    if (abs(uv.x) > 0.92 || abs(uv.y) > 0.88) return 0.0;

    // 外枠の刻印ライン
    vec2 dEdge = abs(uv) - vec2(0.82, 0.72);
    float border = smoothstep(0.04, 0.0, abs(max(dEdge.x, dEdge.y)));

    // 純金スタンプ（円形ロゴ＋横バー刻印）
    float stampCircle = smoothstep(0.03, 0.0, abs(length((uv - vec2(-0.48, 0.0)) * vec2(1.8, 0.9)) - 0.28));
    float bars = step(abs(uv.y), 0.35) * step(abs(uv.x - 0.15), 0.35) * step(0.2, sin(uv.x * 35.0));

    return -(border * 0.5 + stampCircle * 0.5 + bars * 0.35);
}

// --- コインの基本形状（滑らかな円盤＋側面ギザギザ） ---
float sdCoinBase(vec3 p, float r, float h) {
    float rad = length(p.xz);
    vec2 d = abs(vec2(rad, p.y)) - vec2(r, h);
    float cyl = min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - 0.008;

    // 側面のギザギザ（エッジ部分のみに細かい刻みを入れる）
    float edgeMask = smoothstep(r * 0.96, r, rad) * smoothstep(h, h * 0.7, abs(p.y));
    float ridges = sin(atan(p.z, p.x) * 90.0) * 0.0025 * edgeMask;

    // 表面のベース凹み
    float faceIndent = smoothstep(r * 0.89, r * 0.86, rad) * 0.008;

    return cyl + ridges + faceIndent;
}

// リング（指輪）
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// 空間のローカル座標とオブジェクト種別を取得するヘルパー
void getObjectSpace(vec3 p, out vec3 localP, out int objType) {
    vec3 rep = vec3(4.2, 5.0, 4.2);
    vec3 q = p;
    q.y -= iTime * 3.2;

    vec3 id = floor(q / rep);
    q = mod(q, rep) - 0.5 * rep;

    float h = hash(id);
    q.xy *= rot(iTime * (h * 2.0 - 1.0) * 1.3 + h * 10.0);
    q.xz *= rot(iTime * (hash(id + 1.0) * 2.0 - 1.0) * 1.3 + h * 20.0);

    if (h < 0.42) {
        objType = 1; // インゴット
        localP = q;
    } else if (h < 0.82) {
        objType = 2; // ビットコイン
        vec3 cq = q;
        cq.yz *= rot(1.5708);
        localP = cq;
    } else {
        objType = 3; // リング
        localP = q;
    }
}

// 距離関数
float GetDist(vec3 p) {
    vec3 localP;
    int objType;
    getObjectSpace(p, localP, objType);

    if (objType == 1) {
        return sdIngot(localP);
    } else if (objType == 2) {
        return sdCoinBase(localP, 0.72, 0.075);
    } else {
        return sdTorus(localP, vec2(0.52, 0.13));
    }
}

// 基本法線の計算
vec3 GetNormal(vec3 p) {
    vec2 e = vec2(0.0015, 0.0);
    return normalize(vec3(
        GetDist(p + e.xyy) - GetDist(p - e.xyy),
        GetDist(p + e.yxy) - GetDist(p - e.yxy),
        GetDist(p + e.yyx) - GetDist(p - e.yyx)
    ));
}

// --- スタジオ金属反射（黒く締まった影と鋭い純金ハイライト） ---
vec3 getGoldReflection(vec3 ref, float roughness) {
    // 金属特有の明暗ストリップ（鏡面コントラスト）
    float strip1 = pow(sin(ref.y * 6.0 + ref.x * 3.0) * 0.5 + 0.5, mix(5.0, 1.5, roughness));
    float strip2 = pow( max(0.0, sin(ref.x * 5.0 - ref.z * 3.0)), mix(8.0, 2.0, roughness));
    float skyGrad = smoothstep(-0.9, 0.9, ref.y);

    // 暗いアンバーの影（これがあることで金が白飛びせず鏡面に見える）
    vec3 darkShadow = vec3(0.06, 0.015, 0.00);
    vec3 midGold    = vec3(0.95, 0.62, 0.08);
    vec3 brightGold = vec3(1.45, 1.15, 0.55);

    vec3 env = mix(darkShadow, midGold, skyGrad * 0.75 + 0.15);
    env = mix(env, brightGold, strip1 * 0.75);
    env += vec3(1.2, 0.95, 0.45) * strip2 * 0.55;
    return env;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // --- 暖かくリッチな背景の生成 ---
    vec3 bgCol = mix(vec3(0.28, 0.05, 0.0), vec3(0.98, 0.58, 0.1), uv.y * 0.5 + 0.5);
    bgCol += vec3(1.0, 0.8, 0.3) * max(0.0, 1.0 - length(uv) * 1.15) * 0.45;

    // 金粉パーティクル
    float dust = fract(sin(dot(uv, vec2(12.9898, 78.233)) + iTime * 0.5) * 43758.5453);
    if (dust > 0.992) bgCol += vec3(1.0, 0.9, 0.5) * 1.8;

    // カメラ設定
    vec3 ro = vec3(0.0, 0.0, -6.0);
    vec3 rd = normalize(vec3(uv, 1.0));

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

    if(d0 < MAX_DIST) {
        vec3 p = ro + rd * d0;
        vec3 n = GetNormal(p);
        vec3 v = -rd;

        vec3 localP;
        int objType;
        getObjectSpace(p, localP, objType);

        float roughness = 0.08;
        float cavityAO  = 1.0;

        // --- オブジェクト別の精密バンプ（法線ディテール）と質感設定 ---
        if (objType == 2 && abs(localP.y) > 0.055) {
            // 【ビットコイン表面】
            vec2 coinUV = localP.xz / 0.72;
            if (localP.y < 0.0) coinUV.x = -coinUV.x; // 裏面も正しい向きに刻印

            float eps = 0.004;
            vec2 c0 = getCoinSurface(coinUV);
            float hx = getCoinSurface(coinUV + vec2(eps, 0.0)).x - c0.x;
            float hy = getCoinSurface(coinUV + vec2(0.0, eps)).x - c0.x;

            float side = sign(localP.y);
            vec3 bumpN = normalize(vec3(-hx * side * 8.5, side, -hy * 8.5));
            // ワールド空間へ回転を戻すため法線にブレンド
            n = normalize(n + (bumpN - vec3(0.0, side, 0.0)) * 0.65);

            // 鏡面部分（₿ロゴ・外周リム）はツルツル、背景の回路溝は陰影を深くする
            roughness = mix(0.32, 0.03, c0.y);
            cavityAO  = mix(0.55, 1.05, c0.x);

            // 平面でも鏡面の黒〜金のコントラストが出るよう微細な曲面反射を付与
            n = normalize(n + vec3(coinUV.x, 0.0, coinUV.y) * 0.12);

        } else if (objType == 1) {
            // 【金インゴット】
            // 鋳造インゴット特有の膨らみ（ピロー効果）で平面にも美しい鏡面の帯を走らせる
            n = normalize(n + localP * vec3(0.28, 0.45, 0.55));

            if (abs(localP.y) > 0.12) {
                float eps = 0.008;
                float b0 = getIngotBump(localP);
                float bx = getIngotBump(localP + vec3(eps, 0.0, 0.0)) - b0;
                float bz = getIngotBump(localP + vec3(0.0, 0.0, eps)) - b0;
                n = normalize(n + vec3(-bx, 0.0, -bz) * 4.0);
                cavityAO = 1.0 + b0 * 0.45;
            }
            roughness = 0.04; // 超鏡面仕上げ
        } else {
            // 【ゴールドリング】
            roughness = 0.03;
        }

        // --- ライティング＆高光沢メタリック合成 ---
        vec3 lightDir1 = normalize(vec3( 1.2,  2.0, -1.5));
        vec3 lightDir2 = normalize(vec3(-1.5, -1.2, -1.0));
        vec3 ref = reflect(rd, n);

        // 環境反射カラー
        vec3 envCol = getGoldReflection(ref, roughness);

        // スペキュラハイライト
        vec3 halfVec1 = normalize(lightDir1 + v);
        float specPower = mix(220.0, 32.0, roughness);
        float specSharp = pow(max(dot(n, halfVec1), 0.0), specPower);
        float specBroad = pow(max(dot(n, halfVec1), 0.0), 16.0);

        vec3 halfVec2 = normalize(lightDir2 + v);
        float specSub = pow(max(dot(n, halfVec2), 0.0), 48.0);

        // フレネル（輪郭の鋭い輝き）
        float fresnel = pow(1.0 - max(dot(n, v), 0.0), 3.0);

        // 純金ベースカラー
        vec3 goldBase = vec3(1.0, 0.74, 0.14);

        col = goldBase * envCol * cavityAO;
        col += vec3(1.0, 0.82, 0.28) * specBroad * 0.85 * cavityAO;
        col += vec3(1.0, 0.98, 0.88) * specSharp * mix(4.5, 1.2, roughness);
        col += vec3(1.0, 0.80, 0.30) * specSub   * 0.9;
        col += vec3(1.0, 0.92, 0.50) * fresnel   * 1.4;

        // 遠くのオブジェクトを背景色に溶け込ませる（フォグ）
        float fog = 1.0 - exp(-0.0028 * d0 * d0);
        col = mix(col, bgCol, fog);
    }

    // トーンマッピング（白飛びを抑えて金属のツヤと深みを残す）
    col = col / (1.0 + col * 0.22);
    col = pow(max(col, 0.0), vec3(0.4545));

    fragColor = vec4(col, 1.0);
}