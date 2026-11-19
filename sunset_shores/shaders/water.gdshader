// Ocean on the west side of the island: rolling swell, ripples and shore foam.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

global uniform float night;
uniform vec3 shallow : source_color = vec3(0.18, 0.72, 0.72);
uniform vec3 deep : source_color = vec3(0.02, 0.17, 0.32);
uniform float shore_x = -420.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(wpos.x * 0.07 + TIME * 1.1) * 0.14 + sin(wpos.z * 0.09 + wpos.x * 0.02 + TIME * 0.8) * 0.09;
	VERTEX.y += w;
}

void fragment() {
	float dist = shore_x - wpos.x;
	float t = smoothstep(0.0, 110.0, dist);
	vec3 c = mix(shallow, deep, t);
	vec2 p = wpos.xz;
	float nx = sin(p.x * 0.6 + TIME * 2.0) * 0.5 + sin(p.y * 0.9 + p.x * 0.3 + TIME * 1.4) * 0.5;
	float nz = cos(p.y * 0.7 - TIME * 1.7) * 0.5 + cos(p.x * 0.8 + p.y * 0.2 - TIME * 1.1) * 0.5;
	NORMAL = normalize((VIEW_MATRIX * vec4(nx * 0.09, 1.0, nz * 0.09, 0.0)).xyz);
	float foam = smoothstep(5.0, 0.0, dist + sin(wpos.z * 0.15 + TIME * 1.3) * 1.5);
	ALBEDO = mix(c * (1.0 - night * 0.6), vec3(0.95), foam * 0.8);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.6;
	ALPHA = max(mix(0.55, 0.97, t), foam);
}
