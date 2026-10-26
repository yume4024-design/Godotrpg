shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
uniform bool rock_wake = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float grain = surface_noise(vec3(world_position.xz * 3.5, TIME * .8));
	float coverage;
	if (rock_wake) {
		coverage = sin(UV.x * 3.14159) * (.75 + grain * .25);
		if (coverage < .25 || grain < .18) { discard; }
	} else {
		float radius = length((UV - .5) * 2.0);
		float pulse = .5 + .5 * sin(radius * 22.0 - TIME * 3.0);
		coverage = (1.0 - smoothstep(.3,1.0,radius)) * .75 + pulse * .3 + grain * .18;
		if (coverage < .48) { discard; }
	}
	ALBEDO = mix(vec3(.40,.74,.79),vec3(.82,.94,.93),clamp(coverage + grain*.15,0.0,1.0));
	EMISSION = ALBEDO * .08;
	ROUGHNESS = .72;
	SPECULAR = .22;
}
