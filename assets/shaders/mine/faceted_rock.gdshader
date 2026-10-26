shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float broad = surface_noise(world_position * .24);
	float grain = surface_noise(world_position * 7.0);
	float seam = 1.0 - smoothstep(.018,.055,abs(sin(world_position.y*.72 + broad*.65)));
	ALBEDO = mix(vec3(.26,.29,.34),vec3(.43,.45,.48),broad) * (.96 + grain*.07 - seam*.045);
	ROUGHNESS = .95;
	SPECULAR = .13;
}
