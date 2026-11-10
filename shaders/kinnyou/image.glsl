// --- TGIF! Radiant Golden Sky & Authentic Engraved Ingot Edition ---
// 最高の金曜日！輝く黄金の空と本格刻印インゴット（三菱マーク・GOLD・999.9・1000g）＆高精細ビットコイン

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

// 2D基本図形距離関数（ボックス・線分・ひし形）
float sdBox2D(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
float sdSeg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}
float sdRhombus(vec2 p, vec2 b) {
    p = abs(p);
    return (p.x * b.y + p.y * b.x - b.x * b.y) / length(b);
}

// --- インゴット刻印1：三菱スリーダイヤ風の精錬マーク ---
float sdMitsubishi(vec2 p) {
    vec2 b = vec2(0.28, 0.48);
    // 上のダイヤ
    float d1 = sdRhombus(p - vec2(0.0, 0.52), b);
    // 左下のダイヤ（+120度）
    vec2 p2 = rot(2.094395) * p;
    float d2 = sdRhombus(p2 - vec2(0.0, 0.52), b);
    // 右下のダイヤ（-120度）
    vec2 p3 = rot(-2.094395) * p;
    float d3 = sdRhombus(p3 - vec2(0.0, 0.52), b);
    return min(d1, min(d2, d3));
}

// --- インゴット刻印2：「GOLD」文字 ---
float sdWordGOLD(vec2 p) {
    // 'G'
    vec2 qG = p - vec2(-1.25, 0.0);
    float gRing = abs(length(vec2(qG.x * 1.15, qG.y)) - 0.40);
    float gGap  = max(qG.x - 0.10, 0.14 - abs(qG.y - 0.13));
    float gArc  = max(gRing, -gGap);
    float gBar  = min(sdSeg(qG, vec2(0.05, -0.02), vec2(0.35, -0.02)),
                      sdSeg(qG, vec2(0.35, -0.02), vec2(0.35, -0.28)));
    float dG = min(gArc, gBar);

    // 'O'
    vec2 qO = p - vec2(-0.40, 0.0);
    float dO = abs(length(vec2(qO.x * 1.18, qO.y)) - 0.40);

    // 'L'
    vec2 qL = p - vec2(0.40, 0.0);
    float dL = min(sdSeg(qL, vec2(-0.22, 0.40), vec2(-0.22, -0.40)),
                   sdSeg(qL, vec2(-0.22, -0.40), vec2(0.25, -0.40)));

    // 'D'
    vec2 qD = p - vec2(1.20, 0.0);
    float dD_left = sdSeg(qD, vec2(-0.25, -0.40), vec2(-0.25, 0.40));
    float dD_top  = sdSeg(qD, vec2(-0.25,  0.40), vec2(-0.04, 0.40));
    float dD_bot  = sdSeg(qD, vec2(-0.25, -0.40), vec2(-0.04, -0.40));
    float dD_arc  = max(abs(length(vec2((qD.x + 0.04) * 1.05, qD.y)) - 0.40), -0.04 - qD.x);
    float dD = min(min(dD_left, dD_arc), min(dD_top, dD_bot));

    return min(min(dG, dO), min(dL, dD)) - 0.085;
}

// --- インゴット刻印3：純度「999.9」 ---
float sdDigit9(vec2 q) {
    float topLoop   = abs(length(vec2(q.x * 1.1, q.y - 0.16)) - 0.23);
    float rightStem = sdSeg(q, vec2(0.21, 0.16), vec2(0.21, -0.18));
    float botArc    = max(abs(length(vec2((q.x - 0.01) * 1.1, q.y + 0.18)) - 0.21), q.y + 0.16);
    return min(topLoop, min(rightStem, botArc)) - 0.075;
}
float sdPurity9999(vec2 p) {
    float d1  = sdDigit9(p - vec2(-1.22, 0.0));
    float d2  = sdDigit9(p - vec2(-0.50, 0.0));
    float d3  = sdDigit9(p - vec2( 0.22, 0.0));
    float dotP = length(p - vec2( 0.68, -0.34)) - 0.09;
    float d4  = sdDigit9(p - vec2( 1.15, 0.0));
    return min(min(min(d1, d2), min(d3, d4)), dotP);
}

