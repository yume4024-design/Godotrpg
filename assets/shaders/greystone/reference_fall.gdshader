shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
void fragment() {
	// Authored arc-length UV continues from the upper stream over the lip.
	// glTF flips Blender's V coordinate; convert it back to downstream distance.
	// Subtracting TIME moves each pattern toward the impact pool.
	float downstream = 1.0 - UV.y;
	float flow = downstream * 13.0 - TIME * 1.6;
	float ribbons = surface_noise(vec3(UV.x * 17.0, flow * .55, 1.0));
	float fine = surface_noise(vec3(UV.x * 43.0, flow * 1.5, 5.0));
	float falling = smoothstep(.46, .65, downstream);
	float thread = smoothstep(.38, .79, ribbons) * .66 + smoothstep(.62,.86,fine) * .22;
	float impact = smoothstep(.88, 1.0, downstream) * .45;
	ALBEDO = mix(vec3(.035,.40,.60), vec3(.65,.88,.92), clamp(thread * mix(.3,1.0,falling) + impact,0.0,.95));
	EMISSION = ALBEDO * .10;
	ROUGHNESS = .32;
	SPECULAR = .48;
}
