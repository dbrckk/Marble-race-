shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;
uniform vec4 shadow_color : source_color = vec4(0.15,0.09,0.06,0.45);
varying float contact_alpha;

void vertex() {
    contact_alpha = INSTANCE_CUSTOM.a;
}

void fragment() {
    vec2 q = UV * 2.0 - 1.0;
    // Squared radius avoids a per-fragment square root on mobile GPUs.
    // A broad penumbra and tight contact core anchor the marble to the
    // inclined track without a second mesh, light or draw call.
    float radius_sq = dot(q, q);
    float penumbra = 1.0 - smoothstep(0.02, 1.0, radius_sq);
    float contact_core = 1.0 - smoothstep(0.0, 0.20, radius_sq);
    float opacity = 0.66 * penumbra + 0.34 * contact_core;
    ALBEDO = shadow_color.rgb;
    ALPHA = shadow_color.a * opacity * contact_alpha;
}
