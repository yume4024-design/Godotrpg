shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.52, 0.64, 0.29, 1.0);
uniform vec4 grain_color : source_color = vec4(0.70, 0.66, 0.46, 1.0);
uniform float grass_amount : hint_range(0.0, 1.0) = 1.0;
varying vec3 surface_position;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = surface_position;
	float patches = surface_noise(p * 0.38) * 0.65 + surface_noise(p * 1.8) * 0.35;
	float grain = surface_noise(p * 24.0);
	vec2 cell = floor(p.xz * 3.0);
	vec2 center = vec2(surface_hash(vec3(cell, 2.0)), surface_hash(vec3(cell, 8.0)));
	float stones = 1.0 - smoothstep(0.08, 0.21, length(fract(p.xz * 3.0) - center));
	float blades = smoothstep(0.82, 0.98, grain) * surface_noise(p * 4.0);
	vec3 soil = base_color.rgb * (0.83 + patches * 0.32 + (grain - 0.5) * 0.09);
	float detail = mix(stones * 0.22, blades * 0.18, grass_amount);
	ALBEDO = mix(soil, grain_color.rgb, detail);
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
}
