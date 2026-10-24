shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.52, 0.64, 0.29, 1.0);
uniform vec4 grain_color : source_color = vec4(0.70, 0.66, 0.46, 1.0);
uniform float grass_amount : hint_range(0.0, 1.0) = 1.0;
uniform float road_edge_blend : hint_range(0.0, 1.0) = 0.0;
uniform vec4 verge_color : source_color = vec4(0.35,0.44,0.22,1.0);
uniform int clearing_edge_count = 0;
uniform vec2 clearing_edge_start[32];
uniform vec2 clearing_edge_end[32];
varying vec3 surface_position;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = surface_position;
	// Cut only the narrow outer verge. Underlying grass, or another crossing
	// road, is then visible; painting green here creates seams at junctions.
	if (grass_amount < 0.5) {
		float edge = min(UV.x, 1.0 - UV.x);
		float broken_verge = surface_noise(p * 3.8) * 0.038 + surface_noise(p * 10.0) * 0.018;
		if (edge < broken_verge) { discard; }
		// Use the actual imported clearing boundary. Crossing road strips still
		// show through, so this cannot paint green seams across a junction.
		if (clearing_edge_count > 0) {
			float distance_to_edge = 1000.0;
			for (int i = 0; i < clearing_edge_count; i++) {
				vec2 a = clearing_edge_start[i];
				vec2 d = clearing_edge_end[i] - a;
				float t = clamp(dot(p.xz-a, d) / max(dot(d,d), 0.0001), 0.0, 1.0);
				distance_to_edge = min(distance_to_edge, length(p.xz-a-d*t));
			}
			float erosion = 0.07 + surface_noise(p*2.2)*0.22 + surface_noise(p*6.5)*0.12;
			if (distance_to_edge < erosion) { discard; }
		}
	}
	float patches = surface_noise(p * 0.38) * 0.65 + surface_noise(p * 1.8) * 0.35;
	float grain = surface_noise(p * 24.0);
	vec2 cell = floor(p.xz * 3.0);
	vec2 center = vec2(surface_hash(vec3(cell, 2.0)), surface_hash(vec3(cell, 8.0)));
	float stones = 1.0 - smoothstep(0.08, 0.21, length(fract(p.xz * 3.0) - center));
	float blades = smoothstep(0.82, 0.98, grain) * surface_noise(p * 4.0);
	vec3 soil = base_color.rgb * (0.83 + patches * 0.32 + (grain - 0.5) * 0.09);
	if (grass_amount > 0.5) {
		float broad_patches = smoothstep(0.26, 0.76, surface_noise(p * 0.55));
		soil *= 0.92 + broad_patches * 0.19;
	}
	float detail = mix(stones * 0.22, blades * 0.18, grass_amount);
	ALBEDO = mix(soil, grain_color.rgb, detail);
	// One world-space soil color across intersecting road strips and the square.
	// Painting green along every strip edge created seams inside the plaza.
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
}
