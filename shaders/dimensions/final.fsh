#include "/lib/settings.glsl"

uniform sampler2D colortex7;
uniform sampler2D colortex14;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;

varying vec2 texcoord;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;

uniform int hideGUI;

#include "/lib/color_transforms.glsl"
#include "/lib/color_dither.glsl"
#include "/lib/res_params.glsl"


float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

#include "/lib/gameplay_effects.glsl"

void doCameraGridLines(inout vec3 color, vec2 UV){

  float lineThicknessY = 0.001;
  float lineThicknessX = lineThicknessY/aspectRatio;
  
  float horizontalLines = abs(UV.x-0.33);
  horizontalLines = min(abs(UV.x-0.66), horizontalLines);

  float verticalLines = abs(UV.y-0.33);
  verticalLines = min(abs(UV.y-0.66), verticalLines);

  float gridLines = horizontalLines < lineThicknessX || verticalLines < lineThicknessY ? 1.0 : 0.0;

  if(hideGUI > 0.0) gridLines = 0.0;
  color = mix(color, vec3(1.0),  gridLines);
}

uniform vec3 previousCameraPosition;
// uniform vec3 cameraPosition;
uniform mat4 gbufferPreviousModelView;
// uniform mat4 gbufferModelViewInverse;
// uniform mat4 gbufferModelView;

#include "/lib/util.glsl"
#include "/lib/projections.glsl"
#include "/lib/end_awakening.glsl"

vec3 doMotionBlur(vec2 texcoord, float depth, float noise){
  
  float samples = 4.0;
  vec3 color = vec3(0.0);

  float blurMult = 1.0;
  if(depth < 0.56) blurMult = 0.0;

	vec3 viewPos = toScreenSpace(vec3(texcoord, depth));
	viewPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);

	vec3 previousPosition = mat3(gbufferPreviousModelView) * viewPos + gbufferPreviousModelView[3].xyz;
  previousPosition = toClipSpace3(previousPosition);

	vec2 velocity = texcoord - previousPosition.xy;
  
  // thank you Capt Tatsu for letting me use these
  velocity = (velocity / (1.0 + length(velocity))) * 0.05 * blurMult * MOTION_BLUR_STRENGTH;
  texcoord = texcoord - velocity*(samples*0.5 + noise);
  vec2 screenEdges = 2.0/vec2(viewWidth, viewHeight);

	for (int i = 0; i < int(samples); i++) {

    texcoord += velocity;
    color += texture2D(colortex7, clamp(texcoord, screenEdges, 1.0-screenEdges)).rgb;

  }
  // return vec3(texcoord,0.0);
  return color / samples;
}

uniform sampler2D shadowcolor1;

void main() {
  
  float depth = texture2D(depthtex0,texcoord*RENDER_SCALE).r;
  float noise = interleaved_gradientNoise();

  // End Awakening: the Nether shimmers, so every read of the frame goes through the haze.
  vec2 sampleUV = texcoord;
  // Options are tested with their own #ifdef so Iris lists them in the menu.
  #ifdef NETHER_HEAT_HAZE
    #if defined DIMENSION_LOOK && defined NETHER_SHADER
      sampleUV = ea_heatHaze(texcoord, frameTimeCounter);
    #endif
  #endif

  #ifdef MOTION_BLUR
    vec3 COLOR = doMotionBlur(sampleUV, depth, noise);
  #else
    vec3 COLOR = texture2D(colortex7,sampleUV).rgb;
  #endif

  #ifdef END_CHROMATIC_ABERRATION
    #if defined DIMENSION_LOOK && defined END_SHADER
      vec2 fromCenter = texcoord - 0.5;
      vec2 fringe = fromCenter * dot(fromCenter, fromCenter) * 0.018 * DIMENSION_LOOK_STRENGTH;
      COLOR.r = texture2D(colortex7, texcoord + fringe).r;
      COLOR.b = texture2D(colortex7, texcoord - fringe).b;
    #endif
  #endif

  #ifdef SHARPENING
    COLOR = ea_sharpen(colortex7, sampleUV, texelSize, COLOR);
  #endif

  #ifdef DIMENSION_LOOK
    #if defined END_SHADER
      if (depth >= 1.0) {
        vec3 skyDir = normalize(mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord, 0.5)));
        vec3 sky = COLOR + ea_endSky(skyDir, frameTimeCounter);
        COLOR = sky;
      }
      ea_gradeEnd(COLOR, texcoord, frameTimeCounter, DIMENSION_LOOK_STRENGTH);
    #elif defined NETHER_SHADER
      ea_gradeNether(COLOR, texcoord, frameTimeCounter, aspectRatio, DIMENSION_LOOK_STRENGTH);
    #elif defined DAWN_SHADER
      float viewDistance = 0.0;
      if (depth >= 1.0) {
        vec3 skyDir = normalize(mat3(gbufferModelViewInverse) * toScreenSpace(vec3(texcoord, 0.5)));
        COLOR = ea_dawnSky(COLOR, skyDir, frameTimeCounter);
      } else {
        viewDistance = length(toScreenSpace(vec3(texcoord, depth)));
      }
      ea_gradeDawn(COLOR, texcoord, frameTimeCounter, aspectRatio, DIMENSION_LOOK_STRENGTH, viewDistance);
    #else
      ea_gradeOverworld(COLOR, texcoord, DIMENSION_LOOK_STRENGTH);
    #endif
  #endif

  #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT || defined WATER_ON_CAMERA_EFFECT  
    // for making the fun, more fun
    applyGameplayEffects(COLOR, texcoord, noise);
  #endif
  
  #ifdef CAMERA_GRIDLINES
    doCameraGridLines(COLOR, texcoord);
  #endif

  #if DEBUG_VIEW == debug_SHADOWMAP

  vec2 shadowUV = texcoord * vec2(2.0, 1.0);

  if(shadowUV.x < 1.0 && shadowUV.y < 1.0 && hideGUI == 1)COLOR = texture2D(shadowcolor1,shadowUV).rgb;
  #endif


  gl_FragColor.rgb = COLOR;
}