// --- インゴット刻印4：重量「1000g」 ---
float sdZero(vec2 q) {
    vec2 w = vec2(q.x, max(abs(q.y) - 0.16, 0.0));
    return abs(length(w) - 0.21) - 0.072;
}
float sdWeight1000g(vec2 p) {
    // '1'
    vec2 q1 = p - vec2(-1.42, 0.0);
    float d1 = min(sdSeg(q1, vec2(0.0, -0.38), vec2(0.0, 0.38)),
               min(sdSeg(q1, vec2(0.0,  0.38), vec2(-0.16, 0.22)),
                   sdSeg(q1, vec2(-0.16, -0.38), vec2(0.16, -0.38)))) - 0.072;
    // '000'
    float d0a = sdZero(p - vec2(-0.80, 0.0));
    float d0b = sdZero(p - vec2(-0.15, 0.0));
    float d0c = sdZero(p - vec2( 0.50, 0.0));
    // 'g'
    float dg  = sdDigit9((p - vec2(1.18, -0.06)) * 1.15) / 1.15;

    return min(min(d1, dg), min(d0a, min(d0b, d0c)));
}

// --- 高精細ビットコイン「₿」ロゴの2D距離関数 ---
float sdBitcoinLogo(vec2 p) {
    p *= rot(-0.08);
    p *= 1.05;

    float spine = sdBox2D(p - vec2(-0.14, 0.0), vec2(0.06, 0.33));

    float serifTop = sdBox2D(p - vec2(-0.175,  0.285), vec2(0.095, 0.045));
    float serifBot = sdBox2D(p - vec2(-0.175, -0.285), vec2(0.095, 0.045));
    float serifs = min(serifTop, serifBot);

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

    float midBar = sdBox2D(p - vec2(-0.04, 0.0), vec2(0.12, 0.042));
    float loops = max(min(min(topLoop, botLoop), midBar), -(p.x + 0.14));

    float bar1 = sdBox2D(p - vec2(-0.065, 0.0), vec2(0.036, 0.45));
    float bar2 = sdBox2D(p - vec2( 0.065, 0.0), vec2(0.036, 0.45));
    float bars = max(min(bar1, bar2), 0.27 - abs(p.y));

    return min(min(spine, serifs), min(loops, bars));
}

// --- コイン表面の精密ディテール（回路基板模様＋外周刻印＋₿ロゴ） ---
vec2 getCoinSurface(vec2 uv) {
    float rad = length(uv);
    if (rad > 1.0) return vec2(0.0, 1.0);

    float dB = sdBitcoinLogo(uv);

    if (rad > 0.88) {
        float rimBevel = smoothstep(0.88, 0.90, rad) * (1.0 - smoothstep(0.98, 1.0, rad));
        return vec2(0.85 + rimBevel * 0.15, 1.0);
    }

    if (dB < 0.0) {
        float edgeRim = smoothstep(-0.025, -0.008, dB) * (1.0 - smoothstep(-0.008, 0.0, dB));
        return vec2(0.90 + edgeRim * 0.15, 1.0);
    }

    float ang = atan(uv.y, uv.x);
    if (rad > 0.76) {
        float ring1 = smoothstep(0.01, 0.0, abs(rad - 0.865));
        float ring2 = smoothstep(0.01, 0.0, abs(rad - 0.775));
        float ticks = step(0.35, sin(ang * 48.0)) * smoothstep(0.79, 0.80, rad) * smoothstep(0.85, 0.84, rad);
        float subTicks = step(0.1, sin(ang * 96.0 + rad * 40.0)) * 0.5;
        float h = 0.25 + (ring1 + ring2) * 0.35 + ticks * subTicks * 0.35;
        return vec2(h, 0.3);
    }

    float concentric = sin(rad * 160.0);
    float sector = floor((ang + 3.14159) * 12.0 / 6.28318);
    float trackGate = hash2(vec2(floor(rad * 25.0), sector));

    float tracks = smoothstep(-0.2, 0.4, concentric) * step(0.25, trackGate);
    float radialLines = smoothstep(0.97, 0.995, cos(ang * 24.0)) * step(0.6, trackGate);

    float vLines = smoothstep(0.3, 0.7, sin(uv.x * 140.0)) * step(0.5, sin(uv.y * 60.0));
    float innerMask = smoothstep(0.45, 0.2, rad);

    float circuit = mix(max(tracks, radialLines), vLines, innerMask * 0.6);
    float logoShadow = smoothstep(0.0, 0.03, dB);

    float h = (0.15 + circuit * 0.38) * logoShadow;
    return vec2(h, 0.2 + circuit * 0.4);
}

