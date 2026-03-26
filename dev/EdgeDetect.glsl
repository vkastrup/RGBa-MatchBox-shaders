//RGBa

uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h;

uniform float step_size;   // sample offset in pixels
uniform float threshold;   // clip edges below this value
uniform float gain;        // edge brightness multiplier
uniform bool  kernel;      // false = Sobel, true = Scharr
uniform bool  color_edges; // false = luminance, true = per-channel colour edges
uniform bool  output_mode; // false = edge only, true = add edge over source

float luma(vec4 c) {
    return dot(vec3(0.2126, 0.7152, 0.0722), c.rgb);
}

void grad_luma(float sx, float sy, vec2 uv, out float gx, out float gy) {
    float tl = luma(texture2D(Input1, uv + vec2(-sx,  sy)));
    float l  = luma(texture2D(Input1, uv + vec2(-sx, 0.0)));
    float bl = luma(texture2D(Input1, uv + vec2(-sx, -sy)));
    float t  = luma(texture2D(Input1, uv + vec2(0.0,  sy)));
    float b  = luma(texture2D(Input1, uv + vec2(0.0, -sy)));
    float tr = luma(texture2D(Input1, uv + vec2( sx,  sy)));
    float r  = luma(texture2D(Input1, uv + vec2( sx, 0.0)));
    float br = luma(texture2D(Input1, uv + vec2( sx, -sy)));

    if (!kernel) {
        gx = tl + 2.0*l + bl - tr - 2.0*r - br;
        gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
    } else {
        gx = 3.0*tl + 10.0*l + 3.0*bl - 3.0*tr - 10.0*r - 3.0*br;
        gy = -3.0*tl - 10.0*t - 3.0*tr + 3.0*bl + 10.0*b + 3.0*br;
    }
}

void grad_color(float sx, float sy, vec2 uv, out vec3 gx, out vec3 gy) {
    vec3 tl = texture2D(Input1, uv + vec2(-sx,  sy)).rgb;
    vec3 l  = texture2D(Input1, uv + vec2(-sx, 0.0)).rgb;
    vec3 bl = texture2D(Input1, uv + vec2(-sx, -sy)).rgb;
    vec3 t  = texture2D(Input1, uv + vec2(0.0,  sy)).rgb;
    vec3 b  = texture2D(Input1, uv + vec2(0.0, -sy)).rgb;
    vec3 tr = texture2D(Input1, uv + vec2( sx,  sy)).rgb;
    vec3 r  = texture2D(Input1, uv + vec2( sx, 0.0)).rgb;
    vec3 br = texture2D(Input1, uv + vec2( sx, -sy)).rgb;

    if (!kernel) {
        gx = tl + 2.0*l + bl - tr - 2.0*r - br;
        gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
    } else {
        gx = 3.0*tl + 10.0*l + 3.0*bl - 3.0*tr - 10.0*r - 3.0*br;
        gy = -3.0*tl - 10.0*t - 3.0*tr + 3.0*bl + 10.0*b + 3.0*br;
    }
}

void main() {
    vec2 resolution = vec2(adsk_result_w, adsk_result_h);
    vec2 uv  = gl_FragCoord.xy / resolution;
    vec4 src = texture2D(Input1, uv);

    float sx = step_size / resolution.x;
    float sy = step_size / resolution.y;

    vec3 edge;

    if (!color_edges) {
        float gx, gy;
        grad_luma(sx, sy, uv, gx, gy);
        edge = vec3(sqrt(gx*gx + gy*gy));
    } else {
        vec3 gx, gy;
        grad_color(sx, sy, uv, gx, gy);
        edge = sqrt(gx*gx + gy*gy);
    }

    edge = max(edge - vec3(threshold), vec3(0.0)) * gain;

    vec3 result;
    if (!output_mode) {
        result = edge;
    } else {
        result = src.rgb + edge;
    }

    gl_FragColor = vec4(result, src.a);
}
