shader_type spatial;
render_mode diffuse_burley;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"

// World-space union avoids grassy seams where two trail modules overlap.
uniform vec4 trail_rects[6]; // center x/z, half size x/z
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec3 p=world_position;
	float edge=-1000.0;
	for (int i=0;i<6;i++) {
		vec2 d=trail_rects[i].zw-abs(p.xz-trail_rects[i].xy);
		edge=max(edge,min(d.x,d.y));
	}
	float patches=surface_noise(p*.38)*.65+surface_noise(p*1.8)*.35;
	float grain=surface_noise(p*24.0);
	float variation=.83+patches*.32+(grain-.5)*.09;
	vec3 grass=vec3(.24,.39,.22)*variation;
	vec3 earth=vec3(.52,.43,.26)*variation;
	float noisy_margin=.22+surface_noise(p*3.0)*.28;
	float trail=smoothstep(.02,noisy_margin,edge);
	ALBEDO=mix(grass,earth,trail);
	ROUGHNESS=.94;
	SPECULAR=.16;
}
