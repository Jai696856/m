// The spirit portal: a slow glowing vortex.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;

uniform vec3 inner : source_color = vec3(0.86, 0.72, 1.0);
uniform vec3 outer : source_color = vec3(0.36, 0.16, 0.62);
uniform float strength = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 7.0 - TIME * 1.6);
	float swirl2 = sin(a * 5.0 - r * 11.0 + TIME * 1.1);
	vec3 c = mix(outer, inner, smoothstep(-0.35, 0.8, swirl) * (1.0 - r * 0.55));
	c = mix(c, inner, 0.25 * smoothstep(0.5, 1.0, swirl2) * (1.0 - r));
	c += inner * 0.55 * smoothstep(0.45, 0.0, r);
	ALBEDO = c * strength;
	ALPHA = smoothstep(1.0, 0.9, r) * 0.95;
}
