class_name Minecraft2BlockRegistry
extends RefCounted

const TEXTURE_SIZE := 16
var blocks: Dictionary = {}

func register(identifier: String, definition: Dictionary = {}) -> bool:
    if identifier.is_empty() or blocks.has(identifier):
        return false
    var data := definition.duplicate(true)
    data["texture_size"] = TEXTURE_SIZE
    data["id"] = identifier
    blocks[identifier] = data
    return true

func exists(identifier: String) -> bool:
    return blocks.has(identifier)

func get_definition(identifier: String) -> Dictionary:
    return blocks.get(identifier, {}).duplicate(true)

func get_all() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in blocks.values():
        result.append(value.duplicate(true))
    return result
