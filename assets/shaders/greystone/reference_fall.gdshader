shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
uniform bool horizontal = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = horizontal ? world_position.xz : world_position.xy;
	float flow = p.y * .55 + TIME * 2.5;
	float ribbons = surface_noise(vec3(p.x*2.8,flow*.5,0.0));
	float thread = smoothstep(.56,.84,ribbons);
	vec3 blue = vec3(.035,.37,.58);
	vec3 white = vec3(.43,.76,.85);
	ALBEDO = mix(blue,white,thread*(horizontal ? .3 : .82));
	EMISSION = ALBEDO * .07;
	ROUGHNESS = .28;
	SPECULAR = .55;
}
