// Phoenix Flight — 炎をまとって飛び回る不死鳥
// Shadertoy の Image タブに貼り付けてください
// マウスのドラッグで、カメラの向きと高さ・背景の視差が変わります
//
// 仕組み:
//  ・3Dの鳥：流線形の胴、長い首と頭、くちばし、冠羽、
//    扇状に広がる風切羽の翼（羽ばたきで先端が遅れてしなる）、波打つ長い尾羽
//  ・8の字を描く3D飛行経路に沿って、進行方向を向き、旋回では体を内側に傾ける（バンク）
//  ・スフィアトレーシングで羽毛の表面を描き、法線から陰影・縁の光を付ける
//    表面は溶岩のような地肌 + 赤〜黄の割れ目、胴体ほど白熱、目は白く光る
//  ・体のまわりの炎と、通ったあとに伸びる炎の尾（過去の位置をたどって生成）
//  ・背景は奥・中・手前の3層の炎の壁 + 後光 + 火の粉（bgFire 関数）

const int   STEPS = 64;     // 重い場合は 44 程度に減らしてください
const float BS    = 0.62;   // 不死鳥の大きさ

float gFl;    // 明るさのちらつき
float gW;     // 羽ばたきの位相
vec3  gPos, gX, gY, gZ;     // 不死鳥の位置と向き（前・上・右）
vec3  gTr[8];               // 炎の尾の位置
float gTrR[8];              // 炎の尾の太さ
float gTrA[8];              // 炎の尾の古さ 0..1
vec3  gSa[5], gSb[5];       // 体のまわりの炎の骨格（線分）

float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 x) {
    vec3 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash13(i),                 hash13(i + vec3(1, 0, 0)), f.x),
            mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
        mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
            mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y),
        f.z);
}

float fbm3(vec3 p, int oct) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        if (i >= oct) break;
        v += a * noise3(p);
        p = p.yzx * 2.03 + vec3(1.7, 9.2, 3.3);
        a *= 0.5;
    }
    return v;
}

// 温度 0..1 → 暗赤 → 赤橙 → 橙黄 → 淡い黄白
vec3 fireColor(float t) {
    vec3 c = mix(vec3(0.05, 0.0, 0.0), vec3(0.60, 0.05, 0.0), smoothstep(0.00, 0.25, t));
    c = mix(c, vec3(1.00, 0.28, 0.02), smoothstep(0.20, 0.50, t));
    c = mix(c, vec3(1.00, 0.62, 0.12), smoothstep(0.45, 0.75, t));
    c = mix(c, vec3(1.00, 0.90, 0.55), smoothstep(0.70, 1.00, t));
    return c;
}

// ---------- 飛行経路 ----------
vec3 birdPath(float t) {
    float u = t * 0.55;
    return vec3(2.1 * sin(u),
                0.45 + 0.45 * sin(1.5 * u + 0.6),
                1.6 * sin(2.0 * u));       // 8の字
}

// ---------- 鳥の形（局所座標：前 +x、上 +y、翼は ±z） ----------
float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float sdCap3(vec3 p, vec3 a, vec3 b, float ra, float rb) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - mix(ra, rb, h);
}

// 平たくした羽毛（上下方向を潰す）
float sdFeather(vec3 p, vec3 a, vec3 b, float ra, float rb) {
    return sdCap3(vec3(p.x, p.y * 1.7, p.z),
                  vec3(a.x, a.y * 1.7, a.z),
                  vec3(b.x, b.y * 1.7, b.z), ra, rb);
}

float sdEll(vec3 p, vec3 r) {
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1;
}

