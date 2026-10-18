shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform vec4 base_color : source_color = vec4(0.9, 0.27, 0.20, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.83, 0.34, 1.0);
uniform vec4 vein_color : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform float pattern_seed = 0.0;
uniform float stripe_scale = 1.0;

varying vec3 obj_position;

void vertex() {
    obj_position = VERTEX;
}

void fragment() {
    vec3 n = normalize(obj_position);
    float latitude = atan(n.z, n.x);
    float wave = n.y * 7.5 + sin(latitude * (2.5 + stripe_scale) + pattern_seed * 2.2) * 1.25;
    wave += sin(n.x * 12.0 + n.z * 8.0 + pattern_seed * 9.0) * 0.48;
    float sw = sin(wave * 2.4 + pattern_seed * 3.0);
    float veins = smoothstep(0.31, 0.76, sw) - smoothstep(0.86, 0.99, sw);
    float ribbon = smoothstep(0.46, 0.84, sin(wave + pattern_seed));
    float glass_depth = 0.84 + 0.14 * sin(n.y * 19.0 + latitude * 4.0);
    vec3 surface = mix(base_color.rgb, accent_color.rgb, ribbon * 0.66);
    surface = mix(surface, vein_color.rgb, veins * 0.65);
    float speck = step(0.988, fract(sin(dot(floor(n.xz * 83.0 + pattern_seed * 53.0), vec2(12.9898, 78.233))) * 43758.5453));
    ALBEDO = clamp(surface * glass_depth + speck * 0.23, vec3(0.0), vec3(1.0));
    METALLIC = 0.10;
    ROUGHNESS = 0.13;
    SPECULAR = 0.93;
    CLEARCOAT = 0.95;
}
