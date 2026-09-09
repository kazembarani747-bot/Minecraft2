shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 tile_origin = vec2(0.0, 0.0);
uniform vec2 tile_size = vec2(0.25, 0.25);

void fragment() {
    vec2 local_uv = fract(UV);
    vec2 atlas_uv = tile_origin + local_uv * tile_size;
    ALBEDO = texture(atlas_texture, atlas_uv).rgb;
    ROUGHNESS = 1.0;
}