float sdBird(vec3 p) {
    // 胴・首・頭
    float d = sdEll(p - vec3(-0.02, 0.0, 0.0), vec3(0.52, 0.19, 0.19));
    float nk = sdCap3(p, vec3(0.30, 0.04, 0.0), vec3(0.56, 0.15, 0.0), 0.13, 0.08);
    float hd = length(p - vec3(0.61, 0.17, 0.0)) - 0.10;
    d = smin(d, nk, 0.12);
    d = smin(d, hd, 0.06);

    // くちばし
    d = min(d, sdCap3(p, vec3(0.68, 0.16, 0.0), vec3(0.90, 0.10, 0.0), 0.05, 0.008));

    vec3 q = vec3(p.x, p.y, abs(p.z));          // 左右対称

    // 冠羽
    d = min(d, sdCap3(q, vec3(0.56, 0.25, 0.03), vec3(0.24, 0.44, 0.09), 0.030, 0.006));
    d = min(d, sdCap3(q, vec3(0.58, 0.24, 0.00), vec3(0.30, 0.54, 0.00), 0.028, 0.005));

    // 翼：肩を中心に羽ばたき（上下に回転）、先端は遅れてしなる
    float fa = 0.55 * sin(gW);
    float ca = cos(fa), sa = sin(fa);
    vec3 S  = vec3(0.12, 0.05, 0.10);
    vec3 dq = q - S;
    if (length(dq) < 1.9) {
        vec3 wr = S + vec3(dq.x, ca * dq.y - sa * dq.z, sa * dq.y + ca * dq.z);
        vec3 arm = vec3(-0.10, 0.0, 0.50);
        float bend = 0.12 - 0.40 * cos(gW);

        d = min(d, sdFeather(wr, S, S + arm, 0.085, 0.060));
        for (int i = 0; i < 5; i++) {
            float f = float(i) / 4.0;
            float psi = mix(0.10, 0.95, f);                   // 後ろへの流れ
            float L   = mix(1.15, 0.80, f);
            vec3 p0 = S + arm * mix(0.95, 0.25, f);
            vec3 p1 = p0 + vec3(-sin(psi), 0.0, cos(psi)) * L * 0.55;
            float psi2 = psi + 0.25;
            vec3 p2 = p1 + vec3(-sin(psi2), bend * 0.8, cos(psi2)) * L * 0.45;
            d = min(d, sdFeather(wr, p0, p1, 0.062, 0.050));
            d = min(d, sdFeather(wr, p1, p2, 0.050, 0.008));
        }
    }

    // 尾羽：波打ちながら流れる3本（左右で計5本）
    vec3 T0 = vec3(-0.42, 0.0, 0.0);
    for (int k = 0; k < 3; k++) {
        float kz = float(k) * 0.5;
        float ph = iTime * 3.0 + float(k);
        vec3 m1 = T0 + vec3(-0.55, 0.05 * sin(ph), 0.12 * kz);
        vec3 m2 = m1 + vec3(-0.85, 0.10 * sin(ph + 1.5) + 0.04, 0.16 * kz + 0.05);
        d = min(d, sdFeather(q, T0, m1, 0.055, 0.045));
        d = min(d, sdFeather(q, m1, m2, 0.045, 0.008));
    }
    return d;
}

float mapBird(vec3 p) {
    vec3 d = p - gPos;
    vec3 pl = vec3(dot(d, gX), dot(d, gY), dot(d, gZ)) / BS;
    return sdBird(pl) * BS;
}

float segDist(vec3 p, vec3 a, vec3 b) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// ---------- 炎（体のまわり + 通ったあとの尾） ----------
void sampleFlames(vec3 p, out float fl, out float tF) {
    fl = 0.0; tF = 0.0;

    // 炎の尾：過去の位置を球でつなぐ
    float ft = 0.0, ageB = 1.0;
    for (int k = 0; k < 8; k++) {
        float dd = length(p - gTr[k]);
        float fk = (1.0 - dd / gTrR[k]) * (1.0 - 0.8 * gTrA[k]);
        if (fk > ft) { ft = fk; ageB = gTrA[k]; }
    }

    // 体のまわり：骨格の線分からの距離（少し上にずらしたものも使い、炎が上へ伸びる）
    float da = 1e9;
    if (length(p - gPos) < 2.1 * BS + 0.4) {
        vec3 pu = p - vec3(0.0, 0.16, 0.0);
        for (int i = 0; i < 5; i++) {
            da = min(da, segDist(p,  gSa[i], gSb[i]));
            da = min(da, segDist(pu, gSa[i], gSb[i]) + 0.05);
        }
    }

    if (ft <= 0.0 && da > 0.30) return;

    float n = fbm3(vec3(p.x * 1.9, p.y - iTime * 1.9, p.z * 1.9), 4);

    float fb = 0.0;
    if (da < 0.30) fb = clamp((1.0 - da / 0.20 + (n - 0.5) * 0.9) * 1.1, 0.0, 1.0);

    float g = smoothstep(0.0, 0.15, ft);
    float ftn = clamp(ft * 1.25 + (n - 0.5) * 0.9 * g, 0.0, 1.0) * g;

    fl = max(fb * 0.8, ftn * 0.9);
    tF = clamp(max(fb * 0.95, ftn * (1.05 - 0.8 * ageB)), 0.0, 1.0);
}

