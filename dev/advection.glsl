//RGBa
// Advection — Edge-Tangent Flow - Matchbox Shader for Autodesk Flame
// Version 0.2
//
// Two modes:
//   Smear (mode=false): walk along edge tangent, sample at final position.
//                       Good for glass/heat/liquid distortion along edges.
//   Flow  (mode=true):  Line Integral Convolution — bidirectional walk,
//                       accumulate Gaussian-weighted samples along the path.
//                       Produces fibrous, brushstroke-like streaks following
//                       image structure.

uniform float adsk_result_w, adsk_result_h;
uniform sampler2D input1;

uniform float strength;
uniform int   iterations;
uniform float edge_threshold;
uniform bool  mode;          // false = Smear, true = Flow (LIC)
uniform float flow_bias;     // global tangent rotation in degrees

uniform float wave_amp;
uniform float wave_freq;
uniform bool  radial_waves;
uniform vec2  center;        // UV space, 0-1

// ITU-R BT.709 luminance
float luma(vec3 c) {
    return dot(vec3(0.2126, 0.7152, 0.0722), c);
}

// Sobel gradient using BT.709 luminance
vec2 get_gradient(vec2 uv, vec2 texel) {
    float tl = luma(texture2D(input1, uv + texel * vec2(-1,  1)).rgb);
    float l  = luma(texture2D(input1, uv + texel * vec2(-1,  0)).rgb);
    float bl = luma(texture2D(input1, uv + texel * vec2(-1, -1)).rgb);
    float t  = luma(texture2D(input1, uv + texel * vec2( 0,  1)).rgb);
    float b  = luma(texture2D(input1, uv + texel * vec2( 0, -1)).rgb);
    float tr = luma(texture2D(input1, uv + texel * vec2( 1,  1)).rgb);
    float r  = luma(texture2D(input1, uv + texel * vec2( 1,  0)).rgb);
    float br = luma(texture2D(input1, uv + texel * vec2( 1, -1)).rgb);

    float dx = tr + 2.0*r + br - (tl + 2.0*l + bl);
    float dy = bl + 2.0*b + br - (tl + 2.0*t + tr);
    return vec2(dx, dy);
}

// Rotate a 2D vector by angle (radians)
vec2 rotate2d(vec2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec2(v.x*c - v.y*s, v.x*s + v.y*c);
}

// Returns the (possibly modulated) walk direction at a given UV position
vec2 get_tangent(vec2 uv, vec2 texel, vec2 res) {
    vec2 gradient = get_gradient(uv, texel);

    // Clamp before length() — HDR Inf values produce NaN via normalize(), which renders black
    gradient = clamp(gradient, vec2(-1e6), vec2(1e6));
    float mag = length(gradient);

    // Always guard near-zero — normalize(vec2(0)) = NaN when edge_threshold is 0
    if (mag < max(edge_threshold, 1e-7)) return vec2(0.0);

    // Tangent is perpendicular to gradient
    vec2 tangent = normalize(vec2(-gradient.y, gradient.x));

    // Global flow bias (degrees → radians)
    float bias_rad = flow_bias * 0.01745329;
    tangent = rotate2d(tangent, bias_rad);

    // Sine wave modulation: rotate tangent by wave amount
    float phase;
    if (radial_waves) {
        vec2 aspect = vec2(adsk_result_w / adsk_result_h, 1.0);
        phase = distance(uv * aspect, center * aspect);
    } else {
        phase = uv.x;
    }
    float wave = sin(phase * wave_freq * 6.283185) * wave_amp;
    tangent = rotate2d(tangent, wave);

    return tangent;
}

void main() {
    vec2 res    = vec2(adsk_result_w, adsk_result_h);
    vec2 uv     = gl_FragCoord.xy / res;
    vec2 texel  = 1.0 / res;
    vec4 src    = texture2D(input1, uv);

    vec2 step_vec = texel * strength;

    if (!mode) {
        // --- Smear mode ---
        // Walk along tangent, sample at final position
        vec2 pos = uv;
        for (int i = 0; i < iterations; i++) {
            vec2 t = get_tangent(pos, texel, res);
            if (length(t) < 0.0001) break;
            pos += t * step_vec;
        }
        gl_FragColor = texture2D(input1, pos);

    } else {
        // --- Flow mode (LIC) ---
        // Bidirectional walk: accumulate Gaussian-weighted samples along path
        vec3 accum   = vec3(0.0);
        float total_w = 0.0;
        float sigma   = float(iterations) * 0.5 + 0.001;

        // Include the origin sample
        float w0 = 1.0;
        accum    += src.rgb * w0;
        total_w  += w0;

        // Forward walk
        vec2 pos = uv;
        for (int i = 0; i < iterations; i++) {
            vec2 t = get_tangent(pos, texel, res);
            if (length(t) < 0.0001) break;
            pos += t * step_vec;
            float fi = float(i + 1);
            float w  = exp(-(fi * fi) / (2.0 * sigma * sigma));
            accum   += texture2D(input1, pos).rgb * w;
            total_w += w;
        }

        // Backward walk
        pos = uv;
        for (int i = 0; i < iterations; i++) {
            vec2 t = get_tangent(pos, texel, res);
            if (length(t) < 0.0001) break;
            pos -= t * step_vec;
            float fi = float(i + 1);
            float w  = exp(-(fi * fi) / (2.0 * sigma * sigma));
            accum   += texture2D(input1, pos).rgb * w;
            total_w += w;
        }

        gl_FragColor = vec4(accum / total_w, src.a);
    }
}
