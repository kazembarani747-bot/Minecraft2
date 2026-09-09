extends Node

# Minecraft2 chunk renderer: greedy meshing + 16x16 atlas + per-vertex voxel AO.
# Runtime updates invalidate only the affected chunk and its border neighbors.
const CHUNK_SIZE := 16
const WORLD_HEIGHT := 64
const RENDER_RADIUS := 4
const UPDATE_SECONDS := 0.5
const ATLAS_PATH := "res://assets/textures/minecraft2_atlas.svg"
const SHADER_PATH := "res://core/voxel_atlas.gdshader"

var world
var player: Node3D
var root: Node3D
var rendered: Dictionary = {}
var timer := 0.0
var atlas_texture: Texture2D
var atlas_shader: Shader
var material_cache: Dictionary = {}
var dirty_render_chunks: Dictionary = {}

func _ready() -> void:
    world = get_node_or_null("/root/Minecraft2WorldEngine")
    atlas_texture = load(ATLAS_PATH) as Texture2D
    atlas_shader = load(SHADER_PATH) as Shader
    await get_tree().process_frame
    player = get_tree().current_scene.get_node_or_null("Player") as Node3D
    if world == null or player == null or atlas_texture == null or atlas_shader == null:
        return
    if world.has_signal("block_changed"):
        world.block_changed.connect(_on_block_changed)
    if world.has_signal("lighting_changed"):
        world.lighting_changed.connect(_on_lighting_changed)
    root = Node3D.new()
    root.name = "VoxelChunkRenderRoot"
    get_tree().current_scene.add_child(root)
    _remove_legacy_blocks()
    _sync_chunks()

func _process(delta: float) -> void:
    if world == null or player == null:
        return
    timer += delta
    if timer >= UPDATE_SECONDS:
        timer = 0.0
        _sync_chunks()

func _remove_legacy_blocks() -> void:
    var scene := get_tree().current_scene
    for child in scene.get_children():
        if child is StaticBody3D and child.name in ["grass", "dirt", "stone", "water"]:
            child.queue_free()

func _on_block_changed(position: Vector3i, _old_id: int, _new_id: int) -> void:
    _mark_dirty_for_position(position)

func _on_lighting_changed(position: Vector3i) -> void:
    _mark_dirty_for_position(position)

func _mark_dirty_for_position(position: Vector3i) -> void:
    var cx := floori(float(position.x) / CHUNK_SIZE)
    var cz := floori(float(position.z) / CHUNK_SIZE)
    dirty_render_chunks[world.chunk_key(cx, cz)] = true
    if posmod(position.x, CHUNK_SIZE) == 0:
        dirty_render_chunks[world.chunk_key(cx - 1, cz)] = true
    elif posmod(position.x, CHUNK_SIZE) == CHUNK_SIZE - 1:
        dirty_render_chunks[world.chunk_key(cx + 1, cz)] = true
    if posmod(position.z, CHUNK_SIZE) == 0:
        dirty_render_chunks[world.chunk_key(cx, cz - 1)] = true
    elif posmod(position.z, CHUNK_SIZE) == CHUNK_SIZE - 1:
        dirty_render_chunks[world.chunk_key(cx, cz + 1)] = true

func _sync_chunks() -> void:
    if world.has_method("_stream_now"):
        world._stream_now()
    var center := Vector2i(floori(player.global_position.x / CHUNK_SIZE), floori(player.global_position.z / CHUNK_SIZE))
    var needed := {}
    for key in world.chunks.keys():
        var parts := str(key).split(":")
        if parts.size() != 2:
            continue
        var cx := int(parts[0])
        var cz := int(parts[1])
        if abs(cx - center.x) <= RENDER_RADIUS and abs(cz - center.y) <= RENDER_RADIUS:
            needed[key] = true
            if dirty_render_chunks.has(key):
                if rendered.has(key):
                    rendered[key].queue_free()
                    rendered.erase(key)
                dirty_render_chunks.erase(key)
            if not rendered.has(key):
                _render_chunk(cx, cz)
    for key in rendered.keys():
        if not needed.has(key):
            rendered[key].queue_free()
            rendered.erase(key)

