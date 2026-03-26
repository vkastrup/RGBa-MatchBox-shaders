//RGBa
// Halation — Film Halation & Bloom
// Version 0.2
//

uniform float adsk_result_w, adsk_result_h;
uniform sampler2D input1;

uniform float threshold;     // minimum luminance to trigger halation
uniform float radius;        // scatter radius in pixels
uniform float softness;      // falloff rate (higher = softer/wider halo)
uniform float hue;           // 0 = pure red halo, 1 = orange halo
uniform float amount;        // halation intensity
uniform float bloom_amount;  // bloom intensity (0 = off)
uniform int   samples;       // sample count (quality)

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 74.27);
    return fract(p.x * p.y);
}

void main() {
    vec2 res  = vec2(adsk_result_w, adsk_result_h);
    vec2 uv   = gl_FragCoord.xy / res;
    vec4 src  = texture2D(input1, uv);

    float src_luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));

    vec3  hal       = vec3(0.0);
    float bloom_acc = 0.0;
    float n         = float(samples);

    for (int i = 0; i < samples; i++) {
        float fi = float(i);

        float r1 = hash(uv + vec2(fi * 0.61803398875, fi * 0.38196601125));
        float r2 = hash(uv + vec2(fi * 0.38196601125 + 0.5, fi * 0.61803398875 + 0.5));

        float angle   = r1 * 6.283185;
        float dist_px = sqrt(r2) * radius;
        vec2  scoord  = uv + vec2(cos(angle), sin(angle)) * dist_px / res;

        float lum    = dot(texture2D(input1, scoord).rgb, vec3(0.2126, 0.7152, 0.0722));
        float excess = max(lum - threshold, 0.0);

        float t  = dist_px / radius;

        float wr = exp(-t * softness);
        float wg = exp(-t * softness * 3.0);

        hal.r += excess * wr;
        hal.g += excess * wg * hue;

        float bloom_falloff = exp(-t * softness * 0.5);
        bloom_acc += excess * bloom_falloff;
    }

    hal       /= n;
    bloom_acc /= n;

    float src_mask = 1.0 - smoothstep(threshold, threshold + 0.3, src_luma);
    hal *= src_mask;

    vec3 bloom_rgb = vec3(bloom_acc) * bloom_amount;

    gl_FragColor = vec4(src.rgb + hal * amount + bloom_rgb, src.a);
}
