#define PI 3.14159265

float hash(float n)
{
    return fract(sin(n * 127.1) * 43758.5453);
}

float hash21(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p)
{
    float value = 0.0;
    float amplitude = 0.5;

    for(int i = 0; i < 5; i++)
    {
        value += noise(p) * amplitude;
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

float starShape(vec2 uv, vec2 pos, float size)
{
    vec2 p = uv - pos;
    float d = length(p);
    float core = exp(-d * 500.0 / size);
    float horizontal = exp(-abs(p.y) * 900.0) * exp(-abs(p.x) * 80.0);
    float vertical = exp(-abs(p.x) * 900.0) * exp(-abs(p.y) * 80.0);
    return core + horizontal * 0.3 + vertical * 0.3;
}

vec3 drawMoon(vec2 uv, vec3 col)
{
    vec2 moonPos = vec2(0.28, 0.18);
    float radius = 0.22;
    float d = length(uv - moonPos);

    float glow = exp(-d * 5.0);
    col += vec3(0.32, 0.40, 0.72) * glow * 0.50;

    float moon = 1.0 - smoothstep(radius, radius + 0.006, d);
    vec2 p = (uv - moonPos) / radius;

    float surface = fbm(p * 4.0);
    float surface2 = fbm(p * 9.0);

    vec3 moonDark = vec3(0.52, 0.57, 0.68);
    vec3 moonLight = vec3(0.95, 0.94, 0.85);
    vec3 moonColor = mix(moonDark, moonLight, surface);
    moonColor += surface2 * 0.07;

    col = mix(col, moonColor, moon);

    vec2 c1 = p - vec2(-0.32, 0.20);
    vec2 c2 = p - vec2(0.32, 0.28);
    vec2 c3 = p - vec2(0.18, -0.32);
    vec2 c4 = p - vec2(-0.42, -0.25);
    vec2 c5 = p - vec2(0.02, 0.02);
    vec2 c6 = p - vec2(0.48, -0.05);

    float crater1 = 1.0 - smoothstep(0.15, 0.22, length(c1));
    float crater2 = 1.0 - smoothstep(0.10, 0.16, length(c2));
    float crater3 = 1.0 - smoothstep(0.12, 0.19, length(c3));
    float crater4 = 1.0 - smoothstep(0.08, 0.14, length(c4));
    float crater5 = 1.0 - smoothstep(0.07, 0.12, length(c5));
    float crater6 = 1.0 - smoothstep(0.06, 0.11, length(c6));

    float craters = max(max(crater1, crater2),
                    max(crater3, max(crater4, max(crater5, crater6))));
    craters *= moon;

    col = mix(col, col * 0.70, craters * 0.28);

    float rim = smoothstep(radius + 0.012, radius, d);
    rim *= smoothstep(radius - 0.025, radius, d);
    col += vec3(0.65, 0.72, 1.0) * rim * 0.25;

    return col;
}

float cloud(vec2 uv, float y, float speed, float scale)
{
    vec2 p = uv;
    p.x += iTime * speed;

    float n = fbm(vec2(p.x * scale, p.y * scale * 2.0));
    float shape = smoothstep(0.53, 0.70, n);
    shape *= exp(-abs(uv.y - y) * 7.0);

    return shape;
}

float shootingStar(vec2 uv, float offset)
{
    float t = mod(iTime * 0.20 + offset, 3.0);
    vec2 pos = vec2(1.2 - t, 0.50 - t * 0.28);
    vec2 p = uv - pos;

    float line = abs(p.y - p.x * 0.28);
    float tail = exp(-line * 250.0);
    tail *= exp(-abs(p.x) * 8.0);
    tail *= step(0.0, p.x);

    float head = exp(-length(p) * 300.0);

    return tail * 0.45 + head;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float gradient = clamp(uv.y + 0.55, 0.0, 1.0);

    vec3 skyBottom = vec3(0.07, 0.08, 0.22);
    vec3 skyTop = vec3(0.005, 0.008, 0.045);
    vec3 col = mix(skyBottom, skyTop, gradient);

    float purpleGlow =
        exp(-length((uv - vec2(-0.35, 0.05)) * vec2(0.7, 1.3)) * 2.0);

    col += vec3(0.08, 0.025, 0.14) * purpleGlow;

    vec2 galaxyUV = uv;
    galaxyUV.y += galaxyUV.x * 0.38;

    float galaxy = exp(-abs(galaxyUV.y - 0.05) * 5.5);
    float galaxyNoise = fbm(galaxyUV * 4.0);
    galaxy *= galaxyNoise;

    col += vec3(0.10, 0.12, 0.30) * galaxy * 0.50;
    col += vec3(0.15, 0.04, 0.20) * galaxy * galaxyNoise * 0.22;

    for(int i = 0; i < 100; i++)
    {
        float id = float(i);

        vec2 starPos =
            vec2(-1.25 + hash(id + 10.0) * 2.50,
                 -0.55 + hash(id + 30.0) * 1.25);

        float brightness =
            0.50 + 0.50 *
            sin(iTime * (0.5 + hash(id + 50.0) * 2.0) + id);

        float d = length(uv - starPos);
        float s = exp(-d * 650.0);

        vec3 starColor =
            mix(vec3(0.55, 0.68, 1.0),
                vec3(1.0, 0.90, 0.72),
                hash(id + 70.0));

        col += starColor * s * brightness;
    }

    for(int i = 0; i < 15; i++)
    {
        float id = float(i);

        vec2 starPos =
            vec2(-1.1 + hash(id + 120.0) * 2.2,
                 -0.40 + hash(id + 140.0) * 1.05);

        float twinkle =
            0.55 + 0.45 *
            sin(iTime * (0.7 + hash(id + 160.0)) + id * 3.0);

        float s =
            starShape(uv, starPos, 1.0 + hash(id) * 1.5);

        col += vec3(0.65, 0.78, 1.0) * s * twinkle * 0.70;
    }

    col = drawMoon(uv, col);

    vec2 moonPos = vec2(0.28, 0.18);

    float moonDist =
        length((uv - moonPos) * vec2(0.8, 1.0));

    float moonGlow = exp(-moonDist * 2.0);
    float pulse = 0.90 + 0.10 * sin(iTime * 0.35);

    col += vec3(0.08, 0.12, 0.30) * moonGlow * pulse;

    float cloud1 = cloud(uv, -0.10, 0.008, 2.0);

    col =
        mix(col,
            vec3(0.12, 0.14, 0.24),
            cloud1 * 0.20);

    float cloud2 = cloud(uv, 0.18, 0.015, 2.6);
    float moonCloudLight = exp(-moonDist * 3.5);

    vec3 cloudColor =
        mix(vec3(0.08, 0.10, 0.18),
            vec3(0.40, 0.46, 0.65),
            moonCloudLight);

    col =
        mix(col,
            cloudColor,
            cloud2 * 0.22);

    float cloud3 = cloud(uv, -0.38, -0.010, 2.3);

    col =
        mix(col,
            vec3(0.10, 0.11, 0.23),
            cloud3 * 0.30);

    float meteor1 = shootingStar(uv, 0.0);
    float meteor2 = shootingStar(uv + vec2(0.55, -0.25), 1.6);

    col += vec3(0.60, 0.75, 1.0) * meteor1 * 0.8;
    col += vec3(0.85, 0.65, 1.0) * meteor2 * 0.5;

    float nightPulse = 0.96 + 0.04 * sin(iTime * 0.25);
    col *= nightPulse;

    float vignette =
        1.0 - dot(uv * 0.45, uv * 0.45);

    col *= clamp(vignette, 0.60, 1.0);

    col *= 1.20;

    col =
        pow(max(col, vec3(0.0)),
            vec3(0.88));

    fragColor = vec4(col, 1.0);
}
