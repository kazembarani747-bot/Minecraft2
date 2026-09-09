extends Node

# Chunk renderer: converts World Engine voxel data into one mesh per chunk.
# It deliberately uses original procedural materials rather than Minecraft assets.
const CHUNK_SIZE := 16
const WORLD_HEIGHT := 64
const RENDER_RADIUS := 4
const UPDATE_SECONDS := 0.5

var world
var player: Node3D
var root: Node3D
var rendered: Dictionary = {}
var timer := 0.0

func _ready() -> void:
    world = get_node_or_null("/root/Minecraft2WorldEngine")
    await get_tree().process_frame
    player = get_tree().current_scene.get_node_or_null("Player") as Node3D
    if world == null or player == null:
        return
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

func _sync_chunks() -> void:
    var center := Vector2i(floori(player.global_position.x / CHUNK_SIZE), floori(player.global_position.z / CHUNK_SIZE))
    world._stream_now()
    var needed := {}
    for key in world.chunks.keys():
        var parts := str(key).split(":")
        if parts.size() != 2:
            continue
        var cx := int(parts[0])
        var cz := int(parts[1])
        if abs(cx - center.x) <= RENDER_RADIUS and abs(cz - center.y) <= RENDER_RADIUS:
            needed[key] = true
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

    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_material(_material_for(1))
    var face_count := 0
    for lx in range(CHUNK_SIZE):
        for y in range(WORLD_HEIGHT):
            for lz in range(CHUNK_SIZE):
                var id := world.get_block(Vector3i(cx * CHUNK_SIZE + lx, y, cz * CHUNK_SIZE + lz))
                if id == 0:
                    continue
                for face in _faces_for(Vector3i(lx, y, lz), cx, cz):
                    st.set_material(_material_for(id))
                    _add_face(st, Vector3(lx, y, lz), face)
                    face_count += 1
    if face_count == 0:
        node.queue_free()
        return
    var mesh := st.commit()
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    node.add_child(mesh_instance)

    # One static collision body per chunk keeps physics independent from visual cubes.
    var body := StaticBody3D.new()
    body.name = "Collision"
    var shape := CollisionShape3D.new()
    var concave := ConcavePolygonShape3D.new()
    concave.data = _collision_faces(cx, cz)
    shape.shape = concave
    body.add_child(shape)
    node.add_child(body)
    rendered[world.chunk_key(cx, cz)] = node

func _faces_for(local: Vector3i, cx: int, cz: int) -> Array:
    var world_pos := Vector3i(cx * CHUNK_SIZE + local.x, local.y, cz * CHUNK_SIZE + local.z)
    var result: Array = []
    var dirs := [
        Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
        Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)
    ]
    for d in dirs:
        if world.get_block(world_pos + d) == 0:
            result.append(d)
    return result

func _add_face(st: SurfaceTool, p: Vector3, normal: Vector3i) -> void:
    var corners := _face_corners(p, normal)
    var n := Vector3(normal)
    st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(corners[0])
    st.set_normal(n); st.set_uv(Vector2(1, 0)); st.add_vertex(corners[1])
    st.set_normal(n); st.set_uv(Vector2(1, 1)); st.add_vertex(corners[2])
    st.set_normal(n); st.set_uv(Vector2(0, 0)); st.add_vertex(corners[0])
    st.set_normal(n); st.set_uv(Vector2(1, 1)); st.add_vertex(corners[2])
    st.set_normal(n); st.set_uv(Vector2(0, 1)); st.add_vertex(corners[3])

func _face_corners(p: Vector3, n: Vector3i) -> Array:
    var x := p.x; var y := p.y; var z := p.z
    if n == Vector3i(1, 0, 0): return [Vector3(x+1,y,z),Vector3(x+1,y+1,z),Vector3(x+1,y+1,z+1),Vector3(x+1,y,z+1)]
    if n == Vector3i(-1, 0, 0): return [Vector3(x,y,z+1),Vector3(x,y+1,z+1),Vector3(x,y+1,z),Vector3(x,y,z)]
    if n == Vector3i(0, 1, 0): return [Vector3(x,y+1,z),Vector3(x,y+1,z+1),Vector3(x+1,y+1,z+1),Vector3(x+1,y+1,z)]
    if n == Vector3i(0, -1, 0): return [Vector3(x,y,z+1),Vector3(x,y,z),Vector3(x+1,y,z),Vector3(x+1,y,z+1)]
    if n == Vector3i(0, 0, 1): return [Vector3(x+1,y,z+1),Vector3(x+1,y+1,z+1),Vector3(x,y+1,z+1),Vector3(x,y,z+1)]
    return [Vector3(x,y,z),Vector3(x,y+1,z),Vector3(x+1,y+1,z),Vector3(x+1,y,z)]

func _collision_faces(cx: int, cz: int) -> PackedVector3Array:
    var data := PackedVector3Array()
    for lx in range(CHUNK_SIZE):
        for y in range(WORLD_HEIGHT):
            for lz in range(CHUNK_SIZE):
                var pos := Vector3i(cx * CHUNK_SIZE + lx, y, cz * CHUNK_SIZE + lz)
                if world.get_block(pos) == 0:
                    continue
                for face in _faces_for(Vector3i(lx, y, lz), cx, cz):
                    var c := _face_corners(Vector3(lx, y, lz), face)
                    for v in c:
                        data.append(v + Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE))
                    data.append(c[0] + Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE))
                    data.append(c[2] + Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE))
    return data

func _material_for(id: int) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.roughness = 1.0
    if id == 1: m.albedo_color = Color(0.25, 0.65, 0.18)
    elif id == 2: m.albedo_color = Color(0.40, 0.25, 0.12)
    elif id == 3: m.albedo_color = Color(0.43, 0.45, 0.48)
    elif id == 4:
        m.albedo_color = Color(0.20, 0.45, 0.85, 0.72)
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    else: m.albedo_color = Color(1, 1, 1)
    return m
