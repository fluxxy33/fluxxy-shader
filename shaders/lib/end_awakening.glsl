// =============================================================================================
// End Awakening: a distinct look for every dimension.
// Runs in final.fsh, after tonemapping, so every effect works in display space.
//   Overworld: natural, slightly warm and vivid, crisp (sharpening, light fog).
//   Nether:    scorched reds, heat shimmer, embers drifting up.
//   End:       violet/teal grading, aurora curtains, nebula, twinkling stars, a breathing void,
//              and a black hole whose gravity bends the sky around it.
// =============================================================================================

#define DIMENSION_LOOK // Per-dimension colour grading and effects (End Awakening).
#define DIMENSION_LOOK_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define END_AURORA // Aurora curtains across the End sky.
#define END_AURORA_BRIGHTNESS 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define END_NEBULA // Violet and teal nebula clouds behind the End stars.
#define END_TWINKLING_STARS // Bright twinkling stars in the End sky.
#define END_VOID_PULSE // The End slowly breathes: a faint violet pulse in the shadows.
#define END_CHROMATIC_ABERRATION // Colour fringing at the screen edges in the End.
#define NETHER_HEAT_HAZE // Heat shimmer distorts the view in the Nether.
#define NETHER_HEAT_HAZE_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define NETHER_EMBERS // Glowing embers drift upwards in the Nether.
#define DIMENSION_VIGNETTE // Tinted vignette: violet in the End, ember red in the Nether.
#define DAWN_AURORA // Pastel auroras over the night sky of the Dawn.
#define DAWN_MOTES // Motes of golden light drifting in the air of the Dawn.
#define SHARPENING // Contrast adaptive sharpening for a crisper image.
#define SHARPENING_STRENGTH 0.5 // [0.0 0.25 0.5 0.75 1.0]

// --- Noise -------------------------------------------------------------------------------------

float ea_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ea_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = ea_hash12(i);
	float b = ea_hash12(i + vec2(1.0, 0.0));
	float c = ea_hash12(i + vec2(0.0, 1.0));
	float d = ea_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float ea_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * ea_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

// --- Colour helpers -----------------------------------------------------------------------------

float ea_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 ea_saturation(vec3 c, float amount) {
	return mix(vec3(ea_luma(c)), c, amount);
}

/** Multiplies shadows and highlights by different tints, blended by luminance. */
vec3 ea_splitTone(vec3 c, vec3 shadowTint, vec3 highlightTint, float amount) {
	float l = ea_luma(c);
	vec3 tint = mix(shadowTint, highlightTint, smoothstep(0.05, 0.75, l));
	return mix(c, c * tint, amount);
}

vec3 ea_vignette(vec3 c, vec2 uv, vec3 edgeColor, float amount) {
	vec2 centered = (uv - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.25, 0.75, length(centered));
	return mix(c, c * edgeColor, v * amount);
}

// --- End sky ------------------------------------------------------------------------------------

/** Three curtains of aurora, projected on a high plane so they arch over the player. */
vec3 ea_aurora(vec3 dir, float t, vec3 colorA, vec3 colorB) {
	if (dir.y <= 0.0) return vec3(0.0);

	vec3 col = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float layer = float(i);
		vec2 p = dir.xz / (dir.y + 0.12) * (0.55 + 0.12 * layer);

		float wave = ea_fbm(vec2(p.x * 0.7 + t * 0.02, layer * 3.1));
		float band = p.y * 1.1 + sin(p.x * 1.2 + t * 0.07 + layer * 2.0) * 0.7 + wave * 1.6 - 0.6 + layer * 0.7;
		float curtain = exp(-band * band * 5.0);

		// Vertical rays running through each curtain.
		float rays = ea_noise(vec2(p.x * 14.0 + t * 0.2, layer * 7.0));
		curtain *= 0.35 + 0.9 * rays * rays;

		vec3 c = mix(colorA, colorB, clamp(layer * 0.45 + 0.25 * sin(t * 0.05 + p.x * 0.8), 0.0, 1.0));
		col += c * curtain;
	}
	return col * smoothstep(0.0, 0.3, dir.y) * 0.28;
}

vec3 ea_endAurora(vec3 dir, float t) {
	return ea_aurora(dir, t, vec3(0.12, 1.0, 0.72), vec3(0.8, 0.28, 1.0)) * END_AURORA_BRIGHTNESS;
}

vec3 ea_endNebula(vec3 dir, float t) {
	vec2 p = dir.xz / (abs(dir.y) + 0.35) * 1.4 + vec2(t * 0.002, 0.0);
	float shape = ea_fbm(p * 1.2);
	float hue = ea_fbm(p * 2.6 + 5.0);
	vec3 c = mix(vec3(0.38, 0.06, 0.6), vec3(0.04, 0.42, 0.55), hue);
	return c * pow(max(shape - 0.38, 0.0), 1.4) * 1.5;
}

