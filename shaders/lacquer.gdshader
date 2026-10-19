shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 pigment : source_color = vec4(0.85,0.46,0.32,1.0);
uniform sampler2D micro_texture : repeat_enable, filter_linear_mipmap;
uniform float polish = 0.68;
varying vec3 local_p;

void vertex() {
    local_p = VERTEX;
}

void fragment() {
    // Physically plausible satin lacquer: painted polymer with tiny flakes,
    // rounded-edge reflection and local roughness variation from a 256px map.
    // A single filtered texture fetch replaces three per-pixel trig functions.
    vec2 uv = local_p.xz * 5.0 + local_p.yx * 0.22;
    vec3 micro = texture(micro_texture, uv).rgb;
    float fibers = (micro.r - 0.5) * 0.085;
    float flecks = smoothstep(0.88, 0.98, micro.g) * 0.075;
    float facing = max(dot(normalize(NORMAL),normalize(VIEW)),0.0);
    float polish_edge = pow(1.0-facing,3.0);

    vec3 paint = pigment.rgb * (0.96 + fibers);
    paint += vec3(flecks);
    paint = mix(paint,paint*1.16 + vec3(0.012),polish_edge*0.31);
    ALBEDO = clamp(paint,vec3(0.0),vec3(1.0));
    ROUGHNESS = clamp(0.43 - polish*0.24 + (micro.b-0.5)*0.084,0.14,0.52);
    METALLIC = 0.045;
    SPECULAR = 0.86;
    CLEARCOAT = 0.82;
}
