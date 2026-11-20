shader_type canvas_item;
render_mode unshaded;

// Crop the original card at its character, then mask the result to a circle.
// The source files stay intact; titles and game text are outside this region.
uniform vec4 crop_rect = vec4(0.25, 0.16, 0.5, 0.3676);
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	float radius = length(UV - vec2(0.5));
	float feather = max(fwidth(radius), 0.0015);
	float mask = 1.0 - smoothstep(0.5 - feather, 0.5, radius);
	vec4 portrait = texture(TEXTURE, crop_rect.xy + UV * crop_rect.zw);
	COLOR = vec4(portrait.rgb, portrait.a * mask) * item_tint;
}
