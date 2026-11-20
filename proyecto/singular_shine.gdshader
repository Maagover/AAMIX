shader_type canvas_item;
render_mode unshaded;
uniform float shine_progress = -0.3;

void fragment() {
	// Preserve the same original-card corner mask as the ordinary card view.
	vec2 extent = vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y);
	float radius = 0.035;
	vec2 q = abs((UV - 0.5) * extent) - extent * 0.5 + radius;
	float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float smoothing = max(fwidth(distance), 0.0001);
	COLOR.a *= 1.0 - smoothstep(-smoothing, smoothing, distance);
	float band = 1.0 - smoothstep(0.0, 0.065, abs(UV.x + UV.y * 0.28 - shine_progress));
	COLOR.rgb = min(vec3(1.0), COLOR.rgb + vec3(1.0, 0.88, 0.48) * band * 0.25);
}
