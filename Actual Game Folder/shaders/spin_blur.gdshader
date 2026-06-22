shader_type canvas_item;

// angular blur so spinning blades don't strobe to a standstill; blur_angle = swept arc (rad)

uniform float blur_angle = 0.0;
uniform int samples : hint_range(2, 24) = 12;
uniform vec4 glow_color : source_color = vec4(0.0);
uniform float glow_strength = 0.0;
uniform float glow_width = 2.0;

float tex_a(vec2 uv, sampler2D txture) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(txture, uv).a;
}

void fragment() {
	vec4 modulate = COLOR; // node modulate (hit flash)

	if (blur_angle <= 0.0001 || samples < 2) {
		COLOR = texture(TEXTURE, UV) * modulate;
	} else {
		vec2 px = 1.0 / TEXTURE_PIXEL_SIZE;
		float aspect = px.x / px.y;
		vec2 center = vec2(0.5);

		vec2 rel = UV - center;
		rel.x *= aspect; // square space so rotation isn't skewed

		// premultiplied: no dark fringes
		vec3 rgb = vec3(0.0);
		float a = 0.0;
		float start = -blur_angle * 0.5;
		float step = blur_angle / float(samples - 1);
		for (int i = 0; i < samples; i++) {
			float ang = start + step * float(i);
			float s = sin(ang);
			float c = cos(ang);
			vec2 r = vec2(rel.x * c - rel.y * s, rel.x * s + rel.y * c);
			r.x /= aspect;
			vec2 suv = center + r;
			if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
				continue;
			}
			vec4 tap = texture(TEXTURE, suv);
			rgb += pow(tap.rgb, vec3(2.2)) * tap.a; // average in linear, not gamma
			a += tap.a;
		}
		a /= float(samples);
		vec3 avg = a > 0.0 ? rgb / (a * float(samples)) : vec3(0.0);
		avg = pow(avg, vec3(1.0 / 2.2));
		COLOR = vec4(avg, a) * modulate;
	}

	if (glow_strength > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * glow_width;
		vec2 d = px * 0.7071;
		float ring = max(max(max(tex_a(UV + vec2(px.x, 0.0), TEXTURE), tex_a(UV - vec2(px.x, 0.0), TEXTURE)),
			max(tex_a(UV + vec2(0.0, px.y), TEXTURE), tex_a(UV - vec2(0.0, px.y), TEXTURE))),
			max(max(tex_a(UV + d, TEXTURE), tex_a(UV - d, TEXTURE)),
			max(tex_a(UV + vec2(d.x, -d.y), TEXTURE), tex_a(UV - vec2(d.x, -d.y), TEXTURE))));
		float edge = clamp(ring - COLOR.a, 0.0, 1.0) * glow_strength;
		COLOR.rgb = mix(COLOR.rgb, glow_color.rgb, edge);
		COLOR.a = max(COLOR.a, edge);
	}
}
