// ランダム関数
float hash12(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 雨筋（レーンドロップ）の描画関数
float rainLayer(vec2 uv, float t, float speed, vec2 scale) {
    vec2 st = uv * scale;
    st.y += t * speed; // 落下速度
    
    vec2 id = floor(st);
    vec2 gv = fract(st) - 0.5;
    
    float n = hash12(id);
    
    // 雨粒の左右の位置オフセット
    gv.x -= (n - 0.5) * 0.8;
    
    // 風による縦長に変形した雨筋
    float drop = smoothstep(0.03, 0.0, length(gv * vec2(10.0, 1.0)));
    
    // 尾を引くエフェクト（ブラー）
    float trail = smoothstep(0.2, -0.4, gv.y) * smoothstep(0.04, 0.0, abs(gv.x));
    
    return (drop + trail * 0.5) * n;
}

// 地面の水たまりの波紋（リップル）
float ripple(vec2 uv, float t) {
    vec2 id = floor(uv * 6.0);
    vec2 gv = fract(uv * 6.0) - 0.5;
    
    float n = hash12(id);
    float dropTime = fract(t * 1.5 + n); // 波紋の発生タイミング
    
    float dist = length(gv);
    float circle = sin(dist * 30.0 - dropTime * 15.0);
    
    // 時間経過で波紋が広がり消えるフェード処理
    float fade = smoothstep(1.0, 0.0, dropTime);
    float ring = smoothstep(0.05, 0.0, abs(dist - dropTime * 0.5)) * circle * fade;
    
    return max(0.0, ring);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // --------------------------------------------------------
    // 1. 10秒アニメーションタイムライン
    // --------------------------------------------------------
    float cycle = 10.0;
    float t = mod(iTime, cycle);

    // 強度制御 (0〜2s: 降り始め / 2〜7s: 大雨 / 7〜10s: 雨上がり)
    float rainIntensity = 0.0;
    if (t < 2.0) {
        rainIntensity = smoothstep(0.0, 2.0, t) * 0.4; // しとしと雨
    } else if (t < 7.0) {
        rainIntensity = 0.4 + smoothstep(2.0, 4.0, t) * 0.6; // 土砂降り
    } else {
        rainIntensity = smoothstep(10.0, 7.0, t); // 止みかける
    }

    // --------------------------------------------------------
    // 2. 座標系のセットアップ
    // --------------------------------------------------------
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    // 風による雨の斜めの傾き
    float wind = sin(iTime * 0.5) * 0.15;
    uv.x -= uv.y * wind;

    // --------------------------------------------------------
    // 3. 背景（どんよりとした空と霧）
    // --------------------------------------------------------
    vec3 skyTop = vec3(0.05, 0.08, 0.12);
    vec3 skyBottom = vec3(0.15, 0.20, 0.25);
    vec3 col = mix(skyBottom, skyTop, uv.y + 0.5);

    // --------------------------------------------------------
    // 4. 雨の描画 (手前・中景・遠景の3レイヤー)
    // --------------------------------------------------------
    float rain = 0.0;
    
    // 奥の小さい雨
    rain += rainLayer(uv, iTime, 8.0, vec2(15.0, 3.0)) * 0.3;
    
    // 中間の雨
    if (rainIntensity > 0.2) {
        rain += rainLayer(uv + vec2(1.3, 0.7), iTime, 12.0, vec2(10.0, 2.0)) * 0.6;
    }
    
    // 手前の大きな雨
    if (rainIntensity > 0.5) {
        rain += rainLayer(uv + vec2(2.5, 1.4), iTime, 18.0, vec2(6.0, 1.5)) * 1.0;
    }

    // 雨の強さに応じて雨筋を加算
    col += vec3(0.6, 0.75, 0.9) * rain * rainIntensity;

    // --------------------------------------------------------
    // 5. 地面の水たまりの波紋（画面下部）
    // --------------------------------------------------------
    if (uv.y < -0.2) {
        vec2 groundUV = vec2(uv.x * 1.5, (uv.y + 0.2) * 3.0); // 奥行き感を出すための遠近補正
        float rip = ripple(groundUV, iTime) * rainIntensity;
        col += vec3(0.4, 0.6, 0.8) * rip * smoothstep(-0.2, -0.6, uv.y);
    }

    // --------------------------------------------------------
    // 6. 雷（フラッシュ）エフェクト（ピーク時: 4.5秒〜5.5秒付近で発生）
    // --------------------------------------------------------
    if (t > 4.5 && t < 5.5) {
        float lightning = step(0.85, hash12(vec2(floor(iTime * 20.0), 0.0))) * rainIntensity;
        col += vec3(0.8, 0.9, 1.0) * lightning * 0.6;
    }

    // ビネット（画面端を薄暗くする）
    vec2 st = fragCoord / iResolution.xy;
    col *= pow(16.0 * st.x * st.y * (1.0 - st.x) * (1.0 - st.y), 0.25);

    fragColor = vec4(col, 1.0);
}
