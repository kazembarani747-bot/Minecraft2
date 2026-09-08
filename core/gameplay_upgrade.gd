extends Node

# Minecraft2 gameplay layer: interaction and survival UX stay modular so the
# renderer/world implementation can evolve without rewriting the UI.
const REACH := 6.0
const HOTBAR_SIZE := 9
const MAX_HEALTH := 20.0
const MAX_HUNGER := 20.0

var scene: Node3D
var player: CharacterBody3D
var camera: Camera3D
var hotbar: HBoxContainer
var status: Label
var toast: Label
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var selected_slot := 0
var health := MAX_HEALTH
var hunger := MAX_HUNGER
var world_time := 0.0
var inventory := ["grass", "dirt", "stone", "wood", "glass", "sand", "brick", "lamp", "blue_crystal"]
var counts := [32, 32, 64, 16, 16, 32, 16, 8, 4]

func _ready() -> void:
    await get_tree().process_frame
    scene = get_tree().current_scene as Node3D
    if scene == null:
        return
    player = scene.get_node_or_null("Player") as CharacterBody3D
    if player:
        camera = player.get_node_or_null("Camera3D") as Camera3D
    _build_survival_hud()
    _build_hotbar()
    _build_touch_actions()
    _show_toast("ماینکرافت۲: ساخت‌وساز و تعامل فعال شد")

func _process(delta: float) -> void:
    if scene == null or player == null:
        return
    world_time = fmod(world_time + delta * 0.7, 240.0)
    _update_day_cycle()
    _update_survival(delta)
    _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if scene == null or scene.get("settings_open"):
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode >= KEY_1 and event.keycode <= KEY_9:
            _select_slot(event.keycode - KEY_1)
        elif event.keycode == KEY_Q:
            _drop_selected()
        elif event.keycode == KEY_E:
            _eat_selected()
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _break_target()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _place_target()

func _raycast() -> Dictionary:
    if camera == null:
        return {}
    var origin := camera.global_position
    var end := origin + (-camera.global_transform.basis.z * REACH)
    var query := PhysicsRayQueryParameters3D.create(origin, end)
    query.exclude = [player.get_rid()]
    query.collide_with_areas = false
    query.collide_with_bodies = true
    return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _break_target() -> void:
    var hit := _raycast()
    if hit.is_empty():
        return
    var body := hit["collider"] as Node
    if body == null or body == player:
        return
    var block_name := str(body.name)
    if not ["grass", "dirt", "stone", "wood", "glass", "sand", "brick", "lamp", "blue_crystal"].has(block_name):
        return
    var slot := inventory.find(block_name)
    if slot < 0:
        slot = selected_slot
    counts[slot] += 1
    body.queue_free()
    _show_toast("برداشته شد: %s ×1" % _fa_block_name(block_name))

func _place_target() -> void:
    if counts[selected_slot] <= 0:
        _show_toast("این خانه خالی است")
        return
    var hit := _raycast()
    if hit.is_empty():
        return
    var point: Vector3 = hit["position"]
    var normal: Vector3 = hit["normal"]
    var cell := Vector3(round(point.x + normal.x * 0.51), round(point.y + normal.y * 0.51), round(point.z + normal.z * 0.51))
    if player.global_position.distance_to(cell + Vector3(0.5, 0.5, 0.5)) < 1.35:
        return
    var block_name: String = inventory[selected_slot]
    var color := _block_color(block_name)
    if scene.has_method("_block"):
        scene.call("_block", cell, color, block_name)
        counts[selected_slot] -= 1
        _show_toast("ساخته شد: %s" % _fa_block_name(block_name))

func _drop_selected() -> void:
    if counts[selected_slot] > 0:
        counts[selected_slot] -= 1
        _show_toast("یک آیتم روی زمین افتاد")

func _eat_selected() -> void:
    if counts[selected_slot] <= 0:
        return
    hunger = min(MAX_HUNGER, hunger + 4.0)
    counts[selected_slot] -= 1
    _show_toast("غذا خوردی • گرسنگی +4")

func _select_slot(index: int) -> void:
    if index < 0 or index >= HOTBAR_SIZE:
        return
    selected_slot = index
    _refresh_hotbar()

func _build_survival_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "GameplayHUD"
    scene.add_child(layer)

    var panel := Panel.new()
    panel.position = Vector2(24, 105)
    panel.size = Vector2(260, 94)
    panel.modulate = Color(1, 1, 1, 0.82)
    layer.add_child(panel)

    var title := Label.new()
    title.text = "بقا"
    title.position = Vector2(14, 8)
    title.add_theme_font_size_override("font_size", 18)
    panel.add_child(title)

    health_bar = ProgressBar.new()
    health_bar.position = Vector2(14, 38)
    health_bar.size = Vector2(230, 18)
    health_bar.max_value = MAX_HEALTH
    health_bar.value = health
    health_bar.show_percentage = false
    panel.add_child(health_bar)

    hunger_bar = ProgressBar.new()
    hunger_bar.position = Vector2(14, 64)
    hunger_bar.size = Vector2(230, 18)
    hunger_bar.max_value = MAX_HUNGER
    hunger_bar.value = hunger
    hunger_bar.show_percentage = false
    panel.add_child(hunger_bar)

    status = Label.new()
    status.position = Vector2(300, 112)
    status.add_theme_font_size_override("font_size", 15)
    layer.add_child(status)

    toast = Label.new()
    toast.position = Vector2(420, 640)
    toast.size = Vector2(440, 50)
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.add_theme_font_size_override("font_size", 18)
    layer.add_child(toast)

