class_name M2VoxelMesher
extends RefCounted

# Builds only visible cube faces. Textures are intentionally left to the
# original Minecraft2 atlas pipeline so no third-party game assets are copied.
const FACE_VERTICES := [
    [Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(1,0,1)],
    [Vector3(0,0,1), Vector3(0,1,1), Vector3(0,1,0), Vector3(0,0,0)],
    [Vector3(0,1,0), Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0)],
    [Vector3(0,0,1), Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1)],
    [Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1), Vector3(0,0,1)],
    [Vector3(0,0,0), Vector3(0,1,0), Vector3(1,1,0), Vector3(1,0,0)]
]
const FACE_NORMALS := [
    Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
]
const UVS := [Vector2(0,1), Vector2(0,0), Vector2(1,0), Vector2(1,1)]

func build_chunk_mesh(chunk: M2VoxelChunk) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var face_index := 0

    for face in chunk.exposed_faces():
        var normal: Vector3 = face["normal"]
        var face_id := _face_index(normal)
        var base := vertices.size()
        var p: Vector3i = face["position"]
        for i in range(4):
            vertices.append(Vector3(p) + FACE_VERTICES[face_id][i])
            normals.append(normal)
            uvs.append(UVS[i])
        indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
        face_index += 1

    if vertices.is_empty():
        return ArrayMesh.new()

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _face_index(normal: Vector3) -> int:
    for i in range(FACE_NORMALS.size()):
        if FACE_NORMALS[i].is_equal_approx(normal):
            return i
    return 0
