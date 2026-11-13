// Painted ground: grass with soft tonal blotches, a sandy shore, and contact shade
// next to the track and under props. Reads the level's baked data texture:
//   R = contact shade (0..1), G = distance inland (0.5 = shoreline, 1/32 per unit).
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform sampler2D data : filter_linear, repeat_disable;
uniform vec4 world_rect = vec4(-72.0, -52.0, 0.00694, 0.00962);  // x0, z0, 1/width, 1/depth
uniform vec3 grass : source_color = vec3(0.5, 0.79, 0.34);
uniform vec3 grass_light : source_color = vec3(0.58, 0.84, 0.4);
uniform vec3 grass_dark : source_color = vec3(0.43, 0.72, 0.3);
uniform vec3 sand : source_color = vec3(0.96, 0.87, 0.62);
uniform vec3 sand_wet : source_color = vec3(0.86, 0.78, 0.56);
uniform float shade_strength = 0.26;

uniform vec3 horizon : source_color = vec3(0.75, 0.91, 1.0);
uniform vec2 centre = vec2(0.0, 0.0);

varying vec3 wpos;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (wpos.xz - world_rect.xy) * world_rect.zw;
	vec4 d = texture(data, uv);
	float inland = (d.g - 0.5) * 32.0;

	// Grass: two layers of soft blotches, then a faint grain
	float n = vnoise(wpos.xz * 0.1) * 0.62 + vnoise(wpos.xz * 0.27 + 9.0) * 0.38;
	vec3 g = mix(grass_dark, grass, smoothstep(0.32, 0.46, n));
	g = mix(g, grass_light, smoothstep(0.55, 0.68, n));
	g *= 1.0 - 0.03 * smoothstep(0.5, 0.9, vnoise(wpos.xz * 2.7));
	// A lighter fringe where the grass meets the sand
	g = mix(g, grass_light, 0.5 * smoothstep(2.2, 0.2, inland));
	// Contact shade beside the track and under trees and houses
	g *= 1.0 - shade_strength * smoothstep(0.04, 0.8, d.r);

	// Sand, darker where it is wet
	float wob = (vnoise(wpos.xz * 0.55) - 0.5) * 0.9;
	vec3 s = mix(sand_wet, sand, smoothstep(-4.4, -2.4, inland + wob * 0.6));
	s *= 1.0 - 0.025 * smoothstep(0.55, 0.9, vnoise(wpos.xz * 3.3 + 4.0));
	s *= 1.0 - shade_strength * 0.6 * smoothstep(0.04, 0.8, d.r);

	vec3 c = mix(s, g, smoothstep(-0.35, 0.3, inland + wob));
	// Far away the ground melts into the horizon colour
	ALBEDO = mix(c, horizon, 0.85 * smoothstep(150.0, 430.0, length(wpos.xz - centre)));
	ROUGHNESS = 1.0;
}
