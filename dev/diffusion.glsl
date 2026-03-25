// Matchbox Diffusion Shader for Autodesk Flame
// Author: GitHub Copilot
// Date: 2025-11-14
// Description: Simple iterative diffusion (blur) shader with user controls

uniform float adsk_result_w, adsk_result_h;
uniform sampler2D input1;
uniform float radius;
uniform int iterations;
uniform float strength;

uniform bool enable_edge_mask;
uniform float edge_threshold;

// Hash function for pseudo-random numbers
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Sobel Edge Detection
float sobel(vec2 uv, vec2 res) {
    vec2 texel = 1.0 / res;
    
    float tl = texture2D(input1, uv + texel * vec2(-1, -1)).r;
    float t  = texture2D(input1, uv + texel * vec2( 0, -1)).r;
    float tr = texture2D(input1, uv + texel * vec2( 1, -1)).r;
    float l  = texture2D(input1, uv + texel * vec2(-1,  0)).r;
    float r  = texture2D(input1, uv + texel * vec2( 1,  0)).r;
    float bl = texture2D(input1, uv + texel * vec2(-1,  1)).r;
    float b  = texture2D(input1, uv + texel * vec2( 0,  1)).r;
    float br = texture2D(input1, uv + texel * vec2( 1,  1)).r;

    float x = tl + 2.0 * l + bl - tr - 2.0 * r - br;
    float y = tl + 2.0 * t + tr - bl - 2.0 * b - br;

    return sqrt(x * x + y * y);
}

void main()
{
    vec2 coords = gl_FragCoord.xy / vec2(adsk_result_w, adsk_result_h);
    vec3 original = texture2D(input1, coords).rgb;
    vec2 res = vec2(adsk_result_w, adsk_result_h);
    
    vec3 sum = vec3(0.0);
    float total_weight = 0.0;

    // Random seed based on pixel position
    vec2 seed = coords;

    for (int i = 0; i < iterations; ++i) {
        // Generate random angle and radius
        float r1 = hash(seed);
        seed += vec2(0.1, 0.1); // Update seed
        float r2 = hash(seed);
        seed += vec2(0.1, 0.1); // Update seed

        float angle = r1 * 6.283185;
        float dist = sqrt(r2) * radius; // sqrt for uniform distribution

        vec2 offset = vec2(cos(angle), sin(angle)) * dist;
        vec2 sample_coords = coords + offset / res;

        sum += texture2D(input1, sample_coords).rgb;
        total_weight += 1.0;
    }

    vec3 blurred = sum / total_weight;
    
    float mix_factor = strength;
    if (enable_edge_mask) {
        float edge = sobel(coords, res);
        // Apply threshold/gain to edge
        edge = smoothstep(0.0, edge_threshold, edge);
        mix_factor *= edge;
    }
    
    // Mix based on strength and edge mask
    vec3 color = mix(original, blurred, clamp(mix_factor, 0.0, 1.0));
    
    gl_FragColor = vec4(color, 1.0);
}
