// Gradient sky with a sun disc, drifting clouds and stars at night.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.2, 0.42, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.8, 0.9);
uniform vec3 ground_color : source_color = vec3(0.18, 0.18, 0.2);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float star_amount = 0.0;
uniform float cloud_cover = 0.5;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash3(vec3(i, 1.0));
	float b = hash3(vec3(i + vec2(1.0, 0.0), 1.0));
	float c = hash3(vec3(i + vec2(0.0, 1.0), 1.0));
	float d = hash3(vec3(i + vec2(1.0, 1.0), 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h > 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.45));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	if (LIGHT0_ENABLED) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		vec3 sc = LIGHT0_COLOR * LIGHT0_ENERGY;
		col += sc * pow(sd, 900.0) * 10.0;
		col += sc * pow(sd, 10.0) * 0.3 * clamp(1.0 - h * 2.0, 0.0, 1.0);
	}
	if (!AT_CUBEMAP_PASS && h > 0.0) {
		vec3 sp = floor(d * 420.0);
		float s = step(0.9982, hash3(sp)) * star_amount * clamp(h * 3.0, 0.0, 1.0);
		col += vec3(s) * 1.5;
		vec2 uv = d.xz / (h + 0.12) * 1.4 + vec2(TIME * 0.004, TIME * 0.0025);
		float c = smoothstep(cloud_cover, cloud_cover + 0.32, fbm(uv));
		col = mix(col, cloud_color, c * clamp(h * 5.0, 0.0, 1.0) * 0.85);
	}
	COLOR = col;
}
