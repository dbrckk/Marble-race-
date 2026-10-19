shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec4 shadow_color : source_color = vec4(0.15,0.09,0.06,0.45);

void fragment() {
    vec2 q = UV * 2.0 - 1.0;
    float dist = length(q);
    float disc = 1.0 - smoothstep(0.12, 1.0, dist);
    ALBEDO = shadow_color.rgb;
    ALPHA = shadow_color.a * disc;
}
