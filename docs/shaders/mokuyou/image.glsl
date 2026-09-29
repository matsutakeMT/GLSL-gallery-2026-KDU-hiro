#define PI 3.14159265

// ======================================================
// ランダム
// ======================================================

float hash(float n)
{
    return fract(sin(n * 127.1) * 43758.5453);
}

float hash21(vec2 p)
{
    p = fract(p * vec2(123.34,456.21));
    p += dot(p,p+45.32);
    return fract(p.x*p.y);
}

// ======================================================
// 回転
// ======================================================

mat2 rot(float a)
{
    float s = sin(a);
    float c = cos(a);

    return mat2(c,-s,s,c);
}

// ======================================================
// ノイズ
// ======================================================

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f*f*(3.0-2.0*f);

    float a = hash21(i);
    float b = hash21(i+vec2(1.0,0.0));
    float c = hash21(i+vec2(0.0,1.0));
    float d = hash21(i+vec2(1.0,1.0));

    return mix(
        mix(a,b,f.x),
        mix(c,d,f.x),
        f.y
    );
}

// ======================================================
// FBM
// ======================================================

float fbm(vec2 p)
{
    float value = 0.0;
    float amplitude = 0.5;

    for(int i=0;i<5;i++)
    {
        value += noise(p)*amplitude;

        p *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// ======================================================
// ギザギザした山
// ======================================================

float mountainShape(vec2 uv)
{
    float n1 =
        fbm(
            vec2(
                uv.x*2.5,
                2.0
            )
        );

    float n2 =
        fbm(
            vec2(
                uv.x*8.0,
                4.0
            )
        );

    float mountain =
        -0.03
        + n1*0.42
        + n2*0.10;

    mountain +=
        abs(
            sin(
                uv.x*18.0
            )
        )*0.035;

    mountain +=
        abs(
            sin(
                uv.x*43.0
            )
        )*0.012;

    return smoothstep(
        mountain,
        mountain-0.02,
        uv.y
    );
}

// ======================================================
// 巨大な木の幹
// ======================================================

float giantTrunk(
    vec2 uv,
    float x,
    float width,
    float bend
)
{
    float center =
        x
        + sin(
            uv.y*2.5+bend
        )*0.035;

    float w =
        width
        - uv.y*0.025;

    float bark =
        noise(
            vec2(
                uv.y*8.0,
                x*10.0
            )
        )*0.025;

    w += bark;

    return
        1.0 -
        smoothstep(
            w,
            w+0.018,
            abs(
                uv.x-center
            )
        );
}

// ======================================================
// 枝
// ======================================================

float branch(
    vec2 uv,
    vec2 start,
    float angle,
    float lengthValue,
    float width
)
{
    vec2 p =
        uv-start;

    p =
        rot(-angle)*p;

    float branchWidth =
        width*
        (
            1.0-
            clamp(
                p.x/lengthValue,
                0.0,
                1.0
            )*0.7
        );

    float shape =
        1.0 -
        smoothstep(
            branchWidth,
            branchWidth+0.015,
            abs(p.y)
        );

    shape *=
        smoothstep(
            0.0,
            0.03,
            p.x
        );

    shape *=
        1.0 -
        smoothstep(
            lengthValue-0.05,
            lengthValue,
            p.x
        );

    return shape;
}

// ======================================================
// 針葉樹
// ======================================================

float pineTree(
    vec2 uv,
    vec2 pos,
    float scale
)
{
    vec2 p =
        (uv-pos)/scale;

    float trunk =
        1.0 -
        smoothstep(
            0.025,
            0.04,
            abs(p.x)
        );

    trunk *=
        smoothstep(
            -0.55,
            -0.40,
            p.y
        );

    trunk *=
        1.0 -
        smoothstep(
            0.95,
            1.05,
            p.y
        );

    float crown = 0.0;

    for(int i=0;i<8;i++)
    {
        float fi =
            float(i);

        float y =
            -0.05+
            fi*0.12;

        float width =
            0.34-
            fi*0.032;

        float yy =
            abs(
                p.y-y
            );

        float w =
            width-
            yy*0.85;

        float layer =
            1.0-
            smoothstep(
                w,
                w+0.025,
                abs(p.x)
            );

        layer *=
            1.0-
            smoothstep(
                0.09,
                0.15,
                yy
            );

        crown =
            max(
                crown,
                layer
            );
    }

    return max(
        trunk,
        crown
    );
}

// ======================================================
// 岩
// ======================================================

float rock(
    vec2 uv,
    vec2 pos,
    vec2 size
)
{
    vec2 p =
        (uv-pos)/size;

    float n =
        noise(p*3.0)*0.16;

    float d =
        length(p)+n;

    return
        1.0-
        smoothstep(
            0.82,
            1.0,
            d
        );
}

// ======================================================
// 葉っぱの形
// ======================================================

float leafShape(vec2 p)
{
    p.x *= 1.7;

    float d1 =
        length(
            p-
            vec2(
                0.16,
                0.0
            )
        );

    float d2 =
        length(
            p+
            vec2(
                0.16,
                0.0
            )
        );

    return
        max(d1,d2)-0.32;
}

// ======================================================
// 葉っぱを描く
// ======================================================

vec3 drawLeaf(
    vec2 uv,
    vec2 position,
    float size,
    float angle,
    vec3 leafColor,
    vec3 background
)
{
    vec2 p =
        uv-position;

    p =
        rot(angle)*p;

    p /= size;

    float d =
        leafShape(p);

    float leaf =
        1.0-
        smoothstep(
            -0.025,
            0.025,
            d
        );

    float vein =
        1.0-
        smoothstep(
            0.015,
            0.035,
            abs(p.y)
        );

    vein *= leaf;

    vec3 color =
        leafColor;

    color =
        mix(
            color,
            color*0.35,
            vein*0.35
        );

    return mix(
        background,
        color,
        leaf
    );
}

// ======================================================
// メイン
// ======================================================

void mainImage(
    out vec4 fragColor,
    in vec2 fragCoord
)
{
    vec2 uv =
        (
            fragCoord-
            0.5*iResolution.xy
        )/
        iResolution.y;

    float skyAmount =
        clamp(
            uv.y+0.5,
            0.0,
            1.0
        );

    vec3 skyBottom =
        vec3(
            0.45,
            0.55,
            0.43
        );

    vec3 skyTop =
        vec3(
            0.08,
            0.18,
            0.20
        );

    vec3 col =
        mix(
            skyBottom,
            skyTop,
            skyAmount
        );

    vec2 lightPos =
        vec2(
            0.05,
            0.30
        );

    float lightDist =
        length(
            (
                uv-lightPos
            )*
            vec2(
                1.0,
                0.75
            )
        );

    float glow =
        exp(
            -lightDist*3.5
        );

    col +=
        vec3(
            0.95,
            0.85,
            0.58
        )*
        glow*
        0.38;

    float lightBeam =
        exp(
            -abs(
                uv.x-lightPos.x
            )*6.0
        );

    lightBeam *=
        smoothstep(
            -0.35,
            0.50,
            uv.y
        );

    float beamNoise =
        fbm(
            vec2(
                uv.x*5.0,
                uv.y*2.0+
                iTime*0.02
            )
        );

    lightBeam *=
        0.55+
        beamNoise*0.45;

    col +=
        vec3(
            0.90,
            0.83,
            0.58
        )*
        lightBeam*
        0.13;

    // 回転する太陽の光
    float lightRotation =
        iTime*0.10;

    float lightAngle =
        atan(
            uv.y-lightPos.y,
            uv.x-lightPos.x
        );

    lightAngle +=
        lightRotation;

    float rays =
        sin(
            lightAngle*12.0
        );

    rays =
        smoothstep(
            0.20,
            1.0,
            rays
        );

    rays *=
        exp(
            -lightDist*1.8
        );

    float rayNoise =
        fbm(
            vec2(
                lightAngle*3.0,
                iTime*0.08
            )
        );

    rays *=
        0.65+
        rayNoise*0.50;

    col +=
        vec3(
            1.0,
            0.82,
            0.48
        )*
        rays*
        0.24;

    float forestLight =
        0.92+
        0.08*
        sin(
            iTime*0.35
        );

    col *=
        forestLight;

    float mountains =
        mountainShape(
            uv+
            vec2(
                0.0,
                0.08
            )
        );

    col =
        mix(
            col,
            vec3(
                0.13,
                0.24,
                0.20
            ),
            mountains*0.60
        );

    for(int i=0;i<26;i++)
    {
        float id =
            float(i);

        float x =
            -1.50+
            id*0.12;

        float scale =
            0.30+
            hash(
                id+20.0
            )*0.25;

        float t =
            pineTree(
                uv,
                vec2(
                    x,
                    -0.13
                ),
                scale
            );

        vec3 distantTree =
            vec3(
                0.07,
                0.18,
                0.10
            );

        col =
            mix(
                col,
                distantTree,
                t*0.70
            );
    }

    float fog =
        fbm(
            vec2(
                uv.x*3.0+
                iTime*0.015,
                uv.y*4.0
            )
        );

    fog *=
        exp(
            -abs(
                uv.y+0.03
            )*4.5
        );

    col =
        mix(
            col,
            vec3(
                0.55,
                0.63,
                0.52
            ),
            fog*0.20
        );

    float leftTrunk =
        giantTrunk(
            uv,
            -0.75,
            0.16,
            1.0
        );

    float rightTrunk =
        giantTrunk(
            uv,
            0.78,
            0.18,
            2.5
        );

    float leftTrunk2 =
        giantTrunk(
            uv,
            -0.47,
            0.08,
            4.0
        );

    float rightTrunk2 =
        giantTrunk(
            uv,
            0.50,
            0.09,
            5.0
        );

    float trunks =
        max(
            max(
                leftTrunk,
                rightTrunk
            ),
            max(
                leftTrunk2,
                rightTrunk2
            )
        );

    float branches =
        0.0;

    branches =
        max(
            branches,
            branch(
                uv,
                vec2(-0.72,0.22),
                0.40,
                0.55,
                0.055
            )
        );

    branches =
        max(
            branches,
            branch(
                uv,
                vec2(-0.72,0.38),
                -0.35,
                0.48,
                0.045
            )
        );

    branches =
        max(
            branches,
            branch(
                uv,
                vec2(0.75,0.25),
                2.70,
                0.55,
                0.055
            )
        );

    branches =
        max(
            branches,
            branch(
                uv,
                vec2(0.76,0.40),
                3.55,
                0.48,
                0.045
            )
        );

    float giantTrees =
        max(
            trunks,
            branches
        );

    float barkTexture =
        fbm(
            uv*
            vec2(
                15.0,
                7.0
            )
        );

    vec3 barkDark =
        vec3(
            0.055,
            0.075,
            0.045
        );

    vec3 barkLight =
        vec3(
            0.15,
            0.16,
            0.09
        );

    vec3 barkColor =
        mix(
            barkDark,
            barkLight,
            barkTexture
        );

    float treeLight =
        0.82+
        0.18*
        max(
            sin(
                lightAngle*4.0
            ),
            0.0
        );

    barkColor *=
        treeLight;

    col =
        mix(
            col,
            barkColor,
            giantTrees
        );

    float ground =
        smoothstep(
            -0.20,
            -0.44,
            uv.y
        );

    float groundTexture =
        fbm(
            uv*12.0
        );

    vec3 groundDark =
        vec3(
            0.045,
            0.09,
            0.035
        );

    vec3 groundLight =
        vec3(
            0.16,
            0.22,
            0.07
        );

    vec3 groundColor =
        mix(
            groundDark,
            groundLight,
            groundTexture
        );

    float movingGroundLight =
        sin(
            uv.x*7.0+
            lightRotation*5.0
        );

    movingGroundLight =
        smoothstep(
            0.20,
            1.0,
            movingGroundLight
        );

    groundColor +=
        vec3(
            0.25,
            0.21,
            0.07
        )*
        movingGroundLight*
        0.16;

    float groundGlow =
        exp(
            -abs(
                uv.x
            )*3.0
        );

    groundGlow *=
        smoothstep(
            -0.15,
            -0.50,
            uv.y
        );

    groundColor +=
        vec3(
            0.28,
            0.25,
            0.10
        )*
        groundGlow*
        0.35;

    col =
        mix(
            col,
            groundColor,
            ground
        );

    for(int i=0;i<12;i++)
    {
        float id =
            float(i);

        float x =
            -0.95+
            hash(
                id+80.0
            )*1.90;

        float y =
            -0.32-
            hash(
                id+100.0
            )*0.20;

        float size =
            0.045+
            hash(
                id+120.0
            )*0.09;

        float r =
            rock(
                uv,
                vec2(
                    x,
                    y
                ),
                vec2(
                    size,
                    size*0.60
                )
            );

        vec3 rockColor =
            mix(
                vec3(
                    0.10,
                    0.11,
                    0.08
                ),
                vec3(
                    0.15,
                    0.23,
                    0.07
                ),
                hash(id)
            );

        col =
            mix(
                col,
                rockColor,
                r
            );
    }

    float groundFog =
        fbm(
            vec2(
                uv.x*3.0+
                iTime*0.025,
                uv.y*7.0
            )
        );

    groundFog *=
        exp(
            -abs(
                uv.y+0.22
            )*9.0
        );

    col =
        mix(
            col,
            vec3(
                0.62,
                0.68,
                0.57
            ),
            groundFog*0.17
        );

    // 大きめの舞い落ちる葉
    for(int i=0;i<32;i++)
    {
        float id =
            float(i);

        float r1 =
            hash(id+1.0);

        float r2 =
            hash(id+20.0);

        float r3 =
            hash(id+40.0);

        float r4 =
            hash(id+60.0);

        float speed =
            0.025+
            r2*0.045;

        float y =
            0.85-
            mod(
                iTime*speed+
                r1*1.7,
                1.7
            );

        float wind =
            sin(
                iTime*
                (
                    0.25+
                    r3*0.35
                )
                +
                id*2.0
            );

        wind *=
            0.08+
            r4*0.06;

        float x =
            -0.95+
            r1*1.90+
            wind;

        vec2 leafPos =
            vec2(
                x,
                y
            );

        float leafAngle =
            iTime*
            (
                0.15+
                r3*0.45
            )
            +
            r4*PI*2.0;

        float leafSize =
            0.030+
            r2*0.050;

        vec3 green =
            vec3(
                0.24,
                0.38,
                0.07
            );

        vec3 gold =
            vec3(
                0.75,
                0.52,
                0.08
            );

        vec3 orange =
            vec3(
                0.70,
                0.27,
                0.04
            );

        vec3 darkRed =
            vec3(
                0.48,
                0.09,
                0.035
            );

        vec3 leafColor;

        if(r3 < 0.25)
        {
            leafColor =
                green;
        }
        else if(r3 < 0.55)
        {
            leafColor =
                gold;
        }
        else if(r3 < 0.80)
        {
            leafColor =
                orange;
        }
        else
        {
            leafColor =
                darkRed;
        }

        float leafLight =
            0.85+
            0.25*
            max(
                sin(
                    lightAngle+
                    id
                ),
                0.0
            );

        leafColor *=
            leafLight;

        col =
            drawLeaf(
                uv,
                leafPos,
                leafSize,
                leafAngle,
                leafColor,
                col
            );
    }

    // 神秘的な光の粒
    for(int i=0;i<30;i++)
    {
        float id =
            float(i);

        vec2 particlePos =
            vec2(
                -0.90+
                hash(
                    id+140.0
                )*1.80,
                -0.25+
                hash(
                    id+160.0
                )*1.10
            );

        particlePos.x +=
            sin(
                iTime*0.15+
                id
            )*0.015;

        particlePos.y +=
            sin(
                iTime*0.20+
                id*1.5
            )*0.02;

        float particle =
            length(
                uv-
                particlePos
            );

        particle =
            exp(
                -particle*220.0
            );

        float particleLight =
            0.75+
            0.25*
            sin(
                iTime*0.35
            );

        col +=
            vec3(
                1.0,
                0.78,
                0.38
            )*
            particle*
            0.40*
            particleLight;
    }

    float centerLight =
        exp(
            -length(
                (
                    uv-
                    vec2(
                        0.03,
                        0.02
                    )
                )*
                vec2(
                    1.4,
                    0.8
                )
            )*3.0
        );

    col +=
        vec3(
            0.42,
            0.38,
            0.20
        )*
        centerLight*
        0.18;

    float finalLight =
        0.94+
        0.06*
        sin(
            iTime*0.35
        );

    col *=
        finalLight;

    float vignette =
        1.0-
        dot(
            uv*0.55,
            uv*0.55
        );

    col *=
        clamp(
            vignette,
            0.52,
            1.0
        );

    col *=
        1.18;

    col +=
        vec3(
            0.025,
            0.030,
            0.018
        );

    col =
        pow(
            max(
                col,
                vec3(0.0)
            ),
            vec3(0.88)
        );

    fragColor =
        vec4(
            col,
            1.0
        );
}
