shader_type spatial;
#include "res://assets/shaders/greystone/surface_noise.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.43,0.27,0.13,1.0);
varying vec3 wood_position;
void vertex() { wood_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float noise = surface_noise(wood_position * vec3(1.2,7.0,1.2));
    float grain = sin(wood_position.y * 17.0 + noise * 4.0 + wood_position.x * 0.9);
    ALBEDO = base_color.rgb * (0.90 + noise * 0.18 + grain * 0.035);
    ROUGHNESS = 0.85;
}
