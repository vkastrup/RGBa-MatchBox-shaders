//RGBa
// Chobel — Chubby Sobel 5x5 Edge Detection - Matchbox Shader for Autodesk Flame
// Version 0.3
// A 5x5 Sobel that naturally produces fatter edges than 3x3.
// The softness parameter diffuses the edge response by blending each kernel
// tap toward the local neighbourhood mean before convolution — no extra texture fetches.

uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h;

uniform float step_size;   // sample spacing in pixels
uniform float softness;    // 0 = sharp 5x5, 1 = fully diffuse
uniform float threshold;   // clip edges below this value
uniform float gain;        // post-magnitude brightness multiplier
uniform bool  color_edges; // false = BT.709 luminance, true = per-channel colour
uniform bool  output_mode; // false = edge only, true = add edge over source

// 5x5 Sobel kernel weights
const float kernelX[25] = float[25](
    -2.0, -1.0,  0.0,  1.0,  2.0,
    -2.0, -1.0,  0.0,  1.0,  2.0,
    -4.0, -2.0,  0.0,  2.0,  4.0,
    -2.0, -1.0,  0.0,  1.0,  2.0,
    -2.0, -1.0,  0.0,  1.0,  2.0
);

const float kernelY[25] = float[25](
     2.0,  2.0,  4.0,  2.0,  2.0,
     1.0,  1.0,  2.0,  1.0,  1.0,
     0.0,  0.0,  0.0,  0.0,  0.0,
    -1.0, -1.0, -2.0, -1.0, -1.0,
    -2.0, -2.0, -4.0, -2.0, -2.0
);

const vec2 offsets[25] = vec2[25](
    vec2(-2.0,  2.0), vec2(-1.0,  2.0), vec2( 0.0,  2.0), vec2( 1.0,  2.0), vec2( 2.0,  2.0),
    vec2(-2.0,  1.0), vec2(-1.0,  1.0), vec2( 0.0,  1.0), vec2( 1.0,  1.0), vec2( 2.0,  1.0),
    vec2(-2.0,  0.0), vec2(-1.0,  0.0), vec2( 0.0,  0.0), vec2( 1.0,  0.0), vec2( 2.0,  0.0),
    vec2(-2.0, -1.0), vec2(-1.0, -1.0), vec2( 0.0, -1.0), vec2( 1.0, -1.0), vec2( 2.0, -1.0),
    vec2(-2.0, -2.0), vec2(-1.0, -2.0), vec2( 0.0, -2.0), vec2( 1.0, -2.0), vec2( 2.0, -2.0)
);

// ITU-R BT.709 luminance
float luma(vec3 c) {
    return dot(vec3(0.2126, 0.7152, 0.0722), c);
}

void main() {
    vec2 resolution = vec2(adsk_result_w, adsk_result_h);
    vec2 uv  = gl_FragCoord.xy / resolution;
    vec4 src = texture2D(Input1, uv);

    vec2 step = vec2(step_size / resolution.x, step_size / resolution.y);

    vec3 edge;

    if (!color_edges) {
        // --- Luminance path ---
        float samples[25];
        float localAvg = 0.0;
        for (int i = 0; i < 25; i++) {
            samples[i] = luma(texture2D(Input1, uv + offsets[i] * step).rgb);
            localAvg += samples[i];
        }
        localAvg /= 25.0;

        float sumX = 0.0, sumY = 0.0;
        for (int i = 0; i < 25; i++) {
            float s = mix(samples[i], localAvg, softness);
            sumX += s * kernelX[i];
            sumY += s * kernelY[i];
        }
        float mag = sqrt(sumX*sumX + sumY*sumY);
        edge = vec3(mag);

    } else {
        // --- Per-channel colour path ---
        vec3 samples[25];
        vec3 localAvg = vec3(0.0);
        for (int i = 0; i < 25; i++) {
            samples[i] = texture2D(Input1, uv + offsets[i] * step).rgb;
            localAvg += samples[i];
        }
        localAvg /= 25.0;

        vec3 sumX = vec3(0.0), sumY = vec3(0.0);
        for (int i = 0; i < 25; i++) {
            vec3 s = mix(samples[i], localAvg, softness);
            sumX += s * kernelX[i];
            sumY += s * kernelY[i];
        }
        edge = sqrt(sumX*sumX + sumY*sumY);
    }

    // Threshold then gain
    edge = max(edge - vec3(threshold), vec3(0.0)) * gain;

    vec3 result;
    if (!output_mode) {
        result = edge;
    } else {
        result = src.rgb + edge;
    }

    gl_FragColor = vec4(result, src.a);
}
