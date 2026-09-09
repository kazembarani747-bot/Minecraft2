extends Node

# Lightweight water interaction for the CharacterBody3D player. Water remains
# non-solid like a voxel game should be, while movement/gravity are damped and
# upward buoyancy is applied when the player is submerged.
const WATER_ID := 4
const SAMPLE_OFFSETS := [Vector3(0, 0.15, 0), Vector3(0, 0.9, 0)]
const WATER_DRAG := 0.62
const SWIM_UP_ACCEL := 8.0
const MAX_WATER_FALL_SPEED := -2.2

var player: CharacterBody3D
var world
var in_water := false

func _ready() -> void:
    await get_tree().process_frame
    var scene := get_tree().current_scene
    if scene != null:
        player = scene.get_node_or_null("Player") as CharacterBody3D
    world = get_node_or_null("/root/Minecraft2WorldEngine")

func _physics_process(delta: float) -> void:
    if player == null or world == null:
        return
    var submerged := _is_water_at_player()
    in_water = submerged
    if not submerged:
        return
    player.velocity.x *= pow(WATER_DRAG, delta * 10.0)
    player.velocity.z *= pow(WATER_DRAG, delta * 10.0)
    player.velocity.y = maxf(player.velocity.y, MAX_WATER_FALL_SPEED)
    if Input.is_action_pressed("jump"):
        player.velocity.y = minf(player.velocity.y + SWIM_UP_ACCEL * delta, 4.5)

func _is_water_at_player() -> bool:
    for offset in SAMPLE_OFFSETS:
        var p := player.global_position + offset
        var cell := Vector3i(floori(p.x), floori(p.y), floori(p.z))
        if int(world.get_block(cell)) == WATER_ID:
            return true
    return false
