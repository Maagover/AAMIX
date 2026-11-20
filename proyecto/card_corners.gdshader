shader_type canvas_item;
render_mode unshaded;

// Radius is 3.5% of the short edge; only the outermost corners are clipped.
void fragment() {
	vec2 extent = vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y);
	float radius = 0.035;
	vec2 q = abs((UV - 0.5) * extent) - extent * 0.5 + radius;
	float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float smoothing = max(fwidth(distance), 0.0001);
	COLOR.a *= 1.0 - smoothstep(-smoothing, smoothing, distance);
}
