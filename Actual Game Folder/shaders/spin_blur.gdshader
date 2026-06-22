shader_type canvas_item;

// angular blur so spinning blades don't strobe to a standstill; blur_angle = swept arc (rad)

uniform float blur_angle = 0.0;
uniform int samples : hint_range(2, 24) = 12;
uniform float lighten : hint_range(0.0, 1.0) = 0.0;

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

	COLOR.rgb *= 1.0 + lighten;
	if (lighten > 0.0) {
		// keep the player blade as solid as its source so motion blur can't fade it dark
		COLOR.a = max(COLOR.a, texture(TEXTURE, UV).a * modulate.a);
	}
}
