extends Node

# Minecraft2 atmosphere pass: lightweight mobile-safe depth fog and tone setup.
const START_DELAY := 0.25

func _ready() -> void:
    await get_tree().create_timer(START_DELAY).timeout
    var scene := get_tree().current_scene
    if scene == null:
        return
    var env_node := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if env_node == null or env_node.environment == null:
        return
    var env := env_node.environment
    env.background_mode = Environment.BG_COLOR
    env.fog_enabled = true
    env.fog_light_color = Color(0.70, 0.80, 0.92)
    env.fog_light_energy = 0.75
    env.fog_density = 0.012
    env.fog_height = 5.0
    env.fog_height_density = 0.018
    env.fog_aerial_perspective = 0.45
    env.fog_sky_affect = 0.35
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.05
    env.tonemap_white = 1.1