// --- 細長く美しい台形インゴット ---
float sdIngot(vec3 p) {
    vec3 q = p;
    q.xz *= 1.0 + clamp(q.y, -0.2, 0.2) * 0.42;
    vec3 b = vec3(0.98, 0.14, 0.34);
    float r = 0.042;
    vec3 d = abs(q) - b;
    return (length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0) - r) * 0.75;
}

// --- インゴット表面の刻印（三菱マーク・GOLD・999.9・1000g） ---
float getIngotBump(vec3 p) {
    // インゴットの長軸(x)を縦、短軸(z)を横として正しい向きで座標展開
    vec2 uv = vec2(-p.z * sign(p.y), p.x);
    if (abs(uv.x) > 0.28 || abs(uv.y) > 0.88) return 0.0;

    float d = 1.0;

    // 1. 上部：三菱スリーダイヤ精錬マーク
    d = min(d, sdMitsubishi((uv - vec2(0.0, 0.56)) / 0.17) * 0.17);

    // 2. 中上：「GOLD」
    d = min(d, sdWordGOLD((uv - vec2(0.0, 0.18)) / 0.13) * 0.13);

    // 3. 中下：「999.9」
    d = min(d, sdPurity9999((uv - vec2(0.0, -0.15)) / 0.13) * 0.13);

    // 4. 下部：「1000g」
    d = min(d, sdWeight1000g((uv - vec2(0.0, -0.50)) / 0.115) * 0.115);

    // 刻印の深さ（文字のフチがキラッと光るベベル付き）
    return -smoothstep(0.008, -0.008, d) * 0.85;
}

// --- コインの基本形状 ---
float sdCoinBase(vec3 p, float r, float h) {
    float rad = length(p.xz);
    vec2 d = abs(vec2(rad, p.y)) - vec2(r, h);
    float cyl = min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - 0.008;

    float edgeMask = smoothstep(r * 0.96, r, rad) * smoothstep(h, h * 0.7, abs(p.y));
    float ridges = sin(atan(p.z, p.x) * 90.0) * 0.0025 * edgeMask;
    float faceIndent = smoothstep(r * 0.89, r * 0.86, rad) * 0.008;

    return cyl + ridges + faceIndent;
}

// リング（指輪）
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// 空間のローカル座標とオブジェクト種別を取得
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

