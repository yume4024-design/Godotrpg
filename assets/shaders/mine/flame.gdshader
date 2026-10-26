shader_type spatial;
render_mode unshaded;
varying vec3 flame_position;
void vertex() { flame_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float pulse = sin(TIME * 9.0 + flame_position.x * 2.1 + flame_position.z);
    vec3 heat = mix(vec3(1.0,.78,.22),vec3(.95,.16,.012),COLOR.g);
    ALBEDO = heat;
    EMISSION = heat * (0.30 + pulse * 0.07);
}
