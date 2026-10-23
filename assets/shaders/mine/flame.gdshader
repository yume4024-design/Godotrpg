shader_type spatial;
render_mode unshaded;
varying vec3 flame_position;
void vertex() { flame_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float pulse = sin(TIME * 9.0 + flame_position.x * 2.1 + flame_position.z);
    ALBEDO = vec3(0.95,0.26,0.025);
    EMISSION = vec3(1.0,0.22,0.012) * (0.48 + pulse * 0.07);
}
