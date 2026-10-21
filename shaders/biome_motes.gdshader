shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// One GPU-instanced batch per level, no particles, physics or CPU animation.
// Colors and sway distinguish fireflies, flurries and hot embers.
uniform vec4 mote_color : source_color = vec4(0.9, 0.8, 0.5, 0.6);
uniform float drift_speed : hint_range(0.0, 4.0) = 0.8;
uniform float drift_span : hint_range(0.0, 1.2) = 0.35;

void vertex() {
    float seed = float(INSTANCE_ID);
    float tick = TIME * drift_speed + seed * 1.37;
    VERTEX.x += sin(tick) * drift_span;
    VERTEX.y += sin(tick * 0.73 + seed * 0.31) * drift_span * 0.85;
    VERTEX.z += cos(tick * 0.52) * drift_span * 0.42;
}

void fragment() {
    ALBEDO = mote_color.rgb;
    EMISSION = mote_color.rgb * 1.24;
    ALPHA = mote_color.a;
}
