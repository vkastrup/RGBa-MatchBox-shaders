//RGBa

uniform float adsk_result_w, adsk_result_h;
uniform sampler2D input1;
uniform int levels;
uniform float spread;
uniform int algo;

const float bayer8[64] = float[](
    0.0/64.0, 32.0/64.0, 8.0/64.0, 40.0/64.0, 2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
    48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
    12.0/64.0, 44.0/64.0, 4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0, 6.0/64.0, 38.0/64.0,
    60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
    3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0, 1.0/64.0, 33.0/64.0, 9.0/64.0, 41.0/64.0,
    51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
    15.0/64.0, 47.0/64.0, 7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0, 5.0/64.0, 37.0/64.0,
    63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
);

const float bayer4[16] = float[](
    0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0,
    12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
    3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
    15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
);

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float ign(vec2 p) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(p, magic.xy)));
}

void main()
{
    vec2 coords = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec3 color = texture2D(input1, coords).rgb;

    float threshold = 0.5;

    if (algo == 0) {
        int x = int(mod(gl_FragCoord.x, 8.0));
        int y = int(mod(gl_FragCoord.y, 8.0));
        threshold = bayer8[y * 8 + x];
    } else if (algo == 1) {
        int x = int(mod(gl_FragCoord.x, 4.0));
        int y = int(mod(gl_FragCoord.y, 4.0));
        threshold = bayer4[y * 4 + x];
    } else if (algo == 2) {
        threshold = hash(gl_FragCoord.xy);
    } else if (algo == 3) {
        threshold = ign(gl_FragCoord.xy);
    }

    float dither = (threshold - 0.5) * spread;

    float q = float(levels) - 1.0;
    vec3 quant = floor(color * q + 0.5 + dither) / q;

    gl_FragColor = vec4(quant, 1.0);
}
