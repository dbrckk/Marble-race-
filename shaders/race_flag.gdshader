shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 cloth_color : source_color = vec4(0.95,0.25,0.28,1.0);
uniform float phase_offset = 0.0;
varying float wave_light;

void vertex() {
    float bend = clamp((VERTEX.x + 0.6)/1.2, 0.0, 1.0);
    float wiggle = sin(TIME * 3.3 + VERTEX.x * 7.5 + phase_offset);
    float secondary = sin(TIME * 1.8 - VERTEX.z * 8.0 + phase_offset);
    VERTEX.y += (wiggle * 0.12 + secondary*0.045) * bend;
    wave_light = wiggle;
}
void fragment() {
    vec3 cloth = cloth_color.rgb * (0.83 + 0.14 * wave_light + 0.03*sin(UV.x*50.0));
    ALBEDO = cloth;
}
