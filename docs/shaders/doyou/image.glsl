// 「土曜日の解放感とお花畑」 Shader by GLSL
// Shadertoy の MainImage 関数

// 花弁パターンを生成する関数
float flowerPattern(vec2 uv, float petals, float time) {
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);
    
    // 回転効果
    angle += time * 0.3;
    
    // 花弁の形を作る（サイン波の合成）
    float shape = sin(angle * petals) * 0.3 + 0.5;
    
    // 中心からの距離で輪郭をシャープに
    float d = abs(radius - shape * 0.4);
    return smoothstep(0.08, 0.0, d);
}

// 幾何学的な万華鏡風の回転
vec2 rotate(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // 画面の中心を原点 (0,0) にし、アスペクト比を補正
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    // 時間変数（土曜日の解放感でスピードアップ）
    float t = iTime * 0.8;
    
    // 1. 背景：湧き出るエネルギーのグラデーション波
    vec3 color = vec3(0.0);
    
    // 画面全体に広がるエネルギーの波（渦巻き）
    vec2 p = uv;
    float len = length(p);
    
    for (float i = 1.0; i < 4.0; i++) {
        p = rotate(p, t * 0.2 / i);
        p.x += sin(p.y * 3.0 + t) * 0.2;
        p.y += cos(p.x * 3.0 + t) * 0.2;
    }
    
    // ハッピーな虹色カラフルグラデーション（パステル＆ネオン調）
    vec3 waveColor1 = 0.5 + 0.5 * cos(t + uv.xyx * 3.0 + vec3(0.0, 2.0, 4.0));
    vec3 waveColor2 = 0.5 + 0.5 * sin(t * 0.5 + len * 4.0 + vec3(4.0, 1.0, 2.0));
    color = mix(waveColor1, waveColor2, sin(t) * 0.5 + 0.5);
    
    // 2. 中央から咲き誇るお花畑（複数の花重なり）
    float flowers = 0.0;
    vec3 flowerCol = vec3(0.0);
    
    for (int i = 0; i < 3; i++) {
        float scale = float(i) * 0.3 + 1.0;
        vec2 fUv = uv * scale;
        
        // 時間差で脈動（膨らむ＝エネルギー湧出）
        fUv *= 1.0 - sin(t * 2.0 - length(uv) * 3.0) * 0.15;
        
        float petals = 5.0 + float(i * 3); // 5枚、8枚、11枚の花弁
        float f = flowerPattern(fUv, petals, t * (mod(float(i), 2.0) == 0.0 ? 1.0 : -1.0));
        
        // 各層の花の色
        vec3 c = vec3(
            sin(float(i) + t) * 0.5 + 0.5,
            cos(float(i) * 2.0 + t) * 0.5 + 0.5,
            sin(float(i) * 3.0 + t) * 0.5 + 0.5
        );
        
        flowers += f;
        flowerCol = mix(flowerCol, c, f);
    }
    
    // 花模様を背景に合成（発光感）
    color += flowerCol * 1.5;
    
    // 3. キラキラ輝く光の粒子（頭の中のお花畑・高揚感）
    float sparkle = 0.0;
    for (float i = 0.0; i < 15.0; i++) {
        // 放射状に広がる粒子の位置計算
        float angle = i * (6.28318 / 15.0) + t * 0.5;
        float dist = mod(t * 0.4 + i * 0.1, 1.2);
        vec2 particlePos = vec2(cos(angle), sin(angle)) * dist;
        
        float d = length(uv - particlePos);
        sparkle += smoothstep(0.03, 0.0, d) * (1.0 - dist); // 遠くに行くと消える
    }
    
    // 黄色〜ピンクのキラキラを追加
    color += vec3(1.0, 0.9, 0.4) * sparkle * 2.0;
    
    // 画面端を少し暗くして中央を引き立てる（ビネット効果）
    color *= 1.0 - length(uv) * 0.4;
    
    // 最終カラー出力
    fragColor = vec4(color, 1.0);
}