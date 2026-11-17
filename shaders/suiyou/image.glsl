// -----------------------------------------------------------------------------
// ハッシュ・ノイズ関数群
// -----------------------------------------------------------------------------
float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

mat2 rot2D(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// -----------------------------------------------------------------------------
// 船体の形状定義・防水ボリューム判定（浸水防止用）
// -----------------------------------------------------------------------------
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// 船のローカルZ位置における半幅と縁（ブルワーク）の上端高さを返す
float getBowHalfWidth(float z) {
    return max(0.0, 1.35 - z * 0.32);
}

float getBulwarkTopY(float z) {
    return 0.12 + z * 0.05; // 船首に向かって反り上がる縁の高さ
}

// 船体の内側（デッキ上〜縁の高さまで）の防水空間の距離関数
// 負の値＝船壁に守られた空間（縁が水没していない限り浸水しない）
float sdHullWatertightVolume(vec3 p) {
    float absX = abs(p.x);
    float bowWidth = getBowHalfWidth(p.z);
    float topY = getBulwarkTopY(p.z);
    
    float dSide = absX - bowWidth;
    float dFront = p.z - 4.2;
    float dBack = -p.z - 2.0;
    float dTop = p.y - topY;
    float dBottom = -p.y - 1.5;
    
    vec3 d = vec3(max(dSide, max(dFront, dBack)), max(dTop, dBottom), 0.0);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 船体の3D距離関数（ローカル座標系）
vec2 mapShip(vec3 p, float lanternSwing) {
    vec3 sp = p;
    sp.x = abs(sp.x);
    
    float bowWidth = getBowHalfWidth(sp.z);
    float topY = getBulwarkTopY(sp.z);
    
    // 1. 船首（バウ）のV字型ブルワーク（舷側の壁）
    float hullWall = abs(sp.x - bowWidth) - 0.07;
    hullWall = max(hullWall, sp.z - 4.2);
    hullWall = max(hullWall, -sp.z - 1.5);
    hullWall = max(hullWall, sp.y - topY);
    hullWall = max(hullWall, -sp.y - 1.2);
    
    // デッキの床面（ブルワークの縁より低い位置にある）
    float deck = max(sp.x - bowWidth, sp.y + 0.25);
    deck = max(deck, sp.z - 4.15);
    deck = max(deck, -sp.z - 1.5);
    
    float woodDist = min(hullWall, deck);
    
    // バウスプリット（斜檣）
    float bowsprit = sdCapsule(p, vec3(0.0, 0.15, 3.8), vec3(0.0, 0.55, 5.6), 0.065);
    woodDist = min(woodDist, bowsprit);
    
    // 前方マスト
    float mast = sdCapsule(p, vec3(-0.45, -0.3, 2.3), vec3(-0.45, 3.2, 2.3), 0.075);
    woodDist = min(woodDist, mast);
    
    vec2 res = vec2(woodDist, 1.0);
    
    // 2. 手すり（レール）と支柱
    float rail = sdCapsule(sp, vec3(1.35, 0.38, 0.0), vec3(0.0, 0.59, 4.2), 0.022);
    float post1 = sdCapsule(sp, vec3(1.03, 0.05, 1.0), vec3(1.03, 0.43, 1.0), 0.02);
    float post2 = sdCapsule(sp, vec3(0.55, 0.12, 2.5), vec3(0.55, 0.50, 2.5), 0.02);
    float post3 = sdCapsule(sp, vec3(0.08, 0.20, 4.0), vec3(0.08, 0.58, 4.0), 0.02);
    float metalDist = min(rail, min(post1, min(post2, post3)));
    
    if (metalDist < res.x) res = vec2(metalDist, 2.0);
    
    // 3. マストに吊るされた揺れるランタン
    vec3 lp = p - vec3(-0.32, 1.15, 2.3);
    lp.xy *= rot2D(lanternSwing);
    float lanternBox = sdBox(lp - vec3(0.0, -0.18, 0.0), vec3(0.06, 0.09, 0.06));
    if (lanternBox < res.x) res = vec2(lanternBox, 3.0);
    
    return res;
}

vec3 getShipNormal(vec3 p, float lanternSwing) {
    vec2 e = vec2(0.005, 0.0);
    return normalize(vec3(
        mapShip(p + e.xyy, lanternSwing).x - mapShip(p - e.xyy, lanternSwing).x,
        mapShip(p + e.yxy, lanternSwing).x - mapShip(p - e.yxy, lanternSwing).x,
        mapShip(p + e.yyx, lanternSwing).x - mapShip(p - e.yyx, lanternSwing).x
    ));
}

// -----------------------------------------------------------------------------
// 荒波（Ocean Wave）の高度計算
// -----------------------------------------------------------------------------
float waveOctave(vec2 uv, float choppy) {
    uv += noise(uv);
    vec2 wv = 1.0 - abs(sin(uv));
    vec2 swv = abs(cos(uv));
    wv = mix(wv, swv, wv);
    return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}

float getSeaHeight(vec2 p, int iterations) {
    float freq = 0.16;
    float amp = 0.85;
    float choppy = 4.2;
    vec2 uv = p;
    uv.x *= 0.75;
    
    float d = 0.0;
    float h = 0.0;
    mat2 octaveMat = mat2(1.6, 1.2, -1.2, 1.6);
    
    for (int i = 0; i < 6; i++) {
        if (i >= iterations) break;
        d = waveOctave((uv + iTime * 1.4) * freq, choppy);
        d += waveOctave((uv - iTime * 1.1) * freq, choppy);
        h += d * amp;
        uv *= octaveMat;
        freq *= 1.9;
        amp *= 0.24;
        choppy = mix(choppy, 1.0, 0.2);
    }
    return h;
}

vec3 getSeaNormal(vec2 p, float eps) {
    vec3 n;
    n.y = getSeaHeight(p, 5);
    n.x = getSeaHeight(vec2(p.x + eps, p.y), 5) - n.y;
    n.z = getSeaHeight(vec2(p.x, p.y + eps), 5) - n.y;
    n.y = eps;
    return normalize(n);
}

// -----------------------------------------------------------------------------
// 空間変換ヘルパー（ワールド座標 <-> 船体ローカル座標）
// -----------------------------------------------------------------------------
vec3 worldToShipLocal(vec3 wp, vec3 worldRO, vec3 localRO, float pitch, float roll) {
    vec3 p = wp - worldRO;
    p.xy *= rot2D(-roll);
    p.yz *= rot2D(-pitch);
    return p + localRO;
}

vec3 shipLocalToWorld(vec3 lp, vec3 worldRO, vec3 localRO, float pitch, float roll) {
    vec3 p = lp - localRO;
    p.yz *= rot2D(pitch);
    p.xy *= rot2D(roll);
    return p + worldRO;
}

// -----------------------------------------------------------------------------
// 空・雷雲・稲妻の描画
// -----------------------------------------------------------------------------
float fbmClouds(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = rot * p * 2.05 + vec2(iTime * 0.08, 0.0);
        a *= 0.5;
    }
    return v;
}

float getLightningBolt(vec2 uv, float seed, float flash) {
    if (flash <= 0.01) return 0.0;
    float xPos = (hash12(vec2(seed, 1.0)) - 0.5) * 1.6;
    float zigZag = (noise(vec2(uv.y * 8.0, seed * 10.0)) - 0.5) * 0.25;
    zigZag += (noise(vec2(uv.y * 25.0, seed * 20.0)) - 0.5) * 0.08;
    
    float dist = abs(uv.x - xPos - zigZag);
    float yMask = smoothstep(0.0, 0.1, uv.y) * smoothstep(0.85, 0.4, uv.y);
    float bolt = (0.004 / (dist + 0.001)) * yMask * flash;
    return clamp(bolt, 0.0, 3.0);
}

vec3 getSkyAndLightning(vec3 rd, out float flashIntensity, out vec3 lightDir) {
    float cycle = floor(iTime / 3.5);
    float localT = mod(iTime, 3.5);
    
    float flash1 = smoothstep(0.0, 0.05, localT) * smoothstep(0.35, 0.05, localT);
    float flash2 = smoothstep(0.25, 0.30, localT) * smoothstep(0.75, 0.30, localT) * 0.8;
    flashIntensity = max(flash1, flash2);
    
    float boltX = (hash12(vec2(cycle, 1.0)) - 0.5) * 1.6;
    lightDir = normalize(vec3(boltX, 0.45, 1.0));
    
    vec2 cloudUV = rd.xz / (max(rd.y, 0.05) + 0.15) * 1.2;
    float clouds = fbmClouds(cloudUV);
    
    vec3 darkSky = vec3(0.02, 0.03, 0.05);
    vec3 cloudColor = mix(darkSky, vec3(0.08, 0.11, 0.16), clouds);
    
    float cloudGlow = pow(clouds, 2.5) * flashIntensity * 2.2;
    vec3 lightningColor = vec3(0.65, 0.80, 1.0);
    cloudColor += lightningColor * cloudGlow;
    
    if (rd.y > 0.0) {
        float bolt = getLightningBolt(vec2(rd.x / max(rd.z, 0.1), rd.y), cycle, flashIntensity);
        cloudColor += vec3(0.85, 0.92, 1.0) * bolt;
    }
    
    float horizonFog = exp(-max(rd.y, 0.0) * 8.0);
    vec3 fogColor = vec3(0.04, 0.06, 0.09) + lightningColor * flashIntensity * 0.35;
    
    return mix(cloudColor, fogColor, horizonFog);
}

// -----------------------------------------------------------------------------
// 激しい暴風雨（Rain Overlay）
// -----------------------------------------------------------------------------
float rainLayer(vec2 uv, float speed, vec2 scale) {
    uv.x += uv.y * 0.28;
    vec2 st = uv * scale;
    st.y += iTime * speed;
    
    vec2 id = floor(st);
    vec2 gv = fract(st) - 0.5;
    float n = hash12(id);
    
    gv.x -= (n - 0.5) * 0.8;
    float streak = smoothstep(0.035, 0.0, abs(gv.x)) * smoothstep(0.45, 0.0, abs(gv.y));
    return streak * n;
}

// -----------------------------------------------------------------------------
// メイン描画処理
// -----------------------------------------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    
    // 船の揺れ（ロール・ピッチ・上下のヒーブ）
    float shipRoll = sin(iTime * 1.4) * 0.14 + cos(iTime * 2.3) * 0.05;
    float shipPitch = sin(iTime * 1.1) * 0.11 + cos(iTime * 1.8) * 0.04;
    float shipHeave = sin(iTime * 1.4) * 0.35;
    float lanternSwing = -shipRoll * 1.8 + sin(iTime * 3.2) * 0.25;
    
    // 船のローカル空間におけるカメラ位置（デッキに立つ人の目線）
    vec3 localRO = vec3(0.05, 0.85, 0.0);
    vec3 localRD = normalize(vec3(uv.x, uv.y - 0.12, 1.35));
    
    // ワールド空間への変換
    vec3 worldRO = vec3(0.0, 2.35 + shipHeave, iTime * 4.5);
    vec3 worldRD = localRD;
    worldRD.yz *= rot2D(shipPitch);
    worldRD.xy *= rot2D(shipRoll);
    
    // -------------------------------------------------------------------------
    // 船の縁（ブルワーク）が海面下に沈み込んでいるか（越波判定）を事前計算
    // -------------------------------------------------------------------------
    // 船首先端付近の縁（z = 3.8, x = ±bowWidth）のワールド高さをサンプリング
    vec3 bowEdgeLocal = vec3(0.0, getBulwarkTopY(3.8), 3.8);
    vec3 bowEdgeWorld = shipLocalToWorld(bowEdgeLocal, worldRO, localRO, shipPitch, shipRoll);
    float seaAtBow = getSeaHeight(bowEdgeWorld.xz, 3);
    
    // 縁が海面より下にある深さ（0以下なら縁が海面上にある＝浸水なし）
    float overtopDepth = seaAtBow - bowEdgeWorld.y;
    bool isFlooding = (overtopDepth > 0.0);
    
    // 1. 空と雷の計算
    float flashIntensity = 0.0;
    vec3 lightDir = vec3(0.0, 0.5, 1.0);
    vec3 col = getSkyAndLightning(worldRD, flashIntensity, lightDir);
    
    // 2. 海面とのレイマーチング交差判定（船壁による浸水ガード付き）
    float seaDist = 110.0;
    if (worldRD.y < 0.15) {
        float t = 0.0;
        for (int i = 0; i < 72; i++) {
            vec3 p = worldRO + worldRD * t;
            
            // 現在のレイ地点を船のローカル座標に変換
            vec3 lp = worldToShipLocal(p, worldRO, localRO, shipPitch, shipRoll);
            float hullVol = sdHullWatertightVolume(lp);
            
            // 船体の防水ボリューム内側（デッキ上〜縁の高さまで）にいる場合：
            // 縁が海面より上（!isFlooding）なら、海水は船壁に阻まれて存在できないためスキップする
            if (!isFlooding && hullVol < 0.05) {
                t += max(-hullVol + 0.08, 0.12);
                continue;
            }
            
            // 船の縁が海面より下に沈み込んだ場合のみ、縁を越えた分の高さまでデッキ内への浸水を許可する
            float h = getSeaHeight(p.xz, 3);
            if (isFlooding && hullVol < 0.0) {
                // 縁を越えた水量（overtopDepth）に応じてデッキ上の水位を制限
                float maxFloodY = -0.25 + min(overtopDepth * 0.85, 0.35);
                vec3 floodSurfaceWorld = shipLocalToWorld(vec3(lp.x, maxFloodY, lp.z), worldRO, localRO, shipPitch, shipRoll);
                h = min(h, floodSurfaceWorld.y);
            }
            
            float distToSea = p.y - h;
            if (distToSea < 0.02 * t || t > seaDist) break;
            t += max(distToSea * 0.55, 0.12);
        }
        
        if (t < seaDist) {
            seaDist = t;
            vec3 p = worldRO + worldRD * t;
            vec3 n = getSeaNormal(p.xz, 0.015 * t);
            
            float fresnel = clamp(pow(1.0 - max(dot(n, -worldRD), 0.0), 4.0), 0.05, 0.95);
            vec3 reflDir = reflect(worldRD, n);
            float dummyFlash; vec3 dummyDir;
            vec3 reflCol = getSkyAndLightning(reflDir, dummyFlash, dummyDir);
            
            vec3 deepSeaCol = vec3(0.01, 0.03, 0.05);
            float diff = max(dot(n, lightDir), 0.0);
            vec3 seaCol = deepSeaCol + vec3(0.04, 0.09, 0.13) * diff * (0.3 + flashIntensity * 2.5);
            
            float waveHeight = getSeaHeight(p.xz, 5);
            float foamMask = smoothstep(1.35, 2.1, waveHeight + noise(p.xz * 2.5) * 0.4);
            
            // 縁を越えて流れ込む海水は泡立ち（白波）を強調
            vec3 lp = worldToShipLocal(p, worldRO, localRO, shipPitch, shipRoll);
            if (sdHullWatertightVolume(lp) < 0.1) {
                foamMask = max(foamMask, 0.75);
            }
            
            vec3 foamCol = vec3(0.35, 0.42, 0.48) * (0.4 + flashIntensity * 1.8);
            
            vec3 halfVec = normalize(lightDir - worldRD);
            float spec = pow(max(dot(n, halfVec), 0.0), 90.0) * (0.4 + flashIntensity * 6.0);
            vec3 specCol = vec3(0.75, 0.88, 1.0) * spec;
            
            vec3 oceanFinal = mix(seaCol, reflCol, fresnel);
            oceanFinal = mix(oceanFinal, foamCol, foamMask * 0.75);
            oceanFinal += specCol;
            
            float fogFactor = clamp(1.0 - exp(-t * 0.022), 0.0, 1.0);
            vec3 fogColor = vec3(0.04, 0.06, 0.09) + vec3(0.65, 0.80, 1.0) * flashIntensity * 0.35;
            col = mix(oceanFinal, fogColor, fogFactor);
        }
    }
    
    // 3. 乗っている船のレイマーチング（海よりも手前に描画）
    float shipT = 0.0;
    float hitMat = 0.0;
    for (int i = 0; i < 64; i++) {
        vec3 p = localRO + localRD * shipT;
        vec2 res = mapShip(p, lanternSwing);
        if (res.x < 0.004) {
            hitMat = res.y;
            break;
        }
        shipT += res.x;
        if (shipT > 7.5) break;
    }
    
    vec3 lanternPos = vec3(-0.32 + sin(lanternSwing) * 0.18, 1.15 - cos(lanternSwing) * 0.18, 2.3);
    
    if (hitMat > 0.5 && shipT < seaDist) {
        vec3 p = localRO + localRD * shipT;
        vec3 n = getShipNormal(p, lanternSwing);
        
        vec3 worldN = n;
        worldN.yz *= rot2D(shipPitch);
        worldN.xy *= rot2D(shipRoll);
        
        if (hitMat > 2.5) {
            col = vec3(1.8, 1.1, 0.4);
        } else {
            float woodGrain = noise(vec2(p.x * 25.0, p.z * 4.0));
            vec3 baseColor = (hitMat < 1.5) 
                ? mix(vec3(0.07, 0.04, 0.025), vec3(0.12, 0.07, 0.04), woodGrain)
                : vec3(0.12, 0.14, 0.16);
            
            vec3 toLantern = lanternPos - p;
            float lDist = length(toLantern);
            vec3 lDir = toLantern / lDist;
            float lAtten = 1.0 / (1.0 + lDist * lDist * 0.45);
            float lDiff = max(dot(n, lDir), 0.0);
            vec3 lanternLight = vec3(1.0, 0.55, 0.18) * lDiff * lAtten * 1.4;
            
            float boltDiff = max(dot(worldN, lightDir), 0.0);
            vec3 stormLight = vec3(0.65, 0.80, 1.0) * boltDiff * (0.15 + flashIntensity * 2.2);
            
            vec3 halfLantern = normalize(lDir - localRD);
            float wetSpecL = pow(max(dot(n, halfLantern), 0.0), 40.0) * lAtten * 0.8;
            
            vec3 halfBolt = normalize(lightDir - worldRD);
            float wetSpecB = pow(max(dot(worldN, halfBolt), 0.0), 50.0) * (0.2 + flashIntensity * 3.0);
            
            col = baseColor * (lanternLight + stormLight + vec3(0.03, 0.04, 0.06));
            col += vec3(1.0, 0.65, 0.3) * wetSpecL + vec3(0.75, 0.88, 1.0) * wetSpecB;
        }
    }
    
    // ランタンの周囲のハロー
    vec3 roToLantern = lanternPos - localRO;
    float proj = dot(roToLantern, localRD);
    if (proj > 0.0 && proj < shipT) {
        float perpDist = length(roToLantern - localRD * proj);
        col += vec3(1.0, 0.55, 0.15) * (0.015 / (perpDist * perpDist + 0.015)) * 0.45;
    }
    
    // -------------------------------------------------------------------------
    // 4. 暴風雨と水しぶき
    // -------------------------------------------------------------------------
    float rain = 0.0;
    rain += rainLayer(uv, 16.0, vec2(18.0, 3.0)) * 0.25;
    rain += rainLayer(uv + vec2(1.7, 0.4), 22.0, vec2(12.0, 2.0)) * 0.45;
    rain += rainLayer(uv + vec2(3.1, 1.2), 28.0, vec2(7.0, 1.2)) * 0.75;
    
    vec3 rainColor = vec3(0.45, 0.55, 0.65) * (0.35 + flashIntensity * 1.8);
    col += rainColor * rain;
    
    // トーンマッピング・ガンマ補正・ビネット
    col = col / (1.0 + col * 0.35);
    col = pow(col, vec3(0.85));
    vec2 screenST = fragCoord / iResolution.xy;
    col *= pow(16.0 * screenST.x * screenST.y * (1.0 - screenST.x) * (1.0 - screenST.y), 0.2);

    fragColor = vec4(col, 1.0);
}
