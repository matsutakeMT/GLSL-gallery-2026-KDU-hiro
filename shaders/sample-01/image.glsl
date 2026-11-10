// Shadertoy-style fragment shader — only mainImage() is required.
// The engine supplies precision, uniforms and main() automatically, matching
// shadertoy.com: iResolution, iTime, iTimeDelta, iFrame, iFrameRate, iMouse,
// iDate, iChannel0-3, iChannelResolution.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= iResolution.x / iResolution.y;

    float t = iTime * 0.5;
    float v = 0.0;
    v += sin(p.x * 6.0 + t);
    v += sin((p.x * cos(t * 0.3) + p.y * sin(t * 0.2)) * 8.0);
    v += sin(sqrt(p.x * p.x + p.y * p.y + 1.0) * 10.0 - t * 3.0);

    vec3 col = 0.5 + 0.5 * cos(6.2831 * (v * 0.15 + vec3(0.0, 0.33, 0.67)));
    fragColor = vec4(col, 1.0);
}
