shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled, diffuse_burley;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 tile_origin = vec2(0.75, 0.0);
uniform vec2 tile_size = vec2(0.25, 0.25);
uniform float time_seconds = 0.0;

void fragment() {
    vec2 local_uv = fract(UV);
    vec2 atlas_uv = tile_origin + local_uv * tile_size;
    vec3 base = texture(atlas_texture, atlas_uv).rgb;
    float ripple = 0.035 * sin((UV.x + time_seconds * 0.08) * 6.2831) * cos((UV.y - time_seconds * 0.06) * 6.2831);
    ALBEDO = base + vec3(ripple);
    ROUGHNESS = 0.08;
    METALLIC = 0.02;
    ALPHA = 0.68;
}

void vertex() {
    float wave = sin((VERTEX.x + time_seconds * 1.4) * 0.45) * 0.025;
    wave += cos((VERTEX.z - time_seconds * 1.1) * 0.38) * 0.025;
    VERTEX.y += wave;
}
