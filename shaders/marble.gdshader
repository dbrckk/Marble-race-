shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Layered soda-glass appearance, swirled candy pigment and miniature internal flecks.
// Shader stays compatible with Godot 4 Compatibility renderer on Android.
uniform vec4 base_color : source_color = vec4(0.95, 0.39, 0.15, 1.0);
uniform vec4 accent_color : source_color = vec4(0.15, 0.45, 0.76, 1.0);
uniform vec4 vein_color : source_color = vec4(1.0, 0.92, 0.78, 1.0);
uniform float pattern_seed = 0.0;
uniform float stripe_scale = 1.0;
varying vec3 object_pos;

void vertex() {
    object_pos = VERTEX;
}

void fragment() {
    vec3 n = normalize(object_pos);
    float lon = atan(n.z,n.x);
    float twist = n.y * (8.0 + stripe_scale * 1.8);
    twist += sin(lon * (3.6 + stripe_scale * 0.7) + pattern_seed * 0.33)*1.22;
    twist += sin(n.x*17.0 - n.z*11.0 + pattern_seed*2.8)*0.26;
    float swirl = sin(twist*2.6 + pattern_seed*3.2);
    float agate = sin(twist*0.9 + sin(lon*5.2 + pattern_seed)*0.85);
    float band = smoothstep(-0.06,0.76,swirl);
    float white = smoothstep(0.66,0.96,sin(twist*2.5+sin(lon*7.0)*0.15));
    vec3 pigment = mix(base_color.rgb,accent_color.rgb,band*0.73);
    pigment = mix(pigment,vein_color.rgb,white*0.82);
    pigment *= 0.89 + agate*0.09;
    float inclusions = step(0.982,fract(sin(dot(floor(n.xz*105.0+pattern_seed*19.0),vec2(12.9898,78.233)))*43758.5453));
    pigment += vec3(0.24,0.21,0.16)*inclusions;
    float ndv = max(dot(normalize(NORMAL),normalize(VIEW)),0.0);
    float optical_edge = pow(1.0 - ndv,3.3);
    ALBEDO = mix(clamp(pigment,vec3(0.0),vec3(1.0)),vec3(0.90,0.98,1.0),optical_edge*0.36);
    ROUGHNESS = 0.085 + 0.042*band;
    METALLIC = 0.045;
    SPECULAR = 0.96;
    CLEARCOAT = 0.94;
    RIM = 0.16;
    RIM_TINT = 0.25;
    EMISSION = pigment * 0.025;
}
