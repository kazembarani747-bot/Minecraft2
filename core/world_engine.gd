extends Node

# Minecraft2 World Engine v1: deterministic infinite-ish chunk streaming,
# persistent block edits, chunk lifecycle and world diagnostics.
const CHUNK_SIZE := 16
const WORLD_HEIGHT := 64
const STREAM_RADIUS := 4
const UNLOAD_RADIUS := 6
const WORLD_SEED := 20260908
const SAVE_PATH := "user://Minecraft2/worlds/world_engine.json"
const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3
const BLOCK_WATER := 4

signal chunk_loaded(cx: int, cz: int)
signal chunk_unloaded(cx: int, cz: int)
signal block_changed(position: Vector3i, old_id: int, new_id: int)

var world_seed := WORLD_SEED
var chunks: Dictionary = {}
var dirty_chunks: Dictionary = {}
var block_overrides: Dictionary = {}
var player: Node3D
var stream_timer := 0.0
var save_timer := 0.0
var diagnostic_label: Label

func _ready() -> void:
    _load_world_state()
    await get_tree().process_frame
    _find_player()
    _build_diagnostics()
    _stream_now()

func _process(delta: float) -> void:
    if player == null:
        _find_player()
        return
    stream_timer += delta
    save_timer += delta
    if stream_timer >= 0.5:
        stream_timer = 0.0
        _stream_now()
    if save_timer >= 20.0:
        save_timer = 0.0
        save_world()
    _update_diagnostics()

func _find_player() -> void:
    var scene := get_tree().current_scene
    if scene:
        player = scene.get_node_or_null("Player") as Node3D

func world_to_chunk(value: int) -> int:
    return floori(float(value) / CHUNK_SIZE)

func world_to_local(value: int) -> int:
    return posmod(value, CHUNK_SIZE)

func chunk_key(cx: int, cz: int) -> String:
    return "%d:%d" % [cx, cz]

func _stream_now() -> void:
    if player == null:
        return
    var center_cx := world_to_chunk(floori(player.global_position.x))
    var center_cz := world_to_chunk(floori(player.global_position.z))
    for dz in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
        for dx in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
            if dx * dx + dz * dz <= STREAM_RADIUS * STREAM_RADIUS:
                _ensure_chunk(center_cx + dx, center_cz + dz)

    var to_unload: Array[String] = []
    for key in chunks.keys():
        var parts := str(key).split(":")
        if parts.size() != 2:
            continue
        var cx := int(parts[0])
        var cz := int(parts[1])
        if abs(cx - center_cx) > UNLOAD_RADIUS or abs(cz - center_cz) > UNLOAD_RADIUS:
            to_unload.append(str(key))
    for key in to_unload:
        _unload_chunk(key)

func _ensure_chunk(cx: int, cz: int) -> Dictionary:
    var key := chunk_key(cx, cz)
    if chunks.has(key):
        return chunks[key]
    var chunk := _generate_chunk(cx, cz)
    chunks[key] = chunk
    chunk_loaded.emit(cx, cz)
    return chunk

func _generate_chunk(cx: int, cz: int) -> Dictionary:
    var blocks := PackedInt32Array()
    blocks.resize(CHUNK_SIZE * WORLD_HEIGHT * CHUNK_SIZE)
    blocks.fill(BLOCK_AIR)
    for lx in range(CHUNK_SIZE):
        for lz in range(CHUNK_SIZE):
            var wx := cx * CHUNK_SIZE + lx
            var wz := cz * CHUNK_SIZE + lz
            var h := _terrain_height(wx, wz)
            for y in range(h):
                var id := BLOCK_STONE
                if y >= h - 3:
                    id = BLOCK_DIRT
                if y == h - 1:
                    id = BLOCK_GRASS
                blocks[_index(lx, y, lz)] = id
            if h < 4:
                for y in range(h, 4):
                    blocks[_index(lx, y, lz)] = BLOCK_WATER
    var chunk := {"cx": cx, "cz": cz, "blocks": blocks, "dirty": false}
    _apply_overrides_to_chunk(chunk)
    return chunk

func _terrain_height(wx: int, wz: int) -> int:
    var a := sin(float(wx + world_seed % 997) * 0.035) * 5.0
    var b := cos(float(wz - world_seed % 613) * 0.041) * 5.0
    var c := sin(float(wx + wz) * 0.018) * 4.0
    return clampi(12 + int(a + b + c), 3, WORLD_HEIGHT - 1)

