class_name Minecraft2FeatureRegistry
extends RefCounted

const VERSION := "1.0.0"

var features: Dictionary = {}

func bootstrap() -> void:
    register_feature("physics.gravity", true, "World gravity and vertical physics")
    register_feature("graphics.pbr", true, "Higher-fidelity material pipeline")
    register_feature("graphics.post_process", true, "Optional post-processing effects")
    register_feature("graphics.dynamic_lighting", true, "Dynamic light support")
    register_feature("animation.player_motion", true, "Player motion and camera animation")
    register_feature("audio.spatial", true, "3D positional audio")
    register_feature("audio.music", true, "Context-aware background music")
    register_feature("commands.extended", true, "Extended slash-command system")
    register_feature("ai.assistant", true, "In-game AI assistant integration point")
    register_feature("ai.mod_builder", true, "AI-assisted mod/project generation")
    register_feature("mods.java_bridge", false, "Java mod compatibility bridge")
    register_feature("network.java", false, "Java server protocol adapter")
    register_feature("network.bedrock", false, "Bedrock server protocol adapter")
    register_feature("network.crossplay", false, "Crossplay session layer")

func register_feature(id: String, ready: bool, description: String) -> void:
    features[id] = {
        "ready": ready,
        "description": description,
        "version": VERSION
    }

func is_ready(id: String) -> bool:
    return bool(features.get(id, {}).get("ready", false))

func report() -> Dictionary:
    return features.duplicate(true)
