//RGBa
// Streak -- Streak / Flare Filter -- Matchbox Shader for Autodesk Flame
// Version 1.0
//


uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h;

uniform float threshold;   // minimum luminance to generate a streak
uniform float length_px;   // streak length in pixels
uniform int   streaks;     // bilateral directions (1=anamorphic, 2=4pt, 3=6pt...)
uniform float angle;       // rotation of streak pattern in degrees

uniform float intensity;   // overall streak brightness multiplier
uniform float falloff;     // distance attenuation rate (higher = faster fade)
uniform float hue;         // 0 = white/neutral, 1 = anamorphic blue
uniform float chroma;      // chromatic aberration (R shorter, B longer)
uniform int   samples;     // steps per ray (quality)

void main() {
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    vec2 uv  = gl_FragCoord.xy / res;
    vec4 src = texture2D(Input1, uv);

    // Streak colour: mix neutral white toward anamorphic blue
    vec3 streak_rgb = mix(vec3(1.0), vec3(0.5, 0.72, 1.0), hue);

    float base_rad = angle * 0.01745329;   // degrees to radians
    float ca       = chroma * 0.2;         // chromatic offset scale

    vec3  streak_total = vec3(0.0);
    float n            = float(samples);

    for (int d = 0; d < streaks; d++) {
        // Each bilateral direction: one angle and its opposite
        float streak_angle = base_rad + float(d) * 3.14159265 / float(streaks);

        for (int side = 0; side < 2; side++) {
            // side 0 = forward, side 1 = backward along the same axis
            float s_angle = streak_angle + float(side) * 3.14159265;
            vec2 dir = vec2(cos(s_angle), sin(s_angle));

            for (int i = 0; i < samples; i++) {
                // Evenly spaced from one step out to full length
                float t    = float(i + 1) / n;
                float dist = t * length_px;

                // Exponential falloff -- streaks are brightest near the source
                float w = exp(-t * falloff);

                // Chromatic offset: R shorter, G nominal, B longer
                vec2 off_r = dir * dist * (1.0 - ca) / res;
                vec2 off_g = dir * dist / res;
                vec2 off_b = dir * dist * (1.0 + ca) / res;

                float luma_r = dot(texture2D(Input1, uv + off_r).rgb, vec3(0.2126, 0.7152, 0.0722));
                float luma_g = dot(texture2D(Input1, uv + off_g).rgb, vec3(0.2126, 0.7152, 0.0722));
                float luma_b = dot(texture2D(Input1, uv + off_b).rgb, vec3(0.2126, 0.7152, 0.0722));

                float exc_r = max(luma_r - threshold, 0.0);
                float exc_g = max(luma_g - threshold, 0.0);
                float exc_b = max(luma_b - threshold, 0.0);

                streak_total.r += exc_r * w * streak_rgb.r;
                streak_total.g += exc_g * w * streak_rgb.g;
                streak_total.b += exc_b * w * streak_rgb.b;
            }
        }
    }

    // Normalise by sample count so quality changes don't shift brightness.
    // More streak directions naturally add more total light (intentional).
    streak_total /= n;

    gl_FragColor = vec4(src.rgb + streak_total * intensity, src.a);
}
