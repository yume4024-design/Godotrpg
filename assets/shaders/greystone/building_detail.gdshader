shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"

// Runtime equivalent of fine Blender surface detail; no vertex displacement.
uniform vec4 base_color : source_color = vec4(0.84,0.78,0.65,1.0);
uniform int surface_kind = 0; // 0 lime plaster, 1 timber, 2 fired tile / slate
varying vec3 detail_position;
void vertex() {
	detail_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec3 p = detail_position;
	float broad = surface_noise(p * 2.1);
	float fine = surface_noise(p * 31.0);
	float height = 0.0;
	float shade = 1.0;
	float rough = 0.88;
	// Fade subpixel detail instead of introducing shimmering at the overview.
	float footprint = length(fwidth(p));
	float fine_weight = 1.0 - smoothstep(0.015,0.075,footprint);
	if (surface_kind == 0) {
		float trowel = surface_noise(p * vec3(5.0,2.0,5.0));
		shade = 0.95 + broad*0.075 + (fine-0.5)*0.075*fine_weight;
		height = (trowel-0.5)*0.006 + (fine-0.5)*0.004*fine_weight;
		rough = 0.88 + fine*0.10;
	} else if (surface_kind == 1) {
		float fibre = surface_noise(p * vec3(12.0,0.7,12.0));
		float grain = sin((p.x+p.z)*57.0 + broad*7.0 + p.y*0.8);
		float grooves = pow(0.5+0.5*grain,8.0)*fine_weight;
		shade = 0.93 + fibre*0.12 - grooves*0.025;
		height = (fibre-0.5)*0.002 - grooves*0.0005;
		rough = 0.78 + fibre*0.14;
	} else {
		shade = 0.94 + broad*0.10 + (fine-0.5)*0.06*fine_weight;
		height = (broad-0.5)*0.008 + (fine-0.5)*0.003*fine_weight;
		rough = 0.82 + fine*0.13;
	}
	ALBEDO = base_color.rgb * shade;
	ROUGHNESS = rough;
	SPECULAR = 0.22;
	// Derivative surface-gradient bump works on imported meshes without tangents.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 rx = cross(dy,NORMAL);
	vec3 ry = cross(NORMAL,dx);
	float determinant = dot(dx,rx);
	vec3 gradient = sign(determinant)*(dFdx(height)*rx+dFdy(height)*ry);
	if (abs(determinant)>0.0000001) {
		NORMAL = normalize(abs(determinant)*NORMAL-gradient);
	}
}
