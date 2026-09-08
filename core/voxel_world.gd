class_name M2VoxelWorld
extends RefCounted

const CHUNK_SIZE := 16
var chunks: Dictionary = {}
var seed := 0

func _init(world_seed: int = 20260908) -> void:
    seed = world_seed

func _key(cx: int, cz: int) -> String:
    return str(cx) + ":" + str(cz)

func get_chunk(cx: int, cz: int) -> M2VoxelChunk:
    var key := _key(cx, cz)
    if not chunks.has(key):
        var chunk := M2VoxelChunk.new(Vector3i(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE))
        chunk.build_test_terrain()
        chunks[key] = chunk
    return chunks[key]

func set_block(world_pos: Vector3i, block_id: int) -> void:
    var cx := floori(float(world_pos.x) / CHUNK_SIZE)
    var cz := floori(float(world_pos.z) / CHUNK_SIZE)
    var lx := posmod(world_pos.x, CHUNK_SIZE)
    var lz := posmod(world_pos.z, CHUNK_SIZE)
    get_chunk(cx, cz).set_block(lx, world_pos.y, lz, block_id)

func get_block(world_pos: Vector3i) -> int:
    if world_pos.y < 0 or world_pos.y >= M2VoxelChunk.SIZE_Y:
        return 0
    var cx := floori(float(world_pos.x) / CHUNK_SIZE)
    var cz := floori(float(world_pos.z) / CHUNK_SIZE)
    var lx := posmod(world_pos.x, CHUNK_SIZE)
    var lz := posmod(world_pos.z, CHUNK_SIZE)
    return get_chunk(cx, cz).get_block(lx, world_pos.y, lz)

func loaded_chunk_count() -> int:
    return chunks.size()

func clear() -> void:
    chunks.clear()
