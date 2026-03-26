//RGBa
// Dither — Combined Dither Shade
// Version 1.0
//
// Six dither algorithms in one shader

uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h, adsk_time;

uniform int   algo;         // 0=Bayer2, 1=Bayer4, 2=Bayer8, 3=White Noise, 4=IGN, 5=Error Diffusion
uniform int   levels;       // quantization steps (2 = B&W)
uniform float spread;       // dither amplitude (scales threshold offset)
uniform bool  color_mode;   // false = luma -> B&W, true = per-channel color
uniform bool  temporal;     // animate threshold per frame with golden ratio offset
uniform int   scan_size;    // error diffusion: window size in pixels each direction
uniform float error_carry;  // error diffusion: how much error propagates forward

const float bayer2[4] = float[](
    0.0/4.0,  2.0/4.0,
    3.0/4.0,  1.0/4.0
);

const float bayer4[16] = float[](
     0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
    12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
     3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
    15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

const float bayer8[64] = float[](
     0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
    48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
    12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
    60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
     3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
    51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
    15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
    63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
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

float quantize1(float v, float q, float d) {
    return clamp(floor(v * q + 0.5 + d) / q, 0.0, 1.0);
}

vec3 quantize3(vec3 v, float q, float d) {
    return clamp(floor(v * q + 0.5 + d) / q, vec3(0.0), vec3(1.0));
}

void main() {
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    vec2 uv  = gl_FragCoord.xy / res;
    vec4 src = texture2D(Input1, uv);
    vec3 color = src.rgb;

    float q = max(float(levels) - 1.0, 1.0);

    float threshold = 0.5;

    if (algo == 0) {
        int x = int(mod(gl_FragCoord.x, 2.0));
        int y = int(mod(gl_FragCoord.y, 2.0));
        threshold = bayer2[y * 2 + x];

    } else if (algo == 1) {
        int x = int(mod(gl_FragCoord.x, 4.0));
        int y = int(mod(gl_FragCoord.y, 4.0));
        threshold = bayer4[y * 4 + x];

    } else if (algo == 2) {
        int x = int(mod(gl_FragCoord.x, 8.0));
        int y = int(mod(gl_FragCoord.y, 8.0));
        threshold = bayer8[y * 8 + x];

    } else if (algo == 3) {
        threshold = hash(gl_FragCoord.xy);

    } else if (algo == 4) {
        threshold = ign(gl_FragCoord.xy);
    }

    if (temporal && algo < 5) {
        threshold = fract(threshold + fract(adsk_time * 0.6180339));
    }

    float d = (threshold - 0.5) * spread;

    vec3 result;

    if (algo == 5) {
        if (!color_mode) {
            float xErr = 0.0;
            for (int j = 0; j < scan_size; j++) {
                vec2 p = (gl_FragCoord.xy + vec2(float(-scan_size + j), 0.0)) / res;
                float luma = dot(vec3(0.2126, 0.7152, 0.0722), texture2D(Input1, p).rgb);
                luma += xErr;
                float bit = clamp(floor(luma * q + 0.5) / q, 0.0, 1.0);
                xErr = (luma - bit) * error_carry;
            }
            float yErr = 0.0;
            for (int j = 0; j < scan_size; j++) {
                vec2 p = (gl_FragCoord.xy + vec2(0.0, float(-scan_size + j))) / res;
                float luma = dot(vec3(0.2126, 0.7152, 0.0722), texture2D(Input1, p).rgb);
                luma += yErr;
                float bit = clamp(floor(luma * q + 0.5) / q, 0.0, 1.0);
                yErr = (luma - bit) * error_carry;
            }
            float srcLuma = dot(vec3(0.2126, 0.7152, 0.0722), color);
            float v = clamp(floor((srcLuma + xErr * 0.5 + yErr * 0.5) * q + 0.5) / q, 0.0, 1.0);
            result = vec3(v);

        } else {
            vec3 xErr = vec3(0.0);
            for (int j = 0; j < scan_size; j++) {
                vec2 p = (gl_FragCoord.xy + vec2(float(-scan_size + j), 0.0)) / res;
                vec3 s = texture2D(Input1, p).rgb + xErr;
                vec3 bit = clamp(floor(s * q + 0.5) / q, vec3(0.0), vec3(1.0));
                xErr = (s - bit) * error_carry;
            }
            vec3 yErr = vec3(0.0);
            for (int j = 0; j < scan_size; j++) {
                vec2 p = (gl_FragCoord.xy + vec2(0.0, float(-scan_size + j))) / res;
                vec3 s = texture2D(Input1, p).rgb + yErr;
                vec3 bit = clamp(floor(s * q + 0.5) / q, vec3(0.0), vec3(1.0));
                yErr = (s - bit) * error_carry;
            }
            result = clamp(floor((color + xErr * 0.5 + yErr * 0.5) * q + 0.5) / q, vec3(0.0), vec3(1.0));
        }

    } else {
        if (!color_mode) {
            float luma = dot(vec3(0.2126, 0.7152, 0.0722), color);
            result = vec3(quantize1(luma, q, d));
        } else {
            result = quantize3(color, q, d);
        }
    }

    gl_FragColor = vec4(result, src.a);
}