// ---------- 背景用の2Dノイズ ----------
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vn2(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i),              hash12(i + vec2(1, 0)), f.x),
               mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float fbm2(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * vn2(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// ---------- 背景：炎の壁 ----------
//  奥（赤紫・大きくゆっくり）→ 中（橙）→ 手前（金・速く細かい）の3層の炎が
//  画面いっぱいにめらめらと揺れ、中央には後光、全体に細かい火の粉が舞う
vec3 bgFire(vec2 uv, vec2 m, float t) {
    vec2 cen = vec2(0.0, -0.12);                 // オブジェの中心あたり
    float h = uv.y + 0.52;                       // 0(下端)〜1(上端)

    // 下から赤く染まる空気
    vec3 col = vec3(0.012, 0.0, 0.035)
             + vec3(0.40, 0.06, 0.07) * exp(-h * 2.2) * 0.8
             + vec3(0.06, 0.0, 0.12) * smoothstep(0.2, 1.0, h) * 0.3;

    // 3層の炎
    for (int i = 0; i < 3; i++) {
        float k  = float(i);
        float t2 = k * 0.5;                      // 0, 0.5, 1
        float scl     = mix(0.80, 1.50, t2);
        float speed   = mix(0.55, 1.30, t2);
        float topBase = mix(0.95, 0.42, t2);     // 舌の高さ（奥ほど高い）
        float bright  = mix(0.60, 1.10, t2);
        vec3  tint    = mix(vec3(0.80, 0.30, 0.65), vec3(1.0, 0.95, 0.85), t2);

        vec2 p = vec2(uv.x + m.x * 0.12 * (k - 1.0), h);

        // 横方向にまとまった「炎の舌」の高さ
        float prof = fbm2(vec2(p.x * (1.1 + 0.5 * k) + k * 5.3, t * 0.20 * (1.0 + k * 0.5)));
        float topH = topBase * (0.35 + 1.3 * prof);

        // 上ほど大きく横に揺れる（めらめら）
        float sway = (fbm2(vec2(h * 2.4 * scl - t * speed * 0.5, p.x * 0.9 + k * 4.2)) - 0.5)
                   * (0.10 + 0.55 * h);
        float xx = p.x + sway;

        // 上へ流れる乱れ（粗い + 細かい）
        float n  = fbm2(vec2(xx * 3.2 * scl + k * 9.1, h * 1.5 * scl - t * speed * 1.4));
        float n2 = fbm2(vec2(xx * 7.0 * scl + k * 3.3, h * 3.0 * scl - t * speed * 2.4));

        float body = clamp((topH - h) / topH, 0.0, 1.0);
        float d = body * 1.5 + (n - 0.5) * 1.2 + (n2 - 0.5) * 0.5 - 0.40;
        float f = smoothstep(0.0, 0.45, d);
        float heat = clamp(d * 0.85 + body * 0.25, 0.0, 1.1);

        vec3 lc = fireColor(heat) * tint * bright * (0.25 + 0.95 * heat);
        col = mix(col, lc, f * 0.92) + lc * f * 0.10;

        // 炎の縁のにじみ
        float rim = smoothstep(-0.35, 0.0, d) * (1.0 - f);
        col += fireColor(0.45) * tint * bright * rim * 0.10;
    }

    // 中央を少しだけ落ち着かせる
    float r = length(uv - cen);
    col *= mix(0.80, 1.0, smoothstep(0.10, 0.60, r));

    // 後光（放射状の光）
    float a = atan(uv.y - cen.y, uv.x - cen.x);
    float rays = pow(0.5 + 0.5 * sin(a * 14.0 + t * 0.35 + fbm2(vec2(a * 2.0, t * 0.2)) * 3.0), 3.0);
    col += vec3(1.0, 0.45, 0.10) * (exp(-r * 2.6) * 0.28 + rays * exp(-r * 1.6) * 0.20);

    // 舞い上がる火の粉（小さく鋭い点）
    for (int j = 0; j < 2; j++) {
        float sj = 1.0 + float(j) * 0.6;
        vec2 g = uv * vec2(14.0, 8.0) * sj;
        g.y -= t * (1.2 + 0.7 * float(j));
        g.x += sin(g.y * 0.7 + float(j) * 3.0) * 0.4;
        vec2 id = floor(g);
        vec2 gv = fract(g) - 0.5;
        float rn = hash12(id + float(j) * 31.7);
        vec2 off = (vec2(hash12(id + 7.1), hash12(id + 3.3)) - 0.5) * 0.6;
        vec2 dv = gv - off;
        dv.y *= 0.45;
        float sp = smoothstep(0.07, 0.0, length(dv)) * step(0.78, rn);
        float tw = 0.6 + 0.4 * sin(t * 8.0 + rn * 40.0);
        col += vec3(1.0, 0.65, 0.20) * sp * tw * smoothstep(0.0, 0.3, h);
    }

    return col;
}

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 m = iMouse.z > 0.0 ? (iMouse.xy / iResolution.xy - 0.5) : vec2(0.0);

    gFl = 0.88 + 0.12 * noise3(vec3(iTime * 5.0, 0.5, 2.0));
    gW  = iTime * 7.0;

    // ---------- 不死鳥の位置と向き（進行方向 + 旋回で内側に傾く） ----------
    float eps = 0.05;
    vec3 P  = birdPath(iTime);
    vec3 Pp = birdPath(iTime + eps);
    vec3 Pm = birdPath(iTime - eps);
    vec3 vel = (Pp - Pm) / (2.0 * eps);
    vec3 acc3 = (Pp - 2.0 * P + Pm) / (eps * eps);
    vec3 fwd = normalize(vel);
    float kappa = (vel.x * acc3.z - vel.z * acc3.x) / dot(vel, vel);   // 旋回の向きと強さ
    float bank = clamp(0.9 * kappa, -0.9, 0.9);
    vec3 u0 = normalize(vec3(0.0, 1.0, 0.0) - fwd * fwd.y);
    vec3 z0 = cross(fwd, u0);
    gX = fwd;
    gY = u0 * cos(bank) + z0 * sin(bank);
    gZ = cross(gX, gY);
    gPos = P;

    // ---------- 炎の尾（過去の位置） ----------
    for (int k = 0; k < 8; k++) {
        float age = 0.35 + 0.20 * float(k);
        vec3 tp = birdPath(iTime - age);
        tp.y += 0.20 * age;                      // 炎は上へ昇る
        gTr[k]  = tp;
        gTrR[k] = 0.16 + 0.22 * float(k) / 7.0;  // 古いほど太く広がる
        gTrA[k] = age / 1.95;
    }

    // ---------- 体のまわりの炎の骨格（世界座標の線分） ----------
    float fa = 0.55 * sin(gW);
    float ca = cos(fa), sa = sin(fa);
    float bendB = 0.12 - 0.40 * cos(gW);
    vec3 Sl = vec3(0.12, 0.05, 0.10);
    vec3 midR = Sl + vec3(-0.30, sa * 0.80, ca * 0.80);
    vec3 tipR = Sl + vec3(-0.75, sa * 1.65 + bendB * 0.35, ca * 1.65);
    vec3 midL = midR * vec3(1.0, 1.0, -1.0) + vec3(0.0, 0.0, 0.0);
    vec3 tipL = tipR * vec3(1.0, 1.0, -1.0);
    vec3 SlL  = Sl   * vec3(1.0, 1.0, -1.0);
    vec3 la[5]; vec3 lb[5];
    la[0] = vec3(-1.70, 0.0, 0.0);  lb[0] = vec3(0.62, 0.17, 0.0);   // 尾〜頭
    la[1] = Sl;   lb[1] = midR;
    la[2] = midR; lb[2] = tipR;
    la[3] = SlL;  lb[3] = midL;
    la[4] = midL; lb[4] = tipL;
    for (int i = 0; i < 5; i++) {
        gSa[i] = gPos + (gX * la[i].x + gY * la[i].y + gZ * la[i].z) * BS;
        gSb[i] = gPos + (gX * lb[i].x + gY * lb[i].y + gZ * lb[i].z) * BS;
    }

    // ---------- カメラ ----------
    float dist = 5.4;
    float ang = m.x * 6.0;
    float pit = 0.10 + m.y * 1.0;
    vec3 ta = vec3(0.0, 0.45, 0.0);
    vec3 ro = ta + dist * vec3(sin(ang) * cos(pit), sin(pit), -cos(ang) * cos(pit));
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(vec3(0.0, 1.0, 0.0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.8 * ww);

    // ---------- 背景：炎の壁 ----------
    vec3 bgCol = bgFire(uv, m, iTime) * (0.92 + 0.08 * gFl);

    // ---------- 鳥の表面（スフィアトレーシング） ----------
    bool hit = false;
    float tHit = 1e9;
    {
        float rB = 2.0 * BS;
        vec3 oc = ro - gPos;
        float b = dot(oc, rd);
        float disc = b * b - (dot(oc, oc) - rB * rB);
        if (disc > 0.0) {
            float sq = sqrt(disc);
            float tt = max(-b - sq, 0.0);
            float te = -b + sq;
            for (int i = 0; i < 48; i++) {
                float dd = mapBird(ro + rd * tt);
                if (dd < 0.004) { hit = true; tHit = tt; break; }
                tt += dd * 0.85;
                if (tt > te) break;
            }
        }
    }

    // ---------- 炎のボリューム（表面の手前まで） ----------
    vec3 cen = vec3(0.0, 0.5, 0.0);
    float R = 3.4;
    vec3 oc = ro - cen;
    float b = dot(oc, rd);
    float disc = b * b - (dot(oc, oc) - R * R);

    float Tr = 1.0;
    vec3 acc = vec3(0.0);

    if (disc > 0.0) {
        float sq = sqrt(disc);
        float tn = max(-b - sq, 0.0);
        float tf = min(-b + sq, hit ? tHit : 1e9);
        if (tf > tn) {
            float dt = (tf - tn) / float(STEPS);
            float t = tn + dt * hash13(vec3(fragCoord, iTime));
            for (int i = 0; i < STEPS; i++) {
                vec3 p = ro + rd * t;

                // 不死鳥のまわりににじむ光
                acc += Tr * vec3(1.0, 0.36, 0.08) * gFl * dt * 0.08
                     * exp(-max(length(p - gPos) - 0.5 * BS, 0.0) * 2.2);

                float fl, tF;
                sampleFlames(p, fl, tF);
                if (fl > 0.002) {
                    vec3 em = fireColor(tF) * (0.12 + 3.0 * tF * tF) * gFl;
                    acc += Tr * em * fl * dt * 2.6;
                    Tr *= exp(-fl * dt * 1.2);
                }
                if (Tr < 0.02) break;
                t += dt;
            }
        }
    }

    // ---------- 表面の色（溶岩の羽毛 + 縁の光） ----------
    if (hit) {
        vec3 ps = ro + rd * tHit;
        vec3 dl = ps - gPos;
        vec3 pl = vec3(dot(dl, gX), dot(dl, gY), dot(dl, gZ)) / BS;

        vec2 e = vec2(1.0, -1.0) * 0.5773 * 0.004;
        vec3 n = normalize(e.xyy * mapBird(ps + e.xyy) + e.yyx * mapBird(ps + e.yyx)
                         + e.yxy * mapBird(ps + e.yxy) + e.xxx * mapBird(ps + e.xxx));

        float cn = fbm3(pl * 3.0 + vec3(0.0, 0.0, 1.7), 4);
        float ridge = 1.0 - abs(2.0 * cn - 1.0);
        float crack = smoothstep(0.78, 0.94, ridge);
        float pulse = 0.85 + 0.15 * sin(iTime * 3.0 + cn * 10.0);
        float hotBody = smoothstep(1.3, 0.1, length(pl * vec3(0.8, 1.5, 1.0) - vec3(0.1, 0.0, 0.0)));
        float ni = fbm3(vec3(pl.x * 3.0 - iTime * 1.5, pl.y * 3.0, pl.z * 3.0), 3);

        float tS = 0.24 + 0.10 * cn + 0.50 * crack * pulse + 0.60 * hotBody * (0.65 + 0.35 * ni);
        if (length(vec3(pl.x - 0.63, pl.y - 0.18, abs(pl.z) - 0.085)) < 0.035) tS = 1.0;   // 目
        tS = clamp(tS, 0.0, 1.0);

        vec3 surf = fireColor(tS) * (0.25 + 2.4 * tS * tS) * (0.9 + 0.1 * gFl);
        float fres = pow(1.0 - max(dot(n, -rd), 0.0), 2.5);
        surf += vec3(1.0, 0.42, 0.10) * fres * 0.9;
        surf += vec3(1.0, 0.50, 0.15) * max(dot(n, normalize(vec3(0.2, -0.6, -0.3))), 0.0) * 0.25;

        acc += Tr * surf;
        Tr = 0.0;
    }

    vec3 col = bgCol * Tr + acc;

    // ---------- 仕上げ ----------
    col = aces(col * 1.15);
    col = pow(col, vec3(0.4545));
    col *= 1.0 - 0.55 * dot(uv * 0.9, uv * 0.9);
    col += (hash13(vec3(fragCoord, iTime)) - 0.5) * 0.02;

    fragColor = vec4(col, 1.0);
}