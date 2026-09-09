shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D atlas_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 tile_origin = vec2(0.0, 0.0);
uniform vec2 tile_size = vec2(0.25, 0.25);
uniform float world_light = 1.0;

void fragment() {
    vec2 local_uv = fract(UV);
    vec2 atlas_uv = tile_origin + local_uv * tile_size;
    vec3 base = texture(atlas_texture, atlas_uv).rgb;
    float ao = mix(0.52, 1.0, COLOR.r);
    float voxel_light = mix(0.22, 1.0, COLOR.g);
    ALBEDO = base * ao * voxel_light * world_light;
    ROUGHNESS = 1.0;
}
