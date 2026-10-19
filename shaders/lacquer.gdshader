shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 pigment : source_color = vec4(0.85,0.46,0.32,1.0);
uniform float polish = 0.68;
varying vec3 local_p;
void vertex() {
    local_p = VERTEX;
}
void fragment() {
    // Fine molded-plastic micro-flecks & edge wear, no texture downloads.
    float grain = sin(local_p.x*130.0+local_p.z*13.0)*sin(local_p.z*94.0-local_p.y*33.0);
    float fleck = step(0.988,fract(sin(dot(floor(local_p.xz*183.0),vec2(12.9898,78.233)))*43758.5453));
    float edge = max(abs(local_p.x),max(abs(local_p.y),abs(local_p.z)));
    vec3 paint = pigment.rgb*(0.973+grain*0.022);
    paint = mix(paint,paint*1.1,clamp(edge*0.055,0.0,0.15));
    paint += vec3(fleck)*0.055;
    ALBEDO = clamp(paint,vec3(0.0),vec3(1.0));
    ROUGHNESS = clamp(0.43-polish*0.24+grain*0.033,0.13,0.55);
    METALLIC = 0.04;
    SPECULAR = 0.82;
    CLEARCOAT = 0.72;
}
