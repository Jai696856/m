// Roofs: toon shading with thin darker lines for rows of tiles, drawn along the
// slope in the mesh's own space so they follow any roof size.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 albedo : source_color = vec3(0.88, 0.48, 0.17);
uniform float rows = 2.4;        // tile rows per unit of height

varying float vy;

void vertex() {
	vy = VERTEX.y;
}

void fragment() {
	float band = fract(vy * rows);
	float line = smoothstep(0.0, 0.1, band) * (1.0 - 0.5 * smoothstep(0.86, 1.0, band));
	ALBEDO = albedo * mix(0.86, 1.0, line);
	ROUGHNESS = 1.0;
}
