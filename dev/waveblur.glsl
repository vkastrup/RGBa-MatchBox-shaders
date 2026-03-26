//RGBa
// WaveBlur — Parametric Wave Blur
// Version 1.0

uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h;

uniform float size;        // kernel scale in pixels
uniform int   mode;        // 0=Petal, 1=Lissajous, 2=Spiral
uniform float complexity;  // petals / Lissajous freq ratio / spiral turns
uniform float wave_amp;    // wave modulation depth
uniform float twist;       // vortex twist (rotates kernel by distance)
uniform float rotation;    // global kernel rotation in degrees
uniform float chroma;      // chromatic aberration (R/B radial scale split)
uniform int   samples;     // sample count (quality)

void main() {
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    vec2 uv  = gl_FragCoord.xy / res;

    float rot_rad = rotation * 0.01745329;
    float n       = float(samples);

    float r_sum = 0.0, g_sum = 0.0, b_sum = 0.0;

    vec4 origin = texture2D(Input1, uv);
    r_sum += origin.r;
    g_sum += origin.g;
    b_sum += origin.b;
    float total = 1.0;

    for (int i = 0; i < samples; i++) {
        float t = 6.283185 * float(i) / n;

        vec2 kp;

        if (mode == 0) {
            float r = size * abs(cos(complexity * t));
            r *= 1.0 + wave_amp * 0.4 * cos(complexity * 2.0 * t + 1.0472);
            float a = t + rot_rad;
            a += twist * (r * r) / (size * size + 0.001);
            kp = vec2(cos(a), sin(a)) * r;

        } else if (mode == 1) {
            float phase = wave_amp * 1.5708;
            kp = size * vec2(sin(complexity * t + phase), sin(t));
            float r   = length(kp);
            float a   = atan(kp.y, kp.x) + rot_rad + twist * (r * r) / (size * size + 0.001);
            kp = vec2(cos(a), sin(a)) * r;

        } else {
            float r = size * (t / 6.283185) * (1.0 + wave_amp * sin(complexity * t));
            float a = t * max(complexity, 1.0) + rot_rad + twist * (r * r) / (size * size + 0.001);
            kp = vec2(cos(a), sin(a)) * r;
        }

        float ca   = 1.0 + chroma * 0.07;
        vec2 uv_r  = uv + kp * ca  / res;
        vec2 uv_g  = uv + kp        / res;
        vec2 uv_b  = uv + kp / ca  / res;

        r_sum += texture2D(Input1, uv_r).r;
        g_sum += texture2D(Input1, uv_g).g;
        b_sum += texture2D(Input1, uv_b).b;
        total += 1.0;
    }

    vec4 src = texture2D(Input1, uv);
    vec3 result = vec3(r_sum, g_sum, b_sum) / total;

    gl_FragColor = vec4(result, src.a);
}