func _render_chunk(cx: int, cz: int) -> void:
    var node := Node3D.new()
    node.name = "Chunk_%d_%d" % [cx, cz]
    node.position = Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE)
    root.add_child(node)

    var buckets := _build_greedy_geometry(cx, cz)
    var face_count := 0
    for id in buckets.keys():
        if id == "__collision":
            continue
        var data: Dictionary = buckets[id]
        var vertices: PackedVector3Array = data["vertices"]
        if vertices.is_empty():
            continue
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = vertices
        arrays[Mesh.ARRAY_NORMAL] = data["normals"]
        arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
        arrays[Mesh.ARRAY_COLOR] = data["colors"]
        arrays[Mesh.ARRAY_INDEX] = data["indices"]
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        var mesh_instance := MeshInstance3D.new()
        mesh_instance.mesh = mesh
        mesh_instance.material_override = _material_for(int(id))
        mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        node.add_child(mesh_instance)
        face_count += int(data["faces"])

    if face_count == 0:
        node.queue_free()
        return

    var body := StaticBody3D.new()
    body.name = "Collision"
    var shape := CollisionShape3D.new()
    var concave := ConcavePolygonShape3D.new()
    concave.data = buckets["__collision"]
    shape.shape = concave
    body.add_child(shape)
    node.add_child(body)
    rendered[world.chunk_key(cx, cz)] = node

func _build_greedy_geometry(cx: int, cz: int) -> Dictionary:
    var buckets: Dictionary = {}
    buckets["__collision"] = PackedVector3Array()

    for normal_id in range(6):
        var config := _face_config(normal_id)
        var normal: Vector3i = config[0]
        var axis_vec: Vector3i = config[1]
        var u_vec: Vector3i = config[2]
        var v_vec: Vector3i = config[3]
        var slices: int = config[4]
        var u_count: int = config[5]
        var v_count: int = config[6]
        var positive := bool(config[7])

        for slice in range(slices):
            var mask: Array = []
            for v in range(v_count):
                var row: Array = []
                row.resize(u_count)
                row.fill(0)
                mask.append(row)

            for v in range(v_count):
                for u in range(u_count):
                    var local := axis_vec * slice + u_vec * u + v_vec * v
                    var world_pos := Vector3i(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE) + local
                    var id := world.get_block(world_pos)
                    if id == 0:
                        continue
                    if world.get_block(world_pos + normal) == 0:
                        mask[v][u] = id

            var v := 0
            while v < v_count:
                var u := 0
                while u < u_count:
                    var id := int(mask[v][u])
                    if id == 0:
                        u += 1
                        continue

                    var width := 1
                    while u + width < u_count and int(mask[v][u + width]) == id:
                        width += 1

                    var height := 1
                    var can_grow := true
                    while v + height < v_count and can_grow:
                        for x in range(width):
                            if int(mask[v + height][u + x]) != id:
                                can_grow = false
                                break
                        if can_grow:
                            height += 1

                    for yy in range(height):
                        for xx in range(width):
                            mask[v + yy][u + xx] = 0

                    var plane_offset := 1 if positive else 0
                    var origin_i := axis_vec * (slice + plane_offset) + u_vec * u + v_vec * v
                    var origin := Vector3(origin_i)
                    var du := Vector3(u_vec) * width
                    var dv := Vector3(v_vec) * height
                    var n := Vector3(normal)
                    _ensure_bucket(buckets, id)
                    _emit_quad(buckets[id], origin, du, dv, n, width, height, Vector3i(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE) + origin_i)
                    _emit_collision(buckets["__collision"], origin, du, dv)
                    u += width
                v += 1

    return buckets

func _ensure_bucket(buckets: Dictionary, id: int) -> void:
    if buckets.has(id):
        return
    buckets[id] = {
        "vertices": PackedVector3Array(),
        "normals": PackedVector3Array(),
        "uvs": PackedVector2Array(),
        "colors": PackedColorArray(),
        "indices": PackedInt32Array(),
        "faces": 0
    }