float ea_endStars(vec3 dir, float t) {
	vec2 p = vec2(atan(dir.z, dir.x) * 90.0, dir.y * 180.0);
	vec2 id = floor(p);
	float h = ea_hash12(id);
	if (h < 0.982) return 0.0;
	float d = length(fract(p) - 0.5);
	float twinkle = 0.55 + 0.45 * sin(t * (1.5 + h * 3.0) + h * 100.0);
	return smoothstep(0.3, 0.0, d) * twinkle;
}

vec3 ea_endSky(vec3 dir, float t) {
	vec3 sky = vec3(0.0);
	#ifdef END_NEBULA
		sky += ea_endNebula(dir, t);
	#endif
	#ifdef END_AURORA
		sky += ea_endAurora(dir, t);
	#endif
	#ifdef END_TWINKLING_STARS
		sky += vec3(0.85, 0.9, 1.0) * ea_endStars(dir, t);
	#endif
	return sky;
}

// --- Sharpening (contrast adaptive) -------------------------------------------------------------

/** Sharpens less where local contrast is already high, so edges never ring. */
vec3 ea_sharpen(sampler2D tex, vec2 uv, vec2 texel, vec3 center) {
	vec3 north = texture2D(tex, uv + vec2(0.0, texel.y)).rgb;
	vec3 south = texture2D(tex, uv - vec2(0.0, texel.y)).rgb;
	vec3 east = texture2D(tex, uv + vec2(texel.x, 0.0)).rgb;
	vec3 west = texture2D(tex, uv - vec2(texel.x, 0.0)).rgb;
	vec3 lo = min(center, min(min(north, south), min(east, west)));
	vec3 hi = max(center, max(max(north, south), max(east, west)));
	vec3 amount = sqrt(clamp(min(lo, 1.0 - hi) / max(hi, vec3(1.0e-4)), 0.0, 1.0));
	vec3 lobe = -amount * mix(0.08, 0.2, SHARPENING_STRENGTH);
	return clamp((center + (north + south + east + west) * lobe) / (1.0 + 4.0 * lobe), 0.0, 1.0);
}

// --- Nether -------------------------------------------------------------------------------------

/** Horizontal shimmer, stronger near the bottom of the screen where the lava glows. */
vec2 ea_heatHaze(vec2 uv, float t) {
	float strength = 0.0022 * NETHER_HEAT_HAZE_STRENGTH * (0.5 + 0.5 * (1.0 - uv.y));
	float n = ea_noise(uv * vec2(18.0, 42.0) + vec2(0.0, -t * 1.6));
	float wobble = sin(uv.y * 90.0 + t * 3.5 + n * 6.2831);
	return uv + vec2(wobble * strength, (n - 0.5) * strength * 0.5);
}

vec3 ea_embers(vec2 uv, float t, float aspect) {
	vec3 col = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float layer = float(i);
		float scale = 10.0 + layer * 7.0;
		vec2 p = uv * vec2(aspect, 1.0) * scale;
		p.y -= t * (0.5 + 0.35 * layer);
		p.x += sin(t * 0.4 + layer * 2.0 + p.y * 0.3) * 0.4;

		vec2 id = floor(p);
		float h = ea_hash12(id + layer * 13.0);
		if (h > 0.92) {
			vec2 pos = vec2(ea_hash12(id + 3.1), ea_hash12(id + 7.7)) * 0.8 + 0.1;
			float d = length(fract(p) - pos);
			float flicker = 0.55 + 0.45 * sin(t * 7.0 + h * 50.0);
			col += vec3(1.0, 0.42, 0.08) * smoothstep(0.09, 0.0, d) * flicker * (1.0 - layer * 0.25);
		}
	}
	return col;
}

// --- The Dawn -----------------------------------------------------------------------------------

/**
 * The sky of the Dawn. By day the Overworld sky is recoloured into pastel bands (peach on the
 * horizon, lilac above, a soft teal at the zenith) keeping its brightness, so the sun and the clouds
 * still read; at night pink and gold auroras and faint stars come out.
 */
vec3 ea_dawnSky(vec3 sky, vec3 dir, float t) {
	float lum = ea_luma(sky);
	float h = clamp(dir.y, -0.2, 1.0);
	vec3 tint = mix(vec3(1.0, 0.66, 0.7), vec3(0.82, 0.66, 1.0), smoothstep(-0.02, 0.22, h));
	tint = mix(tint, vec3(0.55, 0.86, 0.95), smoothstep(0.25, 0.85, h));
	sky = mix(sky, tint * lum * 1.35, 0.6);

	float night = smoothstep(0.16, 0.03, lum);
	#ifdef DAWN_AURORA
		sky += ea_aurora(dir, t, vec3(1.0, 0.45, 0.75), vec3(1.0, 0.82, 0.35)) * 1.2 * night;
	#endif
	sky += vec3(1.0, 0.92, 0.96) * ea_endStars(dir, t) * night * 0.8;
	return sky;
}

