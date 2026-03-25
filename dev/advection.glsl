// Matchbox Advection Shader for Autodesk Flame
// Author: GitHub Copilot
// Date: 2025-12-08
// Description: Advects pixels along high-contrast edges.

uniform float adsk_result_w, adsk_result_h;
uniform sampler2D input1;
uniform float strength;
uniform int iterations;
uniform float edge_threshold;

uniform float wave_amp;
uniform float wave_freq;
uniform bool radial_waves;
uniform vec2 center;

// Sobel Gradient Calculation
vec2 get_gradient(vec2 uv, vec2 res) {
    vec2 texel = 1.0 / res;
    
    float tl = texture2D(input1, uv + texel * vec2(-1, -1)).r;
    float t  = texture2D(input1, uv + texel * vec2( 0, -1)).r;
    float tr = texture2D(input1, uv + texel * vec2( 1, -1)).r;
    float l  = texture2D(input1, uv + texel * vec2(-1,  0)).r;
    float r  = texture2D(input1, uv + texel * vec2( 1,  0)).r;
    float bl = texture2D(input1, uv + texel * vec2(-1,  1)).r;
    float b  = texture2D(input1, uv + texel * vec2( 0,  1)).r;
    float br = texture2D(input1, uv + texel * vec2( 1,  1)).r;

    float dx = tr + 2.0 * r + br - (tl + 2.0 * l + bl);
    float dy = bl + 2.0 * b + br - (tl + 2.0 * t + tr);

    return vec2(dx, dy);
}

void main()
{
    vec2 coords = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    vec2 texel = 1.0 / res;
    
    vec2 current_coords = coords;

    for (int i = 0; i < iterations; ++i) {
        vec2 gradient = get_gradient(current_coords, res);
        float mag = length(gradient);
        
        // Only advect if edge is strong enough
        if (mag > edge_threshold) {
            // Tangent is perpendicular to gradient (-dy, dx)
            vec2 tangent = vec2(-gradient.y, gradient.x);
            
            // Normalize tangent
            if (length(tangent) > 0.0) {
                tangent = normalize(tangent);
            }
            
            // Calculate sine wave modulation
            float phase;
            if (radial_waves) {
                // Radial distance from center
                // Adjust aspect ratio for circular waves
                vec2 aspect = vec2(adsk_result_w / adsk_result_h, 1.0);
                phase = distance(current_coords * aspect, center * aspect);
            } else {
                // Linear waves along X (or could be diagonal)
                phase = current_coords.x;
            }
            
            float wave = sin(phase * wave_freq * 6.283185) * wave_amp;
            
            // Rotate tangent by wave amount (approximate rotation by adding to angle or vector)
            // Simple approach: rotate vector
            float s = sin(wave);
            float c = cos(wave);
            vec2 rotated_tangent = vec2(
                tangent.x * c - tangent.y * s,
                tangent.x * s + tangent.y * c
            );
            
            // Move along rotated tangent
            current_coords += rotated_tangent * strength * texel;
        }
    }
    
    gl_FragColor = texture2D(input1, current_coords);
}
