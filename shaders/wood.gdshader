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
    // Fade the small-scale relief before dropping its texture lookup.
    float detail = 1.0-smoothstep(14.0,28.0,-VERTEX.z);
    // Explicit gradients stay valid where nearby fragments enter different branches.
    vec2 uv_dx = dFdx(uv);
    vec2 uv_dy = dFdy(uv);
    NORMAL_MAP = vec3(0.5,0.5,1.0);
    NORMAL_MAP_DEPTH = 0.27*detail;
    float filament_roughness = 0.0;
    if (detail > 0.0) {
        NORMAL_MAP = textureGrad(oak_normal,uv,uv_dx,uv_dy).rgb;
        float filaments = sin(uv.x * 115.0 + sin(uv.y * 9.0) * 1.3);
        filament_roughness = filaments*0.045*detail;
    }
    ROUGHNESS = clamp(0.68 + filament_roughness + (1.0 - fibers.r) * 0.12, 0.53, 0.91);
    SPECULAR = 0.18;
}