func _emit_quad(data: Dictionary, origin: Vector3, du: Vector3, dv: Vector3, normal: Vector3, width: int, height: int, world_origin: Vector3i) -> void:
    var vertices: PackedVector3Array = data["vertices"]
    var normals: PackedVector3Array = data["normals"]
    var uvs: PackedVector2Array = data["uvs"]
    var colors: PackedColorArray = data["colors"]
    var indices: PackedInt32Array = data["indices"]
    var base := vertices.size()
    var p0 := origin
    var p1 := origin + du
    var p2 := origin + du + dv
    var p3 := origin + dv
    vertices.append(p0); vertices.append(p1); vertices.append(p2); vertices.append(p3)
    for i in range(4):
        normals.append(normal)
    uvs.append(Vector2(0, 0)); uvs.append(Vector2(width, 0)); uvs.append(Vector2(width, height)); uvs.append(Vector2(0, height))

    var a0 := _corner_ao(world_origin, normal, du, dv, 0.0, 0.0)
    var a1 := _corner_ao(world_origin, normal, du, dv, 1.0, 0.0)
    var a2 := _corner_ao(world_origin, normal, du, dv, 1.0, 1.0)
    var a3 := _corner_ao(world_origin, normal, du, dv, 0.0, 1.0)
    colors.append(Color(a0, a0, a0, 1.0)); colors.append(Color(a1, a1, a1, 1.0))
    colors.append(Color(a2, a2, a2, 1.0)); colors.append(Color(a3, a3, a3, 1.0))

    indices.append(base); indices.append(base + 1); indices.append(base + 2)
    indices.append(base); indices.append(base + 2); indices.append(base + 3)
    data["vertices"] = vertices
    data["normals"] = normals
    data["uvs"] = uvs
    data["colors"] = colors
    data["indices"] = indices
    data["faces"] = int(data["faces"]) + 1

func _corner_ao(origin: Vector3i, normal: Vector3, du: Vector3, dv: Vector3, u_side: float, v_side: float) -> float:
    var face_axis_u := Vector3i(roundi(du.normalized().x), roundi(du.normalized().y), roundi(du.normalized().z))
    var face_axis_v := Vector3i(roundi(dv.normalized().x), roundi(dv.normalized().y), roundi(dv.normalized().z))
    var corner := origin
    if u_side > 0.5:
        corner += face_axis_u * max(1, int(abs(du.length())))
    if v_side > 0.5:
        corner += face_axis_v * max(1, int(abs(dv.length())))
    var side_u := face_axis_u if u_side < 0.5 else -face_axis_u
    var side_v := face_axis_v if v_side < 0.5 else -face_axis_v
    var n := Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
    var p := corner + n
    var s1 := world.get_block(p + side_u) != 0
    var s2 := world.get_block(p + side_v) != 0
    var diag := world.get_block(p + side_u + side_v) != 0
    var occlusion := 0
    if s1 and s2:
        occlusion = 3
    else:
        occlusion = int(s1) + int(s2) + int(diag)
    return 1.0 - float(occlusion) / 4.0

func _emit_collision(data: PackedVector3Array, origin: Vector3, du: Vector3, dv: Vector3) -> void:
    var p0 := origin
    var p1 := origin + du
    var p2 := origin + du + dv
    var p3 := origin + dv
    data.append(p0); data.append(p1); data.append(p2)
    data.append(p0); data.append(p2); data.append(p3)

func _face_config(normal_id: int) -> Array:
    match normal_id:
        0: return [Vector3i(1,0,0), Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1), CHUNK_SIZE, WORLD_HEIGHT, CHUNK_SIZE, true]
        1: return [Vector3i(-1,0,0), Vector3i(1,0,0), Vector3i(0,0,1), Vector3i(0,1,0), CHUNK_SIZE, CHUNK_SIZE, WORLD_HEIGHT, false]
        2: return [Vector3i(0,1,0), Vector3i(0,1,0), Vector3i(0,0,1), Vector3i(1,0,0), WORLD_HEIGHT, CHUNK_SIZE, CHUNK_SIZE, true]
        3: return [Vector3i(0,-1,0), Vector3i(0,1,0), Vector3i(1,0,0), Vector3i(0,0,1), WORLD_HEIGHT, CHUNK_SIZE, CHUNK_SIZE, false]
        4: return [Vector3i(0,0,1), Vector3i(0,0,1), Vector3i(1,0,0), Vector3i(0,1,0), CHUNK_SIZE, CHUNK_SIZE, WORLD_HEIGHT, true]
        _: return [Vector3i(0,0,-1), Vector3i(0,1,0), Vector3i(0,1,0), Vector3i(1,0,0), CHUNK_SIZE, WORLD_HEIGHT, CHUNK_SIZE, false]

func _material_for(id: int) -> ShaderMaterial:
    if material_cache.has(id):
        return material_cache[id]
    var material := ShaderMaterial.new()
    material.shader = atlas_shader
    material.set_shader_parameter("atlas_texture", atlas_texture)
    var tile_x := float((id - 1) % 4) * 0.25
    var tile_y := float((id - 1) / 4) * 0.25
    material.set_shader_parameter("tile_origin", Vector2(tile_x, tile_y))
    material.set_shader_parameter("tile_size", Vector2(0.25, 0.25))
    material_cache[id] = material
    return material
