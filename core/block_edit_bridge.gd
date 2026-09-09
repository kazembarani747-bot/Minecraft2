extends Node

# Real voxel editing bridge: routes interaction into WorldEngine so edits are
# stored in the voxel world and the chunk renderer can rebuild only affected chunks.
const REACH := 6.0
const AIR := 0
const BLOCK_BY_NAME := {
    "grass": 1,
    "dirt": 2,
    "stone": 3,
    "water": 4,
}
const NAME_BY_BLOCK := {
    1: "grass",
    2: "dirt",
    3: "stone",
    4: "water",
}

var player: CharacterBody3D
var camera: Camera3D
var world
var gameplay

func _ready() -> void:
    await get_tree().process_frame
    var scene := get_tree().current_scene
    if scene == null:
        return
    player = scene.get_node_or_null("Player") as CharacterBody3D
    if player:
        camera = player.get_node_or_null("Camera3D") as Camera3D
    world = get_node_or_null("/root/Minecraft2WorldEngine")
    gameplay = get_node_or_null("/root/Minecraft2GameplayUpgrade")

func _input(event: InputEvent) -> void:
    if player == null or camera == null or world == null:
        return
    if _settings_open() or _inventory_open():
        return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if _break_target():
                get_viewport().set_input_as_handled()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            if _place_target():
                get_viewport().set_input_as_handled()

func _raycast() -> Dictionary:
    var origin := camera.global_position
    var end := origin + (-camera.global_transform.basis.z * REACH)
    var query := PhysicsRayQueryParameters3D.create(origin, end)
    query.exclude = [player.get_rid()]
    query.collide_with_areas = false
    query.collide_with_bodies = true
    return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _target_cell(hit: Dictionary, place: bool) -> Vector3i:
    var point: Vector3 = hit["position"]
    var normal: Vector3 = hit["normal"]
    var sample := point + normal * (0.02 if place else -0.02)
    return Vector3i(floori(sample.x), floori(sample.y), floori(sample.z))

func _break_target() -> bool:
    var hit := _raycast()
    if hit.is_empty():
        return false
    var pos := _target_cell(hit, false)
    var id := int(world.get_block(pos))
    if id == AIR:
        return false
    if id == 4:
        return false
    var name := str(NAME_BY_BLOCK.get(id, "dirt"))
    if gameplay != null and gameplay.has_method("_add_item"):
        if not gameplay.call("_add_item", name, 1):
            return false
    world.set_block(pos, AIR)
    if gameplay != null and gameplay.has_method("_show_toast"):
        gameplay.call("_show_toast", "برداشته شد: %s ×1" % name)
    if gameplay != null and gameplay.has_method("_save_persistent_state"):
        gameplay.call("_save_persistent_state", false)
    return true

func _place_target() -> bool:
    if gameplay == null:
        return false
    var selected := int(gameplay.get("selected_slot"))
    var inventory: Array = gameplay.get("inventory")
    var counts: Array = gameplay.get("counts")
    if selected < 0 or selected >= inventory.size() or selected >= counts.size():
        return false
    if int(counts[selected]) <= 0:
        if gameplay.has_method("_show_toast"):
            gameplay.call("_show_toast", "این خانه خالی است")
        return false
    var block_name := str(inventory[selected])
    var id := int(BLOCK_BY_NAME.get(block_name, AIR))
    if id == AIR:
        return false
    var hit := _raycast()
    if hit.is_empty():
        return false
    var pos := _target_cell(hit, true)
    if int(world.get_block(pos)) != AIR:
        return false
    var center := Vector3(pos) + Vector3(0.5, 0.5, 0.5)
    if player.global_position.distance_to(center) < 1.35:
        return false
    world.set_block(pos, id)
    counts[selected] = int(counts[selected]) - 1
    gameplay.set("counts", counts)
    if gameplay.has_method("_refresh_hotbar"):
        gameplay.call("_refresh_hotbar")
    if gameplay.has_method("_refresh_inventory"):
        gameplay.call("_refresh_inventory")
    if gameplay.has_method("_show_toast"):
        gameplay.call("_show_toast", "ساخته شد: %s" % block_name)
    if gameplay.has_method("_save_persistent_state"):
        gameplay.call("_save_persistent_state", false)
    return true

func _settings_open() -> bool:
    var scene := get_tree().current_scene
    return scene != null and bool(scene.get("settings_open"))

func _inventory_open() -> bool:
    return gameplay != null and bool(gameplay.get("inventory_open"))
