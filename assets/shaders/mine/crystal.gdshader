shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
varying vec3 facet_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	facet_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float facet = clamp(dot(normalize(facet_normal),normalize(vec3(-.6,1.0,.35)))*.5+.5,0.0,1.0);
	float veins = pow(max(0.0,sin(world_position.y*2.1+world_position.x*.7+world_position.z*.5)),18.0);
	ALBEDO = mix(vec3(.025,.14,.38),vec3(.20,.75,.94),facet) + veins*.035;
	EMISSION = mix(vec3(.008,.035,.09),vec3(.025,.16,.25),facet);
	ROUGHNESS = .28;
	SPECULAR = .62;
}