func _index(x: int, y: int, z: int) -> int:
    return x + CHUNK_SIZE * (z + CHUNK_SIZE * y)

func _override_key(pos: Vector3i) -> String:
    return "%d,%d,%d" % [pos.x, pos.y, pos.z]

func _apply_overrides_to_chunk(chunk: Dictionary) -> void:
    var blocks: PackedInt32Array = chunk["blocks"]
    var cx: int = chunk["cx"]
    var cz: int = chunk["cz"]
    for key in block_overrides.keys():
        var parts := str(key).split(",")
        if parts.size() != 3:
            continue
        var pos := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
        if world_to_chunk(pos.x) != cx or world_to_chunk(pos.z) != cz:
            continue
        if pos.y < 0 or pos.y >= WORLD_HEIGHT:
            continue
        blocks[_index(world_to_local(pos.x), pos.y, world_to_local(pos.z))] = int(block_overrides[key])
    chunk["blocks"] = blocks

func get_block(pos: Vector3i) -> int:
    if pos.y < 0 or pos.y >= WORLD_HEIGHT:
        return BLOCK_AIR
    var chunk := _ensure_chunk(world_to_chunk(pos.x), world_to_chunk(pos.z))
    var blocks: PackedInt32Array = chunk["blocks"]
    return blocks[_index(world_to_local(pos.x), pos.y, world_to_local(pos.z))]

func set_block(pos: Vector3i, block_id: int) -> void:
    if pos.y < 0 or pos.y >= WORLD_HEIGHT:
        return
    var old_id := get_block(pos)
    if old_id == block_id:
        return
    var chunk_key_value := chunk_key(world_to_chunk(pos.x), world_to_chunk(pos.z))
    var chunk := _ensure_chunk(world_to_chunk(pos.x), world_to_chunk(pos.z))
    var blocks: PackedInt32Array = chunk["blocks"]
    blocks[_index(world_to_local(pos.x), pos.y, world_to_local(pos.z))] = block_id
    chunk["blocks"] = blocks
    chunk["dirty"] = true
    chunks[chunk_key_value] = chunk
    block_overrides[_override_key(pos)] = block_id
    dirty_chunks[chunk_key_value] = true
    block_changed.emit(pos, old_id, block_id)

func _unload_chunk(key: String) -> void:
    if not chunks.has(key):
        return
    if dirty_chunks.has(key):
        save_world()
    var chunk: Dictionary = chunks[key]
    chunks.erase(key)
    dirty_chunks.erase(key)
    chunk_unloaded.emit(int(chunk["cx"]), int(chunk["cz"]))

func loaded_chunk_count() -> int:
    return chunks.size()

func loaded_block_count() -> int:
    return chunks.size() * CHUNK_SIZE * WORLD_HEIGHT * CHUNK_SIZE

func save_world() -> bool:
    DirAccess.make_dir_recursive_absolute("user://Minecraft2/worlds")
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    var payload := {
        "version": 1,
        "seed": world_seed,
        "overrides": block_overrides,
        "saved_at": Time.get_datetime_string_from_system(true)
    }
    file.store_string(JSON.stringify(payload))
    file.close()
    dirty_chunks.clear()
    return true

func _load_world_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != 1:
        return
    world_seed = int(parsed.get("seed", WORLD_SEED))
    var saved_overrides = parsed.get("overrides", {})
    if typeof(saved_overrides) == TYPE_DICTIONARY:
        block_overrides = saved_overrides.duplicate(true)

func _build_diagnostics() -> void:
    var layer := CanvasLayer.new()
    layer.name = "WorldEngineHUD"
    add_child(layer)
    diagnostic_label = Label.new()
    diagnostic_label.position = Vector2(28, 675)
    diagnostic_label.add_theme_font_size_override("font_size", 13)
    diagnostic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(diagnostic_label)

func _update_diagnostics() -> void:
    if diagnostic_label == null:
        return
    diagnostic_label.text = "WORLD ENGINE • Seed %d • Chunks %d • Streaming R%d • Saved edits %d" % [world_seed, loaded_chunk_count(), STREAM_RADIUS, block_overrides.size()]
