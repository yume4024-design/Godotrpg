shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float foam = surface_noise(vec3(world_position.xz * 3.0,TIME*.8));
	ALBEDO = mix(vec3(.35,.68,.80),vec3(.75,.90,.94),foam);
	EMISSION = ALBEDO * .12;
	ROUGHNESS = .76;
	SPECULAR = .18;
}
