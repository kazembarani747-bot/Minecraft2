extends Node

# Minecraft2 chunk renderer: greedy meshing + atlas + AO + skylight,
# transparent water and a bounded build queue for stable mobile frame times.
const CHUNK_SIZE := 16
const WORLD_HEIGHT := 64
const RENDER_RADIUS := 3
const UPDATE_SECONDS := 0.35
const MAX_CHUNKS_PER_FRAME := 2
const ATLAS_PATH := "res://assets/textures/minecraft2_atlas.svg"
const SHADER_PATH := "res://core/voxel_atlas.gdshader"
const WATER_SHADER_PATH := "res://core/water_surface.gdshader"

var world
var player: Node3D
var root: Node3D
var rendered: Dictionary = {}
var timer := 0.0
var atlas_texture: Texture2D
var atlas_shader: Shader
var water_shader: Shader
var material_cache: Dictionary = {}
var dirty_render_chunks: Dictionary = {}
var build_queue: Array[String] = []
var queued: Dictionary = {}
var queue_head := 0
var water_material: ShaderMaterial

func _ready() -> void:
    world = get_node_or_null("/root/Minecraft2WorldEngine")
    atlas_texture = load(ATLAS_PATH) as Texture2D
    atlas_shader = load(SHADER_PATH) as Shader
    water_shader = load(WATER_SHADER_PATH) as Shader
    await get_tree().process_frame
    var scene := get_tree().current_scene
    if scene != null:
        player = scene.get_node_or_null("Player") as Node3D
    if world == null or player == null or atlas_texture == null or atlas_shader == null or water_shader == null:
        return
    if world.has_signal("block_changed"):
        world.block_changed.connect(_on_block_changed)
    if world.has_signal("lighting_changed"):
        world.lighting_changed.connect(_on_lighting_changed)
    root = Node3D.new()
    root.name = "VoxelChunkRenderRoot"
    scene.add_child(root)
    _remove_legacy_blocks()
    _sync_chunks()

func _process(delta: float) -> void:
    if world == null or player == null:
        return
    timer += delta
    if timer >= UPDATE_SECONDS:
        timer = 0.0
        _sync_chunks()
    _process_build_queue()
    if water_material != null:
        water_material.set_shader_parameter("time_seconds", Time.get_ticks_msec() / 1000.0)

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
    _queue_dirty(world.chunk_key(cx, cz))
    if posmod(position.x, CHUNK_SIZE) == 0:
        _queue_dirty(world.chunk_key(cx - 1, cz))
    elif posmod(position.x, CHUNK_SIZE) == CHUNK_SIZE - 1:
        _queue_dirty(world.chunk_key(cx + 1, cz))
    if posmod(position.z, CHUNK_SIZE) == 0:
        _queue_dirty(world.chunk_key(cx, cz - 1))
    elif posmod(position.z, CHUNK_SIZE) == CHUNK_SIZE - 1:
        _queue_dirty(world.chunk_key(cx, cz + 1))

func _queue_dirty(key: String) -> void:
    dirty_render_chunks[key] = true

func _queue_build(key: String) -> void:
    if queued.has(key):
        return
    queued[key] = true
    build_queue.append(key)

func _process_build_queue() -> void:
    var built := 0
    while built < MAX_CHUNKS_PER_FRAME and queue_head < build_queue.size():
        var key := build_queue[queue_head]
        queue_head += 1
        queued.erase(key)
        if not world.chunks.has(key):
            continue
        var parts := key.split(":")
        if parts.size() != 2:
            continue
        var cx := int(parts[0])
        var cz := int(parts[1])
        var center := Vector2i(floori(player.global_position.x / CHUNK_SIZE), floori(player.global_position.z / CHUNK_SIZE))
        if abs(cx - center.x) > RENDER_RADIUS or abs(cz - center.y) > RENDER_RADIUS:
            continue
        if rendered.has(key):
            rendered[key].queue_free()
            rendered.erase(key)
        dirty_render_chunks.erase(key)
        _render_chunk(cx, cz)
        built += 1
    if queue_head > 64 and queue_head * 2 > build_queue.size():
        build_queue = build_queue.slice(queue_head)
        queue_head = 0

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
            if dirty_render_chunks.has(key) or not rendered.has(key):
                _queue_build(str(key))
    var remove_keys: Array[String] = []
    for key in rendered.keys():
        if not needed.has(key):
            remove_keys.append(str(key))
    for key in remove_keys:
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
        mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if int(id) != 4 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.add_child(mesh_instance)
        face_count += int(data["faces"])

    if face_count == 0:
        node.queue_free()
        return

    var collision_data: PackedVector3Array = buckets["__collision"]
    if not collision_data.is_empty():
        var body := StaticBody3D.new()
        body.name = "Collision"
        var shape := CollisionShape3D.new()
        var concave := ConcavePolygonShape3D.new()
        concave.data = collision_data
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
                    var id: int = int(world.get_block(world_pos))
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
                    if id != 4:
                        _emit_collision(buckets["__collision"], origin, du, dv)
                    u += width
                v += 1
    return buckets

func _ensure_bucket(buckets: Dictionary, id: int) -> void:
    if buckets.has(id):
        return
    buckets[id] = {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array(), "faces": 0}

