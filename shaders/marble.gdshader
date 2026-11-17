shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Procedural multilayer optical glass. Opaque on purpose: stable with GL Compatibility
// and dozens of simultaneously overlapping marbles on mobile GPUs.
uniform vec4 base_color : source_color = vec4(0.95, 0.37, 0.15, 1.0);
uniform vec4 accent_color : source_color = vec4(0.07, 0.47, 0.71, 1.0);
uniform vec4 vein_color : source_color = vec4(1.0, 0.94, 0.72, 1.0);
uniform float pattern_seed = 0.0;
uniform float stripe_scale = 1.0;
uniform float boost_strength : hint_range(0.0,1.0) = 0.0;
uniform float visual_quality : hint_range(0.0,2.0) = 1.0;
// Exclusive cosmetics only: zero preserves every original marble unchanged.
uniform float skin_radiance : hint_range(0.0,1.0) = 0.0;
uniform float skin_signature = 0.0;
varying vec3 marble_local;

float hash_13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x+p.y)*p.z);
}

void vertex() {
    marble_local = VERTEX;
}

void fragment() {
    vec3 p = normalize(marble_local);
    float theta = atan(p.z,p.x);
    float swirl = p.y * (10.0 + stripe_scale * 2.0);
    swirl += sin(theta * (3.0 + stripe_scale*1.2) + pattern_seed) * 1.6;
    swirl += sin(p.x * 16.0 + p.z * 12.0 + pattern_seed*4.2) * 0.43;
    float main_phase = swirl*1.85 + pattern_seed*3.2;
    float vein_phase = swirl*3.2 + sin(theta*7.0 + p.y*9.0)*0.55 + pattern_seed*2.3;
    float layer = smoothstep(-0.18,0.58,sin(main_phase))*0.79;
    float milk = pow(smoothstep(0.38,0.92,sin(vein_phase)),2.1);
    // Unresolved bands converge to their cycle averages instead of flickering.
    layer = mix(layer,0.34355,smoothstep(1.1,4.2,fwidth(main_phase)));
    milk = mix(milk,0.23893,smoothstep(0.85,3.8,fwidth(vein_phase)));
    // Core seems to float just under a polished shell.
    vec3 glass = mix(base_color.rgb,accent_color.rgb,layer);
    glass = mix(glass,vein_color.rgb,milk*0.71);
    // Ten premium waveforms, retaining mobile GL compatibility: no
    // transparency sorting, secondary texture, geometry pass or extra mesh.
    float signature = skin_signature*0.71;
    float aurora = sin(theta*(3.0+mod(skin_signature,4.0))+
        p.y*(10.0+mod(skin_signature,3.0)*4.0)+
        TIME*(0.45+mod(skin_signature,5.0)*0.15)+signature);
    float stardust = pow(max(0.0,aurora),5.0);
    glass = mix(glass,vein_color.rgb,
        stardust*skin_radiance*0.52);
    float inner_glow = 0.84+0.13*sin(swirl*0.37 + theta*2.0);
    glass *= inner_glow;
    vec3 grain = p*(68.0+visual_quality*14.0)+pattern_seed*7.0;
    float sparkle = step(0.994,hash_13(floor(grain)));
    float grain_coverage = 1.0-smoothstep(0.50,1.45,length(fwidth(grain)));
    glass += sparkle*grain_coverage*vein_color.rgb*0.22;
    // Fake optical Fresnel: helps spheres read as glass without expensive transparency.
    float facing = clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
    float fresnel = pow(1.0-facing,3.1);
    vec3 rim_color = mix(vec3(0.65,0.86,1.0),vein_color.rgb,0.40);
    // Two broad photographic softbox reflections as a cheap fake studio environment.
    // Reflection moves naturally as the glass marble rolls (no screen-space reflections).
    vec3 reflected = reflect(-normalize(VIEW),normalize(NORMAL));
    float softbox_a = pow(max(dot(reflected,normalize(vec3(0.42,0.8,0.36))),0.0),18.0);
    float softbox_b = pow(max(dot(reflected,normalize(vec3(-0.68,0.23,0.62))),0.0),42.0) * step(0.5,visual_quality);
    vec3 chrome_luster = vec3(0.98,0.94,0.84)*softbox_a*0.33
                         + vec3(0.78,0.91,1.0)*softbox_b*0.21;
    ALBEDO = clamp(mix(glass,rim_color,fresnel*0.58)+chrome_luster,vec3(0.0),vec3(1.0));
    ROUGHNESS = mix(0.12,0.056,boost_strength) + layer*0.028;
    METALLIC = 0.03;
    SPECULAR = 0.96;
    CLEARCOAT = 0.91;
    RIM = 0.23 + boost_strength*0.18;
    RIM_TINT = 0.26;
    EMISSION = glass*(0.022+boost_strength*0.09+skin_radiance*(0.21+stardust*0.34));
}
