shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 timber_color : source_color = vec4(0.63, 0.43, 0.29, 1.0);
varying vec3 local_p;

void vertex() {
    local_p = VERTEX;
}
void fragment() {
    vec2 uv = local_p.xz;
    float elongated = sin(uv.x * 28.0 + sin(uv.y * 1.7) * 0.3 + sin(uv.y * 7.4) * 0.13);
    float small = sin(uv.x * 95.0 + sin(uv.y * 4.4) * 1.6) * 0.32;
    float grain = elongated * 0.11 + small * 0.048;
    float pores = sin(uv.y * 91.0 + uv.x * 13.0) * 0.018;
    float knots = sin(length(vec2(uv.x * 2.9, uv.y * 0.25)) * 17.0) * 0.036;
    float tone = 1.0 + grain + pores + knots;
    ALBEDO = timber_color.rgb * tone;
    ROUGHNESS = 0.83;
    SPECULAR = 0.20;
}