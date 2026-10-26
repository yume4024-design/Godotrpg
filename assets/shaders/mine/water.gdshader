shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=world_position.xz;
	float drift=TIME*.42;
	float broad=surface_noise(vec3(p*.32+vec2(.12,-drift*.12),1.0));
	float ripples=sin(p.x*2.4+p.y*1.1-drift*3.2+ broad*4.0);
	float thin=surface_noise(vec3(p.x*.9,p.y*2.8-drift,4.0));
	vec3 wave=normalize(vec3(sin(p.y*2.2-drift)*.09,1.0,cos(p.x*1.7+drift)*.08));
	NORMAL=normalize(mat3(VIEW_MATRIX)*wave);
	float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),VIEW),0.0,1.0),4.0);
	vec3 body=mix(vec3(.025,.15,.22),vec3(.075,.43,.51),broad*.7+.20);
	float glint=smoothstep(.82,.95,thin)*.12;
	ALBEDO=body*(.96+ripples*.045)+vec3(.17,.32,.34)*(fresnel*.15+glint);
	ROUGHNESS=.24;
	SPECULAR=.62;
}
