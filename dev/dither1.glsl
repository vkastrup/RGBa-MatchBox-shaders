//RGBa

uniform int lookupSize;
uniform float errorCarry;

uniform sampler2D Input1;
uniform float adsk_result_w, adsk_result_h, adsk_result_frameratio, adsk_time;
uniform float red;
uniform float green;
uniform float blue;

vec2 resolution = vec2(adsk_result_w, adsk_result_h);
float time = adsk_time *.05;

float getGrayscale(vec2 FragCoords){
	vec2 uv = FragCoords / resolution.xy;
	vec3 sourcePixel = texture2D(Input1, uv).rgb;
	return length(sourcePixel*vec3(red, green, blue));
}

void main() {

	int topGapY = int((resolution.y - gl_FragCoord.y) + 20);

	int cornerGapX = int((gl_FragCoord.x < 10.0) ? gl_FragCoord.x : resolution.x - gl_FragCoord.x);
	int cornerGapY = int((gl_FragCoord.y < 10.0) ? gl_FragCoord.y : resolution.y - gl_FragCoord.y);
	int cornerThreshhold = ((cornerGapX == 0) || (topGapY == 0)) ? 5 : 4;

	if (cornerGapX+cornerGapY < cornerThreshhold) {

		gl_FragColor = vec4(0,0,0,1);

	} else if (topGapY < 20) {

			if (topGapY == 19) {

				gl_FragColor = vec4(0,0,0,1);

			} else {

				gl_FragColor = vec4(1,1,1,1);

			}

	} else {

		float xError = 0.0;
		for(int xLook=0; xLook<lookupSize; xLook++){
			float grayscale = getGrayscale(gl_FragCoord.xy + vec2(-lookupSize+xLook,0));
			grayscale += xError;
			float bit = grayscale >= 0.5 ? 1.0 : 0.0;
			xError = (grayscale - bit)*errorCarry;
		}

		float yError = 0.0;
		for(int yLook=0; yLook<lookupSize; yLook++){
			float grayscale = getGrayscale(gl_FragCoord.xy + vec2(0,-lookupSize+yLook));
			grayscale += yError;
			float bit = grayscale >= 0.5 ? 1.0 : 0.0;
			yError = (grayscale - bit)*errorCarry;
		}

		float finalGrayscale = getGrayscale(gl_FragCoord.xy);
		finalGrayscale += xError*0.5 + yError*0.5;
		float finalBit = finalGrayscale >= 0.5 ? 1.0 : 0.0;

		gl_FragColor = vec4(finalBit,finalBit,finalBit,1);

	}

}
