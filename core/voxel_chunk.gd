class_name M2VoxelChunk
extends RefCounted

const SIZE_X := 16
const SIZE_Y := 64
const SIZE_Z := 16

var origin := Vector3i.ZERO
var blocks: PackedInt32Array
var dirty := true

func _init(chunk_origin: Vector3i = Vector3i.ZERO) -> void:
    origin = chunk_origin
    blocks.resize(SIZE_X * SIZE_Y * SIZE_Z)
    blocks.fill(0)

func _index(x: int, y: int, z: int) -> int:
    return x + SIZE_X * (z + SIZE_Z * y)

func in_bounds(x: int, y: int, z: int) -> bool:
    return x >= 0 and x < SIZE_X and y >= 0 and y < SIZE_Y and z >= 0 and z < SIZE_Z

func get_block(x: int, y: int, z: int) -> int:
    if not in_bounds(x, y, z):
        return 0
    return blocks[_index(x, y, z)]

func set_block(x: int, y: int, z: int, block_id: int) -> void:
    if not in_bounds(x, y, z):
        return
    blocks[_index(x, y, z)] = block_id
    dirty = true

func fill_column(x: int, z: int, height: int, top_id := 1, filler_id := 2) -> void:
    var h: int = clampi(height, 0, SIZE_Y)
    for y in range(h):
        set_block(x, y, z, top_id if y == h - 1 else filler_id)

func build_test_terrain() -> void:
    for x in range(SIZE_X):
        for z in range(SIZE_Z):
            var wave: float = sin(float(x) * 0.55) + cos(float(z) * 0.47)
            var height: int = 5 + int((wave + 2.0) * 2.0)
            fill_column(x, z, height)
    dirty = true

# Returns only exposed cube faces. This is the first real voxel-meshing layer;
# the renderer can later replace these quads with a greedy-meshed surface.
func exposed_faces() -> Array[Dictionary]:
    var faces: Array[Dictionary] = []
    var directions := [
        Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
        Vector3i(0, 1, 0), Vector3i(0, -1, 0),
        Vector3i(0, 0, 1), Vector3i(0, 0, -1)
    ]
    for x in range(SIZE_X):
        for y in range(SIZE_Y):
            for z in range(SIZE_Z):
                var block_id: int = get_block(x, y, z)
                if block_id == 0:
                    continue
                for direction in directions:
                    var nx: int = x + direction.x
                    var ny: int = y + direction.y
                    var nz: int = z + direction.z
                    if not in_bounds(nx, ny, nz) or get_block(nx, ny, nz) == 0:
                        faces.append({"position": Vector3i(x, y, z), "normal": direction, "block": block_id})
    return faces
