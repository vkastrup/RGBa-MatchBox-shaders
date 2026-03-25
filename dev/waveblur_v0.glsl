

uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h;
uniform float direction;
uniform float waverad;
uniform float size;


vec2 resolution = vec2(adsk_result_w, adsk_result_h);

//hardcoded for now
float quality = 100.0;

void main()
{
    float Pi = 6.28318530718 * waverad; // Pi*2


    vec2 Radius = size/resolution.xy;

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy/resolution.xy;
    // Pixel colour
    vec4 Color = texture2D(Input1, uv);

    // Blur calculations
    for( float d=0.0; d<Pi; d+=Pi/direction)
    {
		for(float i=1.0/quality; i<=1.0; i+=1.0/quality)
        {
			Color += texture2D( Input1, uv+vec2(cos(d*0.5),sin(d*2))*Radius*i);
        }
    }

    Color /= quality * direction;
    gl_FragColor =  Color;
}
