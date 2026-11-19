// Building facades: windows drawn from world position, lit at random after dark.
shader_type spatial;
render_mode specular_schlick_ggx;

global uniform float night;
instance uniform vec4 wall_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
instance uniform float style = 0.0; // 0 office/apartment, 1 glass tower, 2 house
instance uniform float seed = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = wall_color.rgb;
	float rough = 0.85;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (abs(wnorm.y) < 0.5) {
		float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
		float v = wpos.y;
		float fh = 3.5;
		float ww = 3.0;
		vec2 lo = vec2(0.22, 0.28);
		vec2 hi = vec2(0.78, 0.82);
		if (style > 0.5 && style < 1.5) {
			ww = 1.6; lo = vec2(0.05, 0.08); hi = vec2(0.95, 0.94);
		} else if (style > 1.5) {
			fh = 3.0; ww = 4.2; lo = vec2(0.3, 0.3); hi = vec2(0.7, 0.75);
		}
		vec2 cell = vec2(u / ww, v / fh);
		vec2 f = fract(cell);
		vec2 id = floor(cell) + vec2(seed * 17.0, seed * 31.0);
		float win = step(lo.x, f.x) * step(f.x, hi.x) * step(lo.y, f.y) * step(f.y, hi.y);
		win *= step(1.0, v);
		float h = hash21(id);
		vec3 glass = vec3(0.14, 0.2, 0.28) * (0.7 + 0.6 * hash21(id + 7.0));
		if (style > 0.5 && style < 1.5) {
			glass = mix(glass, wall_color.rgb * 0.55, 0.45);
		}
		float slab = smoothstep(0.0, 0.04, f.y) * smoothstep(0.0, 0.04, 1.0 - f.y);
		if (style < 0.5) {
			base *= mix(0.84, 1.0, slab);
		}
		base = mix(base, glass, win);
		rough = mix(rough, 0.1, win);
		metal = mix(0.0, 0.55, win);
		float lit = step(0.52, h) * night;
		vec3 warm = mix(vec3(1.0, 0.76, 0.42), vec3(0.72, 0.86, 1.0), hash21(id + 3.3));
		emit = warm * win * lit * 1.8;
		base *= mix(0.72, 1.0, smoothstep(0.0, 3.0, v));
	} else {
		base *= 0.55;
		rough = 0.95;
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