func _build_hotbar() -> void:
    var layer := get_node("GameplayHUD")
    hotbar = HBoxContainer.new()
    hotbar.position = Vector2(360, 640)
    hotbar.size = Vector2(560, 64)
    hotbar.add_theme_constant_override("separation", 5)
    layer.add_child(hotbar)
    _refresh_hotbar()

func _refresh_hotbar() -> void:
    if hotbar == null:
        return
    for child in hotbar.get_children():
        child.queue_free()
    for i in range(HOTBAR_SIZE):
        var b := Button.new()
        b.custom_minimum_size = Vector2(58, 58)
        b.text = "%d\n%s\n%d" % [i + 1, _fa_block_name(inventory[i]), counts[i]]
        b.add_theme_font_size_override("font_size", 11)
        b.pressed.connect(func(slot := i): _select_slot(slot))
        if i == selected_slot:
            b.modulate = Color(1.0, 0.95, 0.55, 1.0)
        hotbar.add_child(b)

func _build_touch_actions() -> void:
    var layer := get_node("GameplayHUD")
    var break_button := Button.new()
    break_button.text = "⛏ شکستن"
    break_button.position = Vector2(940, 525)
    break_button.size = Vector2(120, 58)
    break_button.pressed.connect(_break_target)
    layer.add_child(break_button)

    var place_button := Button.new()
    place_button.text = "▣ ساختن"
    place_button.position = Vector2(940, 590)
    place_button.size = Vector2(120, 58)
    place_button.pressed.connect(_place_target)
    layer.add_child(place_button)

func _update_survival(delta: float) -> void:
    if player.is_on_floor() and player.velocity.length() > 2.0:
        hunger = max(0.0, hunger - delta * 0.012)
    if hunger <= 0.0:
        health = max(0.0, health - delta * 0.15)
    if health <= 0.0:
        player.global_position = Vector3(0, 5, 5)
        health = MAX_HEALTH
        hunger = MAX_HUNGER
        _show_toast("بازگشت به نقطه شروع")

func _update_day_cycle() -> void:
    var sun := scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
    var env_node := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if sun:
        var phase := world_time / 240.0 * TAU
        sun.rotation_degrees = Vector3(-45.0 + sin(phase) * 35.0, -30.0 + cos(phase) * 70.0, 0.0)
        sun.light_energy = 0.35 + max(0.0, sin(phase)) * 1.05
    if env_node and env_node.environment:
        var daylight := 0.35 + max(0.0, sin(world_time / 240.0 * TAU)) * 0.65
        env_node.environment.ambient_light_energy = daylight

func _update_hud() -> void:
    if health_bar:
        health_bar.value = health
    if hunger_bar:
        hunger_bar.value = hunger
    if status:
        var phase := "روز" if sin(world_time / 240.0 * TAU) >= 0.0 else "شب"
        status.text = "زمان: %s • بلوک انتخابی: %s ×%d" % [phase, _fa_block_name(inventory[selected_slot]), counts[selected_slot]]
    if toast and toast.modulate.a > 0.0:
        toast.modulate.a = max(0.0, toast.modulate.a - get_process_delta_time() * 0.6)

func _show_toast(text: String) -> void:
    if toast == null:
        return
    toast.text = text
    toast.modulate.a = 1.0

func _block_color(name: String) -> Color:
    match name:
        "grass": return Color(0.25, 0.65, 0.18)
        "dirt": return Color(0.32, 0.20, 0.10)
        "stone": return Color(0.55, 0.55, 0.58)
        "wood": return Color(0.45, 0.27, 0.12)
        "glass": return Color(0.55, 0.80, 0.92, 0.55)
        "sand": return Color(0.82, 0.72, 0.42)
        "brick": return Color(0.65, 0.25, 0.18)
        "lamp": return Color(1.0, 0.75, 0.25)
        "blue_crystal": return Color(0.15, 0.55, 1.0)
        _: return Color.WHITE

func _fa_block_name(name: String) -> String:
    match name:
        "grass": return "چمن"
        "dirt": return "خاک"
        "stone": return "سنگ"
        "wood": return "چوب"
        "glass": return "شیشه"
        "sand": return "شن"
        "brick": return "آجر"
        "lamp": return "چراغ"
        "blue_crystal": return "کریستال آبی"
        _: return name
