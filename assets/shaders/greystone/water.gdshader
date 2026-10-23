shader_type spatial;
render_mode depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 shallow_color : source_color = vec4(0.19, 0.63, 0.66, 1.0);
uniform vec4 deep_color : source_color = vec4(0.055, 0.32, 0.48, 1.0);
uniform vec4 foam_color : source_color = vec4(0.76, 0.91, 0.87, 1.0);
uniform float flow_speed : hint_range(0.0, 4.0) = 0.65;
uniform float falling : hint_range(0.0, 1.0) = 0.0;
varying vec3 surface_position;
varying vec3 surface_normal;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = mix(surface_position.xz, surface_position.xy, falling);
	p.y -= TIME * flow_speed * mix(1.0, -1.0, falling);
	float noise = surface_noise(vec3(p * 1.25, TIME * 0.16));
	float ripple = sin(p.x * 2.4 + p.y * 3.0 + noise * 4.0);
	vec3 wave_normal = normalize(vec3(sin(p.y * 3.0 + noise) * 0.13, 1.0, cos(p.x * 2.4 + noise) * 0.10));
	NORMAL = normalize(mat3(VIEW_MATRIX) * normalize(mix(wave_normal, surface_normal, falling)));
	float depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 background_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	background_view.xyz /= background_view.w;
	float thickness = max(0.0, -background_view.z + VERTEX.z);
	float absorption = 1.0 - exp(-thickness * 0.48);
	float shore = (1.0 - smoothstep(0.06, 0.85, thickness)) * smoothstep(0.30, 0.72, noise);
	float streak = smoothstep(0.70, 0.96, surface_noise(vec3(p.x * 5.0, p.y * 0.55, TIME * 0.2)));
	float foam = mix(shore * 0.78, streak * 0.64, falling);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 3.0);
	vec3 body = mix(shallow_color.rgb, deep_color.rgb, absorption * (1.0 - falling));
	body *= 0.96 + ripple * 0.035;
	body = mix(body, vec3(0.48, 0.73, 0.80), fresnel * 0.34);
	ALBEDO = mix(body, foam_color.rgb, foam);
	EMISSION = foam_color.rgb * foam * 0.06;
	ROUGHNESS = mix(0.20, 0.39, falling);
	SPECULAR = 0.68;
	ALPHA = mix(0.88, 0.78, falling);
}
