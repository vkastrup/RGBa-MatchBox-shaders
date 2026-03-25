//RGBa
// WaveBlur — Parametric Wave Blur - Matchbox Shader for Autodesk Flame
// Version 1.0
//
// Three kernel modes, each sampling along a different parametric wave curve:
//
//   Petal    — Rose/Rhodonea curve. Samples trace N-petal flower shapes.
//              Complexity controls petal count (non-integer values give
//              partial/spiral petals — try floats for interesting forms).
//
//   Lissajous — Samples trace Lissajous figures (figure-8s, knots, pretzel
//               shapes). Complexity sets the x:y frequency ratio.
//               WaveAmp controls the phase offset — the key parameter for
//               this mode (0=degenerate line, 0.5=figure-8, 1=classic knot).
//
//   Spiral   — Archimedean spiral with a sine-wave radial modulation.
//              Complexity sets turns. WaveAmp controls how wavy the spiral
//              arms are. High WaveAmp causes the arms to fold back on
//              themselves, creating dense interference patterns.
//
// Twist warps all modes by rotating each sample point proportionally to its
// distance from centre — turns any kernel into a vortex/galaxy form.
//
// Chroma splits R/G/B samples to slightly different radial scales, adding
// chromatic fringing to the blur trails.

uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h;

uniform float size;        // kernel scale in pixels
uniform int   samples;     // sample count (quality)
uniform int   mode;        // 0=Petal, 1=Lissajous, 2=Spiral
uniform float complexity;  // petals / Lissajous freq ratio / spiral turns
uniform float wave_amp;    // wave modulation depth
uniform float twist;       // vortex twist (rotates kernel by distance)
uniform float rotation;    // global kernel rotation in degrees
uniform float chroma;      // chromatic aberration (R/B radial scale split)

void main() {
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    vec2 uv  = gl_FragCoord.xy / res;

    float rot_rad = rotation * 0.01745329;
    float n       = float(samples);

    float r_sum = 0.0, g_sum = 0.0, b_sum = 0.0;

    // Include the origin pixel
    vec4 origin = texture2D(Input1, uv);
    r_sum += origin.r;
    g_sum += origin.g;
    b_sum += origin.b;
    float total = 1.0;

    for (int i = 0; i < samples; i++) {
        // Evenly spaced parameter t from 0 to 2π
        float t = 6.283185 * float(i) / n;

        vec2 kp; // kernel position in pixel space

        if (mode == 0) {
            // --- Petal (Rose / Rhodonea) ---
            // r = size * |cos(complexity * t)|
            // Non-integer complexity: partial/spiral petals
            float r = size * abs(cos(complexity * t));
            // WaveAmp adds a secondary ripple on the petal radius
            r *= 1.0 + wave_amp * 0.4 * cos(complexity * 2.0 * t + 1.0472);
            float a = t + rot_rad;
            // Twist: quadratic — inner samples barely move, outer arms sweep
            a += twist * (r * r) / (size * size + 0.001);
            kp = vec2(cos(a), sin(a)) * r;

        } else if (mode == 1) {
            // --- Lissajous ---
            // x = sin(c*t + phase),  y = sin(t)
            // WaveAmp controls phase offset (0=line, 0.5=figure-8, 1=knot)
            float phase = wave_amp * 1.5708; // 0 to π/2
            kp = size * vec2(sin(complexity * t + phase), sin(t));
            // Apply rotation and twist
            float r   = length(kp);
            float a   = atan(kp.y, kp.x) + rot_rad + twist * (r * r) / (size * size + 0.001);
            kp = vec2(cos(a), sin(a)) * r;

        } else {
            // --- Spiral (Archimedean + wave) ---
            // r grows with t; WaveAmp modulates the radius with a sine wave.
            // High complexity = more spiral turns.
            // High WaveAmp = arms fold back on themselves.
            float r = size * (t / 6.283185) * (1.0 + wave_amp * sin(complexity * t));
            float a = t * max(complexity, 1.0) + rot_rad + twist * (r * r) / (size * size + 0.001);
            kp = vec2(cos(a), sin(a)) * r;
        }

        // Chromatic aberration: R and B sampled at slightly different radial scales
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
