shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float broad = surface_noise(world_position * .24);
	float grain = surface_noise(world_position * 7.0);
	float seam = 1.0 - smoothstep(.018,.055,abs(sin(world_position.y*.72 + broad*.65)));
	vec3 stone = mix(vec3(.26,.29,.33),vec3(.44,.45,.47),broad);
	float dust = smoothstep(.45,.88,normalize(world_normal).y) * (.25 + broad*.30);
	ALBEDO = mix(stone,vec3(.45,.40,.31),dust) * (.94 + grain*.10 - seam*.065);
	ROUGHNESS = .95;
	SPECULAR = .13;
}
