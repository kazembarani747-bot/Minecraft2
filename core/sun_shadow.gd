extends Node

# Keeps the real directional sun useful at mobile-friendly distances.
func _ready() -> void:
    await get_tree().process_frame
    var scene := get_tree().current_scene
    if scene == null:
        return
    for child in scene.get_children():
        if child is DirectionalLight3D:
            child.shadow_enabled = true
            child.directional_shadow_max_distance = 96.0
            child.directional_shadow_fade_start = 0.78
            child.shadow_bias = 0.035
            child.shadow_normal_bias = 1.0
            child.distance_fade_enabled = true
            child.distance_fade_begin = 72.0
            child.distance_fade_shadow = 0.85
            break