func _emit_quad(data: Dictionary, origin: Vector3, du: Vector3, dv: Vector3, normal: Vector3, width: int, height: int, world_origin: Vector3i) -> void:
    var vertices: PackedVector3Array = data["vertices"]
    var normals: PackedVector3Array = data["normals"]
    var uvs: PackedVector2Array = data["uvs"]
    var colors: PackedColorArray = data["colors"]
    var indices: PackedInt32Array = data["indices"]
    var base := vertices.size()
    vertices.append(origin); vertices.append(origin + du); vertices.append(origin + du + dv); vertices.append(origin + dv)
    for i in range(4):
        normals.append(normal)
    uvs.append(Vector2(0, 0)); uvs.append(Vector2(width, 0)); uvs.append(Vector2(width, height)); uvs.append(Vector2(0, height))
    var a0 := _corner_ao(world_origin, normal, du, dv, 0.0, 0.0)
    var a1 := _corner_ao(world_origin, normal, du, dv, 1.0, 0.0)
    var a2 := _corner_ao(world_origin, normal, du, dv, 1.0, 1.0)
    var a3 := _corner_ao(world_origin, normal, du, dv, 0.0, 1.0)
    var light := (_corner_light(world_origin) + _corner_light(world_origin + _axis_step(du, width)) + _corner_light(world_origin + _axis_step(dv, height)) + _corner_light(world_origin + _axis_step(du, width) + _axis_step(dv, height))) * 0.25
    colors.append(Color(a0, light, 1.0, 1.0)); colors.append(Color(a1, light, 1.0, 1.0)); colors.append(Color(a2, light, 1.0, 1.0)); colors.append(Color(a3, light, 1.0, 1.0))
    indices.append(base); indices.append(base + 1); indices.append(base + 2); indices.append(base); indices.append(base + 2); indices.append(base + 3)
    data["vertices"] = vertices; data["normals"] = normals; data["uvs"] = uvs; data["colors"] = colors; data["indices"] = indices; data["faces"] = int(data["faces"]) + 1

func _axis_step(vec: Vector3, amount: int) -> Vector3i:
    return Vector3i(roundi(vec.normalized().x), roundi(vec.normalized().y), roundi(vec.normalized().z)) * amount

func _corner_light(pos: Vector3i) -> float:
    if world.has_method("get_light_factor"):
        return world.get_light_factor(pos)
    return 1.0

func _corner_ao(origin: Vector3i, normal: Vector3, du: Vector3, dv: Vector3, u_side: float, v_side: float) -> float:
    var face_axis_u := Vector3i(roundi(du.normalized().x), roundi(du.normalized().y), roundi(du.normalized().z))
    var face_axis_v := Vector3i(roundi(dv.normalized().x), roundi(dv.normalized().y), roundi(dv.normalized().z))
    var corner := origin
    if u_side > 0.5: corner += face_axis_u * max(1, int(abs(du.length())))
    if v_side > 0.5: corner += face_axis_v * max(1, int(abs(dv.length())))
    var side_u := face_axis_u if u_side < 0.5 else -face_axis_u
    var side_v := face_axis_v if v_side < 0.5 else -face_axis_v
    var n := Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
    var p := corner + n
    var s1: bool = world.get_block(p + side_u) != 0
    var s2: bool = world.get_block(p + side_v) != 0
    var diag: bool = world.get_block(p + side_u + side_v) != 0
    var occlusion := 3 if s1 and s2 else int(s1) + int(s2) + int(diag)
    return 1.0 - float(occlusion) / 4.0

func _emit_collision(data: PackedVector3Array, origin: Vector3, du: Vector3, dv: Vector3) -> void:
    data.append(origin); data.append(origin + du); data.append(origin + du + dv); data.append(origin); data.append(origin + du + dv); data.append(origin + dv)

func _face_config(normal_id: int) -> Array:
    match normal_id:
        0: return [Vector3i(1,0,0), Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1), CHUNK_SIZE, WORLD_HEIGHT, CHUNK_SIZE, true]
        1: return [Vector3i(-1,0,0), Vector3i(1,0,0), Vector3i(0,0,1), Vector3i(0,1,0), CHUNK_SIZE, CHUNK_SIZE, WORLD_HEIGHT, false]
        2: return [Vector3i(0,1,0), Vector3i(0,1,0), Vector3i(0,0,1), Vector3i(1,0,0), WORLD_HEIGHT, CHUNK_SIZE, CHUNK_SIZE, true]
        3: return [Vector3i(0,-1,0), Vector3i(0,1,0), Vector3i(1,0,0), Vector3i(0,0,1), WORLD_HEIGHT, CHUNK_SIZE, CHUNK_SIZE, false]
        4: return [Vector3i(0,0,1), Vector3i(0,0,1), Vector3i(1,0,0), Vector3i(0,1,0), CHUNK_SIZE, CHUNK_SIZE, WORLD_HEIGHT, true]
        _: return [Vector3i(0,0,-1), Vector3i(0,0,1), Vector3i(0,1,0), Vector3i(1,0,0), CHUNK_SIZE, WORLD_HEIGHT, CHUNK_SIZE, false]

func _material_for(id: int) -> ShaderMaterial:
    if id == 4:
        if water_material == null:
            water_material = ShaderMaterial.new()
            water_material.shader = water_shader
            water_material.set_shader_parameter("atlas_texture", atlas_texture)
            water_material.set_shader_parameter("tile_origin", Vector2(0.75, 0.0))
            water_material.set_shader_parameter("tile_size", Vector2(0.25, 0.25))
        return water_material
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
