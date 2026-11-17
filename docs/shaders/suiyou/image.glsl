// 1次元ハッシュ関数
float hash12(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2次元ハッシュ関数（ランダムなXYオフセット生成用）
vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
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

// ランダムな位置と大きさで重なり合う波紋（リップル）
float ripple(vec2 uv, float t) {
    vec2 st = uv * 4.5;
    vec2 id = floor(st);
    vec2 gv = fract(st);
    
    float totalRing = 0.0;
    
    // 隣接する3x3セルを探索することで、セル境界を越えて波紋が広がり重なり合うようにする
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cellId = id + offset;
            
            // セルごとのランダム値を取得
            vec2 randPos = hash22(cellId);          // 発生位置のランダム化 (0.0 ~ 1.0)
            float randVal = hash12(cellId + 17.3);  // タイミングとサイズのランダム化
            
            // 波紋のライフサイクル（周期も少しランダムにずらす）
            float speed = 0.8 + randVal * 0.6;
            float dropTime = fract(t * speed + randVal * 10.0);
            
            // セル内のランダムな位置を波紋の中心に設定
            vec2 center = offset + randPos;
            float dist = length(gv - center);
            
            // 大きさのランダム化（最大半径を 0.25 〜 0.85 の間でランダムに決定）
            float maxRadius = 0.25 + fract(randVal * 7.13) * 0.6;
            float currentRadius = dropTime * maxRadius;
            
            // 波紋のリング形状（外側と内側の輪郭 + 多重リングの揺らぎ）
            float wave = sin((dist - currentRadius) * 45.0);
            float mask = smoothstep(0.08, 0.0, abs(dist - currentRadius));
            
            // 発生直後から消えるまでのフェードイン・フェードアウト
            float fade = smoothstep(0.0, 0.1, dropTime) * smoothstep(1.0, 0.2, dropTime);
            
            totalRing += max(0.0, wave) * mask * fade;
        }
    }
    
    return totalRing;
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
        col += vec3(0.45, 0.65, 0.85) * rip * smoothstep(-0.2, -0.55, uv.y);
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
