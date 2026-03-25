//RGBa
// Diffusion — Random Scatter Blur - Matchbox Shader for Autodesk Flame
// Version 0.2
// Random disc-sample blur with optional edge-preserving mask.
// Edge mask restricts diffusion to flat areas, leaving edges sharp.

uniform float adsk_result_w, adsk_result_h;
uniform sampler2D input1;

uniform float radius;
uniform int   iterations;
uniform float strength;
uniform bool  enable_edge_mask;
uniform float edge_threshold;

// ITU-R BT.709 luminance
float luma(vec3 c) {
    return dot(vec3(0.2126, 0.7152, 0.0722), c);
}

// 2D hash — golden-ratio offsets per iteration break per-pixel correlation
float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 74.27);
    return fract(p.x * p.y);
}

// Sobel edge magnitude using BT.709 luminance
float sobel_edge(vec2 uv, vec2 texel) {
    float tl = luma(texture2D(input1, uv + texel * vec2(-1,  1)).rgb);
    float l  = luma(texture2D(input1, uv + texel * vec2(-1,  0)).rgb);
    float bl = luma(texture2D(input1, uv + texel * vec2(-1, -1)).rgb);
    float t  = luma(texture2D(input1, uv + texel * vec2( 0,  1)).rgb);
    float b  = luma(texture2D(input1, uv + texel * vec2( 0, -1)).rgb);
    float tr = luma(texture2D(input1, uv + texel * vec2( 1,  1)).rgb);
    float r  = luma(texture2D(input1, uv + texel * vec2( 1,  0)).rgb);
    float br = luma(texture2D(input1, uv + texel * vec2( 1, -1)).rgb);

    float x = tl + 2.0*l + bl - tr - 2.0*r - br;
    float y = -tl - 2.0*t - tr + bl + 2.0*b + br;
    return sqrt(x*x + y*y);
}

void main() {
    vec2 res    = vec2(adsk_result_w, adsk_result_h);
    vec2 uv     = gl_FragCoord.xy / res;
    vec4 src    = texture2D(input1, uv);

    vec3 sum         = vec3(0.0);
    float total      = 0.0;

    // Golden ratio offsets decorrelate samples across iterations per pixel
    // Each iteration i uses a unique directional seed, different per pixel via uv
    for (int i = 0; i < iterations; i++) {
        float fi = float(i);
        float r1 = hash(uv + vec2(fi * 0.61803398875, fi * 0.38196601125));
        float r2 = hash(uv + vec2(fi * 0.38196601125 + 0.5, fi * 0.61803398875 + 0.5));

        float angle = r1 * 6.283185;
        float dist  = sqrt(r2) * radius; // sqrt = uniform disc distribution

        vec2 offset       = vec2(cos(angle), sin(angle)) * dist / res;
        sum              += texture2D(input1, uv + offset).rgb;
        total            += 1.0;
    }

    vec3 blurred    = sum / total;

    float mix_factor = strength;
    if (enable_edge_mask) {
        vec2 texel = 1.0 / res;
        float edge = sobel_edge(uv, texel);
        // Invert: strong edges → less diffusion, flat areas → full diffusion
        mix_factor *= 1.0 - smoothstep(0.0, edge_threshold, edge);
    }

    vec3 result = mix(src.rgb, blurred, clamp(mix_factor, 0.0, 1.0));
    gl_FragColor = vec4(result, src.a);
}
