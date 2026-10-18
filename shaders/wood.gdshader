shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 timber_color : source_color = vec4(0.75,0.53,0.33,1);
uniform sampler2D oak_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D oak_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float grain_offset = 0.0;
varying vec3 local_pos;

void vertex() {
    local_pos = VERTEX;
}
void fragment() {
    // Continuous planks: 2 longitudinal repeats per section, tinted by timber species.
    vec2 uv = vec2(local_pos.x*0.27+grain_offset, local_pos.z*0.16+grain_offset*0.4);
    vec3 fibers = texture(oak_albedo,uv).rgb;
    ALBEDO = timber_color.rgb * mix(vec3(0.80),fibers*1.54,0.73);
    NORMAL_MAP = texture(oak_normal,uv).rgb;
    NORMAL_MAP_DEPTH = 0.21;
    ROUGHNESS = 0.79 + texture(oak_albedo,uv).r * 0.12;
    SPECULAR = 0.18;
}
