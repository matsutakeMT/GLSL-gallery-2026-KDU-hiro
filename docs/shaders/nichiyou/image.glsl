// --------------------------------------------------------
// ノイズ & FBM (雲やウネウネの動きを生成)
// --------------------------------------------------------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        p = p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// --------------------------------------------------------
// Main Image
// --------------------------------------------------------
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // アスペクト比補正 (-1.0 ～ 1.0)
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    // --------------------------------------------------------
    // 1. 日曜日の爽やかな青空 & 陽光（ベース）
    // --------------------------------------------------------
    vec3 skyTop = vec3(0.18, 0.52, 0.95);
    vec3 skyBottom = vec3(0.65, 0.85, 1.0);
    vec3 col = mix(skyBottom, skyTop, uv.y * 0.5 + 0.5);

    // 太陽
    vec2 sunPos = vec2(-0.5, 0.4);
    float sunDist = length(uv - sunPos);
    float sun = smoothstep(0.4, 0.0, sunDist);
    col += vec3(1.0, 0.92, 0.75) * sun * 0.6;

    // --------------------------------------------------------
    // 2. ゆっくり流れる白い雲
    // --------------------------------------------------------
    vec2 cloudUV = uv * 1.4 + vec2(iTime * 0.03, 0.0);
    float cloudNoise = fbm(cloudUV * 2.2);
    float cloudShape = smoothstep(0.38, 0.72, cloudNoise);
    col = mix(col, vec3(0.98, 0.98, 1.0), cloudShape * 0.75);

    // --------------------------------------------------------
    // 3. 「月曜日の悪魔」の位置・大きさ・動き制御
    // --------------------------------------------------------
    // マウス操作で侵食度変更（ドラッグで悪魔が迫り出す）
    float pressAmount = 0.0;
    if (iMouse.z > 0.0) {
        pressAmount = (1.0 - iMouse.x / iResolution.x) * 0.5;
    } else {
        pressAmount = sin(iTime * 0.8) * 0.05; // 呼吸のようなジワジワ感
    }

    // 悪魔の中心位置（右上）
    vec2 devilCenter = vec2(0.7 - pressAmount, 0.5 - pressAmount);
    vec2 devilUV = uv - devilCenter;

    // --------------------------------------------------------
    // 4. 悪魔の輪郭・黒い霧・触手 (Dark Smoke & Tentacles)
    // --------------------------------------------------------
    float distToDevil = length(devilUV);
    float angle = atan(devilUV.y, devilUV.x);

    // 渦巻く歪みと触手状の突起ノイズ
    float tentacleNoise = fbm(devilUV * 3.0 + vec2(iTime * 0.2, -iTime * 0.1));
    float spikes = sin(angle * 8.0 + fbm(devilUV * 5.0) * 6.0) * 0.15;
    
    // 影の形を作る
    float devilShape = smoothstep(0.7 + tentacleNoise * 0.3 + spikes, 0.1, distToDevil);

    // 暗黒色（黒紫〜漆黒）
    vec3 devilBodyColor = vec3(0.04, 0.03, 0.08);
    col = mix(col, devilBodyColor, devilShape * 0.95);

    // --------------------------------------------------------
    // 5. 悪魔の「発光する赤目」 (Glowing Evil Eyes)
    // --------------------------------------------------------
    // 左右の目の位置を設定
    vec2 eyeLeftPos = devilCenter + vec2(-0.18, 0.08);
    vec2 eyeRightPos = devilCenter + vec2(0.05, 0.12);

    // つり目（斜めの楕円）にするための座標変換
    mat2 rotL = mat2(cos(0.4), -sin(0.4), sin(0.4), cos(0.4));
    mat2 rotR = mat2(cos(-0.4), -sin(-0.4), sin(-0.4), cos(-0.4));
    
    vec2 uvEyeL = rotL * (uv - eyeLeftPos);
    vec2 uvEyeR = rotR * (uv - eyeRightPos);

    // 目の形状（扁平な楕円）
    float eyeL = length(uvEyeL * vec2(1.0, 2.5));
    float eyeR = length(uvEyeR * vec2(1.0, 2.5));

    // メッシュ・発光グラデーション（コアは明るく、外側は赤く光る）
    float eyeGlow = smoothstep(0.08, 0.0, eyeL) + smoothstep(0.08, 0.0, eyeR);
    float eyeCore = smoothstep(0.03, 0.0, eyeL) + smoothstep(0.03, 0.0, eyeR);

    // 瞳のゆらめき（炎のような明滅）
    float eyeFlicker = 0.8 + 0.2 * sin(iTime * 15.0 + fbm(uv * 10.0));
    vec3 eyeColor = (vec3(1.0, 0.1, 0.0) * eyeGlow + vec3(1.0, 0.9, 0.3) * eyeCore) * eyeFlicker;

    // --------------------------------------------------------
    // 6. 悪魔の「ギザギザした口」 (Fanged Mouth)
    // --------------------------------------------------------
    vec2 mouthPos = devilCenter + vec2(-0.06, -0.12);
    vec2 uvMouth = uv - mouthPos;
    
    // 三日月状の開いた口のベース
    float mouthDist = length(uvMouth * vec2(1.2, 2.2));
    float mouthBase = smoothstep(0.12, 0.0, mouthDist);

    // ギザギザの歯（鋭い波形ノイズ）
    float teeth = abs(sin(uvMouth.x * 60.0)) * 0.05;
    float mouthInside = smoothstep(0.08 - teeth, 0.0, mouthDist);

    // 口の中の赤黒いグラデーションと発光
    vec3 mouthColor = vec3(0.9, 0.05, 0.02) * mouthInside * (0.8 + 0.2 * sin(iTime * 10.0));

    // 目と口を背景に加算合成（暗闇の中で強く輝く）
    col += eyeColor * 2.0;
    col += mouthColor * 1.8;

    // --------------------------------------------------------
    // 7. 走る雷・不吉な閃光 (Lightning Bolts)
    // --------------------------------------------------------
    // ランダムに一瞬光るフラッシュ（月曜日の絶望感）
    float lightningFlash = step(0.93, hash(vec2(floor(iTime * 12.0), 0.1)));
    
    // 雷の筋（ギザギザの細いライン）
    vec2 boltUV = uv * 3.0 + vec2(iTime * 0.5, 0.0);
    float boltLine = abs(uv.x - devilCenter.x + (fbm(boltUV) - 0.5) * 0.4);
    float lightning = smoothstep(0.015, 0.0, boltLine) * lightningFlash * devilShape;

    // 雷の光を合成（紫がかった白）
    col += vec3(0.8, 0.85, 1.0) * lightning * 2.5;

    // 最終出力
    fragColor = vec4(col, 1.0);
}