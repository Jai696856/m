// Ocean around the island. Vertex colour R = how deep (0 shallow, 1 open sea),
// G = foam at the shoreline. Rolling swell and ripples.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform float night = 0.0;
uniform vec3 shallow : source_color = vec3(0.18, 0.72, 0.72);
uniform vec3 deep : source_color = vec3(0.02, 0.17, 0.32);

varying vec2 info;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	info = COLOR.rg;
	float w = sin(wpos.x * 0.07 + TIME * 1.1) * 0.14 + sin(wpos.z * 0.09 + wpos.x * 0.02 + TIME * 0.8) * 0.09;
	VERTEX.y += w * (0.3 + 0.7 * info.r);
}

void fragment() {
	float t = smoothstep(0.0, 0.8, info.r);
	vec3 c = mix(shallow, deep, t);
	vec2 p = wpos.xz;
	float nx = sin(p.x * 0.6 + TIME * 2.0) * 0.5 + sin(p.y * 0.9 + p.x * 0.3 + TIME * 1.4) * 0.5;
	float nz = cos(p.y * 0.7 - TIME * 1.7) * 0.5 + cos(p.x * 0.8 + p.y * 0.2 - TIME * 1.1) * 0.5;
	NORMAL = normalize((VIEW_MATRIX * vec4(nx * 0.09, 1.0, nz * 0.09, 0.0)).xyz);
	float foam = info.g * (0.6 + 0.4 * sin(TIME * 1.3 + wpos.x * 0.2 + wpos.z * 0.15));
	ALBEDO = mix(c * (1.0 - night * 0.6), vec3(0.95), foam * 0.8);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.6;
	ALPHA = max(mix(0.55, 0.97, t), foam);
}
