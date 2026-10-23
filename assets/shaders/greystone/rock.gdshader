shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.48, 0.49, 0.46, 1.0);
uniform vec4 moss_color : source_color = vec4(0.39, 0.47, 0.25, 1.0);
varying vec3 surface_position;
varying vec3 surface_normal;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = surface_position;
	float broad = surface_noise(p * 0.9);
	float grain = surface_noise(p * 13.0);
	float bands = abs(sin(p.y * 3.4 + broad * 5.7 + p.x * 0.43 + p.z * 0.28));
	float veins = (1.0 - smoothstep(0.035, 0.16, bands)) * 0.09;
	float moss = smoothstep(0.55, 0.78, surface_noise(p * 1.3)) * smoothstep(0.15, 0.8, surface_normal.y);
	float wet_edge = (1.0 - smoothstep(2.1, 3.2, p.y)) * 0.19;
	vec3 stone = base_color.rgb * (0.83 + broad * 0.30 + (grain - 0.5) * 0.16 - veins - wet_edge);
	ALBEDO = mix(stone, moss_color.rgb, moss * 0.43);
	ROUGHNESS = 0.91 + grain * 0.07;
	SPECULAR = 0.20;
}