/** Slow motes of light drifting up through the air, golden and pink. */
vec3 ea_dawnMotes(vec2 uv, float t, float aspect) {
	vec3 col = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float layer = float(i);
		float scale = 7.0 + layer * 5.0;
		vec2 p = uv * vec2(aspect, 1.0) * scale;
		p.y -= t * (0.06 + 0.04 * layer);
		p.x += sin(t * 0.25 + layer * 2.0 + p.y * 0.5) * 0.3;
		vec2 id = floor(p);
		float h = ea_hash12(id + layer * 17.0);
		if (h > 0.94) {
			vec2 pos = vec2(ea_hash12(id + 4.3), ea_hash12(id + 9.1)) * 0.7 + 0.15;
			float d = length(fract(p) - pos);
			float breathe = 0.5 + 0.5 * sin(t * 1.3 + h * 40.0);
			vec3 tint = mix(vec3(1.0, 0.85, 0.45), vec3(1.0, 0.6, 0.85), ea_hash12(id + 1.7));
			col += tint * smoothstep(0.12, 0.0, d) * breathe * (0.5 - layer * 0.12);
		}
	}
	return col;
}

// --- Grading ------------------------------------------------------------------------------------

void ea_gradeOverworld(inout vec3 c, vec2 uv, float k) {
	c = ea_saturation(c, 1.0 + 0.12 * k);
	c = ea_splitTone(c, vec3(0.94, 0.99, 1.08), vec3(1.07, 1.01, 0.92), 0.6 * k);
	#ifdef DIMENSION_VIGNETTE
		c = ea_vignette(c, uv, vec3(0.75, 0.72, 0.7), 0.25 * k);
	#endif
}

void ea_gradeNether(inout vec3 c, vec2 uv, float t, float aspect, float k) {
	c = ea_saturation(c, 1.0 + 0.3 * k);
	c = ea_splitTone(c, vec3(1.35, 0.55, 0.42), vec3(1.2, 0.95, 0.62), 0.75 * k);
	#ifdef NETHER_EMBERS
		c += ea_embers(uv, t, aspect) * k;
	#endif
	#ifdef DIMENSION_VIGNETTE
		c = ea_vignette(c, uv, vec3(0.35, 0.05, 0.02), 0.45 * k);
	#endif
}

void ea_gradeEnd(inout vec3 c, vec2 uv, float t, float k) {
	c = ea_saturation(c, 1.0 + 0.35 * k);
	c = ea_splitTone(c, vec3(0.78, 0.48, 1.3), vec3(0.82, 1.12, 1.12), 0.8 * k);

	float darkness = pow(1.0 - clamp(ea_luma(c), 0.0, 1.0), 4.0);
	c += vec3(0.045, 0.0, 0.08) * darkness * k;
	#ifdef END_VOID_PULSE
		c += vec3(0.05, 0.0, 0.09) * darkness * (0.5 + 0.5 * sin(t * 0.6)) * k;
	#endif
	#ifdef DIMENSION_VIGNETTE
		c = ea_vignette(c, uv, vec3(0.3, 0.1, 0.45), 0.65 * k);
	#endif
}

/** The Dawn: pastel light, a rosy haze in the distance, never truly dark, a soft glow on bright things. */
void ea_gradeDawn(inout vec3 c, vec2 uv, float t, float aspect, float k, float distance) {
	float haze = (1.0 - exp(-distance / 260.0)) * 0.22 * k;
	c = mix(c, vec3(1.0, 0.8, 0.86) * max(ea_luma(c), 0.35), haze);
	c = ea_saturation(c, 1.0 + 0.15 * k);
	c = ea_splitTone(c, vec3(0.88, 1.0, 1.12), vec3(1.1, 0.98, 0.9), 0.6 * k);
	c += max(c - 0.65, 0.0) * vec3(1.0, 0.75, 0.6) * 0.35 * k;
	c += vec3(0.02, 0.012, 0.03) * pow(1.0 - clamp(ea_luma(c), 0.0, 1.0), 3.0) * k;
	#ifdef DAWN_MOTES
		c += ea_dawnMotes(uv, t, aspect) * k;
	#endif
	#ifdef DIMENSION_VIGNETTE
		c = ea_vignette(c, uv, vec3(0.88, 0.66, 0.74), 0.3 * k);
	#endif
}
