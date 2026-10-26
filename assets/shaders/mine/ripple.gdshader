shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float fringe=sin(clamp(UV.y,0.0,1.0)*3.14159265);
	float bubbles=surface_noise(vec3(world_position.xz*2.0,TIME*.6));
	ALBEDO=mix(vec3(.32,.64,.70),vec3(.72,.87,.89),bubbles);
	ALPHA=fringe*fringe*(.30+bubbles*.28);
	EMISSION=ALBEDO*.025;
	ROUGHNESS=.62;
}
