shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.48, 0.49, 0.46, 1.0);
uniform vec4 moss_color : source_color = vec4(0.39, 0.47, 0.25, 1.0);
uniform bool masonry_joints = false;
varying vec3 surface_position;
varying vec3 surface_normal;
varying vec3 local_position;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_position = VERTEX;
}

void fragment() {
	vec3 p = surface_position;
	float broad = surface_noise(p * 0.9);
	float grain = surface_noise(p * 13.0);
	float bands = abs(sin(p.y * 3.4 + broad * 5.7 + p.x * 0.43 + p.z * 0.28));
	float veins = (1.0 - smoothstep(0.035, 0.16, bands)) * 0.025;
	float moss = smoothstep(0.55, 0.78, surface_noise(p * 1.3)) * smoothstep(0.15, 0.8, surface_normal.y);
	float wet_edge = (1.0 - smoothstep(2.1, 3.2, p.y)) * 0.19;
	// Broad facet color carries the cliff form; retain quiet grain at player scale.
	vec3 cool = base_color.rgb * vec3(0.91, 0.98, 1.08);
	vec3 warm = base_color.rgb * vec3(1.09, 1.025, 0.92);
	vec3 stone = mix(cool, warm, smoothstep(0.24, 0.77, surface_noise(p * 0.21)));
	stone *= 0.89 + broad * 0.20 + (grain - 0.5) * 0.045 - veins - wet_edge;
	ALBEDO = mix(stone, moss_color.rgb, moss * 0.43);
	ALBEDO *= COLOR.rgb;
	if (masonry_joints) {
		float courses = floor(p.y * 5.5);
		float joint = fract(local_position.x / 1.24 + mod(courses, 2.0) * 0.5);
		float mortar = 1.0 - smoothstep(0.008, 0.026, min(joint, 1.0-joint));
		ALBEDO *= 1.0 - mortar * 0.22;
	}
	ROUGHNESS = 0.91 + grain * 0.07;
	SPECULAR = 0.20;
}
