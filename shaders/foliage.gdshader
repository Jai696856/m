// Leaves and canopies: soft toon shading with a top-to-bottom tint and a gentle
// sway in the wind. Canopies cast shadows but do not receive them, so overlapping
// leaf balls stay clean.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, shadows_disabled, world_vertex_coords;

uniform vec3 albedo : source_color = vec3(0.3, 0.7, 0.3);
uniform float sway = 0.06;

varying float up;

void vertex() {
	float h = smoothstep(0.6, 4.5, VERTEX.y);
	float t = TIME * 1.1 + VERTEX.x * 0.21 + VERTEX.z * 0.17;
	VERTEX.x += sin(t) * sway * h;
	VERTEX.z += cos(t * 0.83) * sway * 0.6 * h;
	up = NORMAL.y;
}

void fragment() {
	ALBEDO = albedo * mix(0.84, 1.07, smoothstep(-0.35, 0.85, up));
	ROUGHNESS = 0.75;
}
