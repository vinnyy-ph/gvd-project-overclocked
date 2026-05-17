shader_type canvas_item;

uniform vec2 hole_center;
uniform vec2 hole_size;
uniform float hole_softness = 4.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel_uv = uv * screen_size;
	
	// Rectangular distance field
	vec2 d = abs(pixel_uv - hole_center) - hole_size * 0.5;
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
	
	float alpha = smoothstep(0.0, hole_softness, dist);
	COLOR.a *= alpha;
}
