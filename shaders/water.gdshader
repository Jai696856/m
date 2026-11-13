// Stylised sea: a depth gradient from the shore, foam at the waterline, thin foam
// lines rolling in, and drifting highlights. Uses the level's baked data texture
// (G = distance inland, 0.5 = shoreline, 1/32 per unit).
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled, shadows_disabled;

uniform sampler2D data : filter_linear, repeat_disable;
uniform vec4 world_rect = vec4(-72.0, -52.0, 0.00694, 0.00962);
uniform vec3 deep : source_color = vec3(0.12, 0.6, 0.84);
uniform vec3 shallow : source_color = vec3(0.37, 0.82, 0.94);
uniform vec3 foam : source_color = vec3(0.92, 0.99, 1.0);
uniform float shore_edge = 4.6;   // how far out the sand reaches

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
	float dist = -(texture(data, uv).g - 0.5) * 32.0 - shore_edge;   // units out from the sand
	float t = TIME;
	float w1 = vnoise(wpos.xz * 0.3 + vec2(t * 0.11, t * 0.06));
	float w2 = vnoise(wpos.xz * 0.75 - vec2(t * 0.09, -t * 0.05));

	vec3 c = mix(shallow, deep, smoothstep(0.5, 8.5, dist + (w1 - 0.5) * 2.4));
	// Soft lighter patches so open water is not one flat colour
	c = mix(c, shallow, 0.16 * smoothstep(0.55, 0.8, w1 * 0.6 + w2 * 0.4) * smoothstep(3.0, 9.0, dist));

	// Foam hugging the shore, breathing in and out
	float breathe = sin(t * 0.8 + w1 * 4.0) * 0.35;
	float edge = smoothstep(1.3 + breathe, 0.25 + breathe, dist + (w2 - 0.5) * 1.1);
	// Thin foam lines rolling toward the shore
	float roll = sin((dist + t * 0.7) * 1.9 + w1 * 5.0);
	float lines = smoothstep(0.9, 0.985, roll) * smoothstep(7.5, 1.5, dist) * smoothstep(0.35, 0.6, w2);
	// Drifting glints further out
	float glint = smoothstep(0.62, 0.7, vnoise(wpos.xz * 1.5 + vec2(t * 0.3, 0.0)) * vnoise(wpos.xz * 1.1 - vec2(0.0, t * 0.25)) * 1.7);

	c = mix(c, foam, clamp(edge + lines * 0.75, 0.0, 1.0));
	c += glint * 0.1;
	ALBEDO = mix(c, horizon, 0.8 * smoothstep(150.0, 430.0, length(wpos.xz - centre)));
	ROUGHNESS = 1.0;
}