// --- スタジオ金属反射（コントラストと鮮やかな黄金の輝き） ---
vec3 getGoldReflection(vec3 ref, float roughness) {
    float strip1 = pow(sin(ref.y * 6.0 + ref.x * 3.0) * 0.5 + 0.5, mix(4.5, 1.5, roughness));
    float strip2 = pow(max(0.0, sin(ref.x * 5.0 - ref.z * 3.0)), mix(7.0, 2.0, roughness));
    float skyGrad = smoothstep(-0.9, 0.9, ref.y);

    vec3 darkShadow = vec3(0.10, 0.03, 0.00);
    vec3 midGold    = vec3(1.05, 0.72, 0.12);
    vec3 brightGold = vec3(1.65, 1.32, 0.65);

    vec3 env = mix(darkShadow, midGold, skyGrad * 0.78 + 0.18);
    env = mix(env, brightGold, strip1 * 0.80);
    env += vec3(1.3, 1.05, 0.50) * strip2 * 0.65;
    return env;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // --- 眩しく輝くゴールデン背景（後光付き・白い点なし） ---
    vec3 bgCol = mix(vec3(0.58, 0.22, 0.01), vec3(1.18, 0.82, 0.22), uv.y * 0.5 + 0.5);

    // 画面中央からの強い黄金の輝き（ブルーム効果）
    float centerDist = length(uv - vec2(0.0, 0.08));
    bgCol += vec3(1.15, 0.92, 0.45) * exp(-centerDist * 1.4) * 0.75;
    bgCol += vec3(1.00, 0.98, 0.80) * exp(-centerDist * 3.2) * 0.45;

    // 放射状に広がる光の筋（ゴッドレイ）
    float rayAng = atan(uv.y - 0.08, uv.x);
    float rays = (sin(rayAng * 10.0 + iTime * 0.4) * 0.5 + 0.5)
               * (sin(rayAng * 7.0  - iTime * 0.25) * 0.5 + 0.5);
    bgCol += vec3(1.0, 0.88, 0.40) * rays * exp(-centerDist * 1.2) * 0.32;

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

        // --- オブジェクト別の精密バンプと質感設定 ---
        if (objType == 2 && abs(localP.y) > 0.055) {
            // 【ビットコイン表面】
            vec2 coinUV = localP.xz / 0.72;
            if (localP.y < 0.0) coinUV.x = -coinUV.x;

            float eps = 0.004;
            vec2 c0 = getCoinSurface(coinUV);
            float hx = getCoinSurface(coinUV + vec2(eps, 0.0)).x - c0.x;
            float hy = getCoinSurface(coinUV + vec2(0.0, eps)).x - c0.x;

            float side = sign(localP.y);
            vec3 bumpN = normalize(vec3(-hx * side * 8.5, side, -hy * 8.5));
            n = normalize(n + (bumpN - vec3(0.0, side, 0.0)) * 0.65);

            roughness = mix(0.30, 0.03, c0.y);
            cavityAO  = mix(0.60, 1.05, c0.x);

            n = normalize(n + vec3(coinUV.x, 0.0, coinUV.y) * 0.12);

        } else if (objType == 1) {
            // 【金インゴット】
            n = normalize(n + localP * vec3(0.22, 0.40, 0.48));

            if (abs(localP.y) > 0.115) {
                float eps = 0.0035;
                float b0 = getIngotBump(localP);
                float bx = getIngotBump(localP + vec3(eps, 0.0, 0.0)) - b0;
                float bz = getIngotBump(localP + vec3(0.0, 0.0, eps)) - b0;
                n = normalize(n + vec3(-bx, 0.0, -bz) * 5.5);

                cavityAO  = 1.0 + b0 * 0.45;
                roughness = mix(0.035, 0.22, clamp(-b0, 0.0, 1.0));
            } else {
                roughness = 0.035;
            }
        } else {
            // 【ゴールドリング】
            roughness = 0.03;
        }

        // --- ライティング＆高光沢メタリック合成 ---
        vec3 lightDir1 = normalize(vec3( 1.2,  2.0, -1.5));
        vec3 lightDir2 = normalize(vec3(-1.5, -1.2, -1.0));
        vec3 ref = reflect(rd, n);

        vec3 envCol = getGoldReflection(ref, roughness);

        vec3 halfVec1 = normalize(lightDir1 + v);
        float specPower = mix(220.0, 32.0, roughness);
        float specSharp = pow(max(dot(n, halfVec1), 0.0), specPower);
        float specBroad = pow(max(dot(n, halfVec1), 0.0), 16.0);

        vec3 halfVec2 = normalize(lightDir2 + v);
        float specSub = pow(max(dot(n, halfVec2), 0.0), 48.0);

        float fresnel = pow(1.0 - max(dot(n, v), 0.0), 3.0);

        vec3 goldBase = vec3(1.0, 0.76, 0.15);

        col = goldBase * envCol * cavityAO;
        col += vec3(1.0, 0.85, 0.30) * specBroad * 0.95 * cavityAO;
        col += vec3(1.0, 0.99, 0.90) * specSharp * mix(5.0, 1.3, roughness);
        col += vec3(1.0, 0.82, 0.32) * specSub   * 1.0;
        col += vec3(1.0, 0.94, 0.55) * fresnel   * 1.6;

        // 遠くのオブジェクトを背景の黄金光に溶け込ませる
        float fog = 1.0 - exp(-0.0025 * d0 * d0);
        col = mix(col, bgCol, fog);
    }

    // 明るさと彩度を保ちつつ滑らかにガンマ補正
    col = col / (1.0 + col * 0.08);
    col = pow(max(col, 0.0), vec3(0.4545));

    fragColor = vec4(col, 1.0);
}