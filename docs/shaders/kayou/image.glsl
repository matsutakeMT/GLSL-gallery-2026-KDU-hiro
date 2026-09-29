// Ember Real — リアルな焚き火（ボリュームレンダリング）
// Shadertoy の Image タブに貼り付けてください
// マウスのドラッグで、炎の周りを回り込んだり見下ろしたりできます
//
// リアルに見せるための工夫:
//  ・縦に引き伸ばしたノイズを、上昇速度を保ったまま流して「炎の舌」を作る
//  ・先端ほど乱れが強くなり、ちぎれて消えていく形状
//  ・黒体放射に近い色（暗赤 → 橙 → 黄 → 淡い黄白）と、温度の2乗で光る発光量
//  ・上空にすすを含んだ煙が立ちのぼり、炎の光で下から照らされる
//  ・地面には熾火（おきび）の割れ目が赤く光り、炎のゆらぎに合わせて周囲が照らされる
//  ・ACES 風のトーンマップで、明部が自然に黄白へ飽和する

const int STEPS = 64;   // 重い場合は 40 程度に減らしてください

float gFl; // 全体のゆらぎ（明るさのちらつき）

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
    for (int i = 0; i < 6; i++) {
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

// 炎の密度と温度   戻り値 x: 密度  y: 温度
vec2 flameMap(vec3 p) {
    float h = (p.y + 0.6) / 1.6;                    // 0(根元)〜1(先端)
    if (h < -0.05 || h > 1.05) return vec2(0.0);

    // ゆっくり揺れる炎全体の傾き（上ほど大きく揺れる）
    vec2 sway = (vec2(noise3(vec3(h * 1.6 - iTime * 0.6, 1.3, 0.0)),
                      noise3(vec3(h * 1.6 - iTime * 0.5, 7.1, 3.0))) - 0.5) * 0.55 * h;
    vec2 xz = p.xz - sway;
    float r = length(xz);
    if (r > 0.85) return vec2(0.0);

    // 高さに応じて細くなる柱
    float rad = 0.50 * pow(max(1.0 - h, 0.0), 0.7) + 0.05;

    // 縦に引き伸ばしたノイズを上へ流す → 炎の舌
    vec3 s = vec3(xz.x * 2.6, p.y * 1.05 - iTime * 1.7, xz.y * 2.6);
    float n = fbm3(s, 5);

    // 先端ほど乱れが強く、ちぎれて消える
    float d = 1.0 - r / rad + (n - 0.5) * (0.5 + h * 1.4) - h * h * 0.5;
    d = clamp(d * 1.1, 0.0, 1.0);
    d *= smoothstep(-0.05, 0.05, h) * smoothstep(1.05, 0.75, h);

    float temp = d * (1.18 - h * 0.85) + (n - 0.5) * 0.15 * d;
    return vec2(d, clamp(temp, 0.0, 1.0));
}

// 煙の密度（炎の上に広がる）
float smokeMap(vec3 p) {
    float hs = p.y + 0.6;
    if (hs < 0.6 || hs > 2.4) return 0.0;
    float rs = 0.25 + 0.34 * hs;
    vec2 sway = (vec2(noise3(vec3(hs * 0.8 - iTime * 0.3, 2.1, 0.0)),
                      noise3(vec3(hs * 0.8 - iTime * 0.25, 5.3, 1.0))) - 0.5) * 0.9;
    float r = length(p.xz - sway * clamp(hs - 0.6, 0.0, 1.0));
    if (r > rs * 1.7) return 0.0;
    vec3 sp = vec3(p.x * 1.3, p.y * 0.8 - iTime * 0.5, p.z * 1.3);
    float n = fbm3(sp, 3);
    float d = (1.0 - r / rs) + (n - 0.5) * 1.3;
    d = clamp(d, 0.0, 1.0);
    return d * smoothstep(0.6, 1.2, hs) * smoothstep(2.4, 1.4, hs) * 0.55;
}

vec3 aces(vec3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 m = iMouse.z > 0.0 ? (iMouse.xy / iResolution.xy - 0.5) : vec2(0.0);

    // 炎のちらつき（低周波 + 高周波を混ぜる）
    gFl = 0.86 + 0.14 * noise3(vec3(iTime * 5.0, 0.5, 2.0))
                + 0.06 * sin(iTime * 17.0 + noise3(vec3(iTime * 3.0, 4.0, 1.0)) * 6.0);

    // ---------- カメラ ----------
    float dist = 3.9;
    float ang = 0.35 * sin(iTime * 0.1) + m.x * 6.0;
    float pit = 0.20 + m.y * 1.0;
    vec3 ta = vec3(0.0, 0.42, 0.0);
    vec3 ro = ta + dist * vec3(sin(ang) * cos(pit), sin(pit), -cos(ang) * cos(pit));
    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(vec3(0.0, 1.0, 0.0), ww));
    vec3 vv = cross(ww, uu);
    vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.7 * ww);

    // ---------- 背景（ほぼ闇、わずかな暖色の空気） ----------
    vec3 floorCol = vec3(0.004, 0.003, 0.006);
    float FLOOR_Y = -0.65;
    float tfloor = 1e9;

    // ---------- 地面（灰と熾火） ----------
    if (rd.y < -0.001) {
        tfloor = (FLOOR_Y - ro.y) / rd.y;
        if (tfloor > 0.0) {
            vec3 fp = ro + rd * tfloor;
            float rr = length(fp.xz);

            float glowL = exp(-rr * 1.3) * gFl;                // 炎に照らされる光
            float tex = fbm3(vec3(fp.xz * 2.2, 0.7), 4);       // 灰・地面の凹凸
            vec3 albedo = vec3(0.05, 0.035, 0.028) * (0.4 + tex);
            floorCol = albedo * (0.25 + vec3(1.0, 0.42, 0.14) * glowL * 6.0);

            // 熾火の割れ目（尾根状ノイズ）
            float cn = fbm3(vec3(fp.xz * 3.4, iTime * 0.15), 4);
            float ridge = 1.0 - abs(2.0 * cn - 1.0);
            float cracks = smoothstep(0.74, 0.95, ridge);
            float coalMask = smoothstep(0.85, 0.15, rr);
            float pulse = 0.65 + 0.55 * noise3(vec3(fp.xz * 4.0, iTime * 0.8));
            floorCol += vec3(1.0, 0.26, 0.04) * cracks * coalMask * pulse * 1.6;
            floorCol += vec3(0.7, 0.12, 0.02) * coalMask * pulse * 0.10;

            floorCol *= exp(-tfloor * 0.05);
        } else {
            tfloor = 1e9;
        }
    }

    // ---------- ボリュームレイマーチング ----------
    vec3 c = vec3(0.0, 0.55, 0.0);
    float R = 1.85;
    vec3 oc = ro - c;
    float b = dot(oc, rd);
    float disc = b * b - (dot(oc, oc) - R * R);

    float Tr = 1.0;
    vec3 acc = vec3(0.0);

    if (disc > 0.0) {
        float sq = sqrt(disc);
        float tn = max(-b - sq, 0.0);
        float tf = min(-b + sq, tfloor);
        if (tf > tn) {
            float dt = (tf - tn) / float(STEPS);
            float t = tn + dt * hash13(vec3(fragCoord, iTime));

            for (int i = 0; i < STEPS; i++) {
                vec3 p = ro + rd * t;
                float r = length(p.xz);

                // 炎まわりのにじむ光（大気中の散乱）
                acc += Tr * vec3(1.0, 0.36, 0.08) * gFl * dt * 0.16
                     * exp(-r * 2.6) * exp(-abs(p.y - 0.1) * 1.1);

                // 炎
                vec2 f = flameMap(p);
                if (f.x > 0.002) {
                    vec3 em = fireColor(f.y) * (0.12 + 3.2 * f.y * f.y) * gFl;
                    acc += Tr * em * f.x * dt * 3.2;
                    Tr *= exp(-f.x * dt * 1.6);
                }

                // 煙（炎の光で下から照らされる）
                float sd = smokeMap(p);
                if (sd > 0.002) {
                    float hs = p.y + 0.6;
                    float lit = exp(-max(hs - 0.9, 0.0) * 1.6) * gFl;
                    vec3 sc = mix(vec3(0.02, 0.018, 0.02), vec3(0.85, 0.32, 0.09), lit * 0.9);
                    acc += Tr * sc * sd * dt * 2.2;
                    Tr *= exp(-sd * dt * 1.4);
                }

                if (Tr < 0.02) break;
                t += dt;
            }
        }
    }

    vec3 col = floorCol * Tr + acc;

    // ---------- 仕上げ ----------
    col = aces(col * 1.15);
    col = pow(col, vec3(0.4545));
    col *= 1.0 - 0.55 * dot(uv * 0.9, uv * 0.9);
    col += (hash13(vec3(fragCoord, iTime)) - 0.5) * 0.02;

    fragColor = vec4(col, 1.0);
}