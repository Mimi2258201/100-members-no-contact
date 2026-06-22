shader_type canvas_item;

// radius is normalized: 0.0 fully covered, 1.1 fully open (clears the corners)
uniform float radius : hint_range(0.0, 1.2) = 1.1;
uniform float softness : hint_range(0.0, 0.3) = 0.03;
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 p = UV - vec2(0.5);
	p.x *= aspect; // keep the iris circular regardless of screen ratio
	float corner = length(vec2(0.5 * aspect, 0.5));
	float dist = length(p) / corner;
	float a = smoothstep(radius - softness, radius + softness, dist);
	COLOR = vec4(cover_color.rgb, cover_color.a * a);
}
