class_name Minecraft2BlockDefinition
extends RefCounted

const TEXTURE_SIZE := 16

var identifier: String
var solid: bool
var transparent: bool
var hardness: float
var textures: Dictionary

func _init(id: String, data: Dictionary = {}) -> void:
    identifier = id
    solid = bool(data.get("solid", true))
    transparent = bool(data.get("transparent", false))
    hardness = float(data.get("hardness", 1.0))
    textures = data.get("textures", {}).duplicate(true)

func to_dict() -> Dictionary:
    return {
        "identifier": identifier,
        "solid": solid,
        "transparent": transparent,
        "hardness": hardness,
        "texture_size": TEXTURE_SIZE,
        "textures": textures.duplicate(true)
    }
