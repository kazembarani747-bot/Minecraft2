extends Node

# Minecraft2 gameplay layer: interaction, survival, inventory, crafting and saves
# are modular so the renderer/network core can evolve without rewriting UX.
const REACH := 6.0
const HOTBAR_SIZE := 9
const INVENTORY_SIZE := 27
const MAX_HEALTH := 20.0
const MAX_HUNGER := 20.0
const AUTOSAVE_SECONDS := 20.0

var scene: Node3D
var player: CharacterBody3D
var camera: Camera3D
var hotbar: HBoxContainer
var status: Label
var toast: Label
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var inventory_panel: Panel
var inventory_grid: GridContainer
var crafting_output: Button
var selected_slot := 0
var health := MAX_HEALTH
var hunger := MAX_HUNGER
var world_time := 0.0
var autosave_timer := 0.0
var inventory_open := false
var inventory := ["grass", "dirt", "stone", "wood", "glass", "sand", "brick", "lamp", "blue_crystal"]
var counts := [32, 32, 64, 16, 16, 32, 16, 8, 4]
var extra_slots: Array[String] = []
var extra_counts: Array[int] = []

func _ready() -> void:
    await get_tree().process_frame
    scene = get_tree().current_scene as Node3D
    if scene == null:
        return
    player = scene.get_node_or_null("Player") as CharacterBody3D
    if player:
        camera = player.get_node_or_null("Camera3D") as Camera3D
    _init_extra_inventory()
    _build_survival_hud()
    _build_hotbar()
    _build_inventory_panel()
    _build_touch_actions()
    _load_persistent_state()
    _show_toast("ماینکرافت۲: بقا، موجودی، ساخت‌وساز و ذخیره‌سازی فعال شد")

func _init_extra_inventory() -> void:
    extra_slots.clear()
    extra_counts.clear()
    for i in range(INVENTORY_SIZE - HOTBAR_SIZE):
        extra_slots.append("")
        extra_counts.append(0)

func _process(delta: float) -> void:
    if scene == null or player == null:
        return
    world_time = fmod(world_time + delta * 0.7, 240.0)
    autosave_timer += delta
    _update_day_cycle()
    _update_survival(delta)
    _update_hud()
    if autosave_timer >= AUTOSAVE_SECONDS:
        autosave_timer = 0.0
        _save_persistent_state(false)

func _unhandled_input(event: InputEvent) -> void:
    if scene == null or scene.get("settings_open"):
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode >= KEY_1 and event.keycode <= KEY_9:
            _select_slot(event.keycode - KEY_1)
        elif event.keycode == KEY_Q and not inventory_open:
            _drop_selected()
        elif event.keycode == KEY_E and not inventory_open:
            _eat_selected()
        elif event.keycode == KEY_I or event.keycode == KEY_TAB:
            _toggle_inventory()
        elif event.keycode == KEY_F2:
            _save_persistent_state(true)
    if event is InputEventMouseButton and event.pressed and not inventory_open:
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
    _add_item(block_name, 1)
    body.queue_free()
    _show_toast("برداشته شد: %s ×1" % _fa_block_name(block_name))
    _save_persistent_state(false)

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
    if scene.has_method("_block"):
        scene.call("_block", cell, _block_color(block_name), block_name)
        counts[selected_slot] -= 1
        _refresh_hotbar()
        _show_toast("ساخته شد: %s" % _fa_block_name(block_name))
        _save_persistent_state(false)

func _drop_selected() -> void:
    if counts[selected_slot] > 0:
        counts[selected_slot] -= 1
        _refresh_hotbar()
        _show_toast("یک آیتم روی زمین افتاد")
        _save_persistent_state(false)

func _eat_selected() -> void:
    if counts[selected_slot] <= 0:
        return
    hunger = min(MAX_HUNGER, hunger + 4.0)
    counts[selected_slot] -= 1
    _refresh_hotbar()
    _show_toast("غذا خوردی • گرسنگی +4")

func _add_item(name: String, amount: int) -> bool:
    var slot := inventory.find(name)
    if slot >= 0:
        counts[slot] += amount
        _refresh_hotbar()
        return true
    for i in range(extra_slots.size()):
        if extra_slots[i] == name:
            extra_counts[i] += amount
            _refresh_inventory()
            return true
    for i in range(extra_slots.size()):
        if extra_slots[i].is_empty():
            extra_slots[i] = name
            extra_counts[i] = amount
            _refresh_inventory()
            return true
    _show_toast("موجودی پر است")
    return false

func _select_slot(index: int) -> void:
    if index < 0 or index >= HOTBAR_SIZE:
        return
    selected_slot = index
    _refresh_hotbar()

func _toggle_inventory() -> void:
    inventory_open = not inventory_open
    if inventory_panel:
        inventory_panel.visible = inventory_open
    _refresh_inventory()

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

func _build_inventory_panel() -> void:
    var layer := get_node("GameplayHUD")
    inventory_panel = Panel.new()
    inventory_panel.name = "InventoryPanel"
    inventory_panel.position = Vector2(270, 105)
    inventory_panel.size = Vector2(740, 500)
    inventory_panel.visible = false
    layer.add_child(inventory_panel)

    var title := Label.new()
    title.text = "موجودی و ساخت"
    title.position = Vector2(24, 18)
    title.add_theme_font_size_override("font_size", 24)
    inventory_panel.add_child(title)

    var hint := Label.new()
    hint.text = "I / TAB برای بستن • مواد را با کلیک انتخاب کن"
    hint.position = Vector2(24, 52)
    inventory_panel.add_child(hint)

    inventory_grid = GridContainer.new()
    inventory_grid.columns = 9
    inventory_grid.position = Vector2(24, 92)
    inventory_grid.size = Vector2(690, 260)
    inventory_grid.add_theme_constant_override("h_separation", 6)
    inventory_grid.add_theme_constant_override("v_separation", 6)
    inventory_panel.add_child(inventory_grid)

    var craft_title := Label.new()
    craft_title.text = "ساخت سریع"
    craft_title.position = Vector2(24, 375)
    craft_title.add_theme_font_size_override("font_size", 19)
    inventory_panel.add_child(craft_title)

    crafting_output = Button.new()
    crafting_output.position = Vector2(24, 410)
    crafting_output.size = Vector2(310, 54)
    crafting_output.pressed.connect(_craft_selected)
    inventory_panel.add_child(crafting_output)
    _refresh_inventory()

func _refresh_inventory() -> void:
    if inventory_grid == null:
        return
    for child in inventory_grid.get_children():
        child.queue_free()
    for i in range(HOTBAR_SIZE):
        _add_inventory_button(inventory[i], counts[i], i)
    for i in range(extra_slots.size()):
        _add_inventory_button(extra_slots[i], extra_counts[i], HOTBAR_SIZE + i)
    if crafting_output:
        crafting_output.text = "ساخت چراغ: 4 چوب → 1 چراغ" if _can_craft_lamp() else "ساخت چراغ (مواد کافی نیست)"

func _add_inventory_button(name: String, amount: int, index: int) -> void:
    var b := Button.new()
    b.custom_minimum_size = Vector2(72, 62)
    if name.is_empty():
        b.text = "—"
        b.disabled = true
    else:
        b.text = "%s\n×%d" % [_fa_block_name(name), amount]
        b.pressed.connect(func(slot := index): _select_inventory_slot(slot))
    inventory_grid.add_child(b)

func _select_inventory_slot(index: int) -> void:
    if index < HOTBAR_SIZE:
        _select_slot(index)
    else:
        var extra := index - HOTBAR_SIZE
        if extra >= 0 and extra < extra_slots.size() and not extra_slots[extra].is_empty():
            inventory[selected_slot] = extra_slots[extra]
            counts[selected_slot] = extra_counts[extra]
            extra_slots[extra] = ""
            extra_counts[extra] = 0
            _refresh_hotbar()
            _refresh_inventory()
            _show_toast("آیتم به نوار ابزار منتقل شد")

func _can_craft_lamp() -> bool:
    return _total_item("wood") >= 4

func _total_item(name: String) -> int:
    var total := 0
    for i in range(inventory.size()):
        if inventory[i] == name:
            total += counts[i]
    for i in range(extra_slots.size()):
        if extra_slots[i] == name:
            total += extra_counts[i]
    return total

func _remove_item(name: String, amount: int) -> bool:
    var remaining := amount
    for i in range(inventory.size()):
        if inventory[i] == name and remaining > 0:
            var take := min(counts[i], remaining)
            counts[i] -= take
            remaining -= take
    for i in range(extra_slots.size()):
        if extra_slots[i] == name and remaining > 0:
            var take := min(extra_counts[i], remaining)
            extra_counts[i] -= take
            remaining -= take
            if extra_counts[i] <= 0:
                extra_slots[i] = ""
    return remaining <= 0

func _craft_selected() -> void:
    if not _can_craft_lamp():
        _show_toast("برای چراغ 4 چوب لازم است")
        return
    if _remove_item("wood", 4):
        _add_item("lamp", 1)
        _refresh_hotbar()
        _refresh_inventory()
        _show_toast("چراغ ساخته شد")
        _save_persistent_state(true)

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

    var inventory_button := Button.new()
    inventory_button.text = "🎒 موجودی"
    inventory_button.position = Vector2(940, 460)
    inventory_button.size = Vector2(120, 58)
    inventory_button.pressed.connect(_toggle_inventory)
    layer.add_child(inventory_button)

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
        status.text = "زمان: %s • بلوک انتخابی: %s ×%d • F2 ذخیره" % [phase, _fa_block_name(inventory[selected_slot]), counts[selected_slot]]
    if toast and toast.modulate.a > 0.0:
        toast.modulate.a = max(0.0, toast.modulate.a - get_process_delta_time() * 0.6)

func _save_persistent_state(show_message: bool) -> void:
    if not is_instance_valid(player):
        return
    var save_system := get_node_or_null("/root/Minecraft2SaveSystem")
    if save_system == null:
        return
    var data := {
        "player": {"x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z},
        "health": health,
        "hunger": hunger,
        "world_time": world_time,
        "selected_slot": selected_slot,
        "inventory": inventory.duplicate(),
        "counts": counts.duplicate(),
        "extra_slots": extra_slots.duplicate(),
        "extra_counts": extra_counts.duplicate()
    }
    var ok: bool = save_system.call("save_game", data)
    if show_message:
        _show_toast("بازی ذخیره شد" if ok else "ذخیره‌سازی ناموفق بود")

func _load_persistent_state() -> void:
    var save_system := get_node_or_null("/root/Minecraft2SaveSystem")
    if save_system == null:
        return
    var data: Dictionary = save_system.call("load_game")
    if data.is_empty():
        return
    var p: Dictionary = data.get("player", {})
    if p.has("x") and p.has("y") and p.has("z"):
        player.global_position = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
    health = clamp(float(data.get("health", MAX_HEALTH)), 0.0, MAX_HEALTH)
    hunger = clamp(float(data.get("hunger", MAX_HUNGER)), 0.0, MAX_HUNGER)
    world_time = fmod(float(data.get("world_time", 0.0)), 240.0)
    selected_slot = clamp(int(data.get("selected_slot", 0)), 0, HOTBAR_SIZE - 1)
    var saved_inventory = data.get("inventory", [])
    var saved_counts = data.get("counts", [])
    if saved_inventory is Array and saved_inventory.size() == HOTBAR_SIZE:
        inventory = saved_inventory.duplicate()
    if saved_counts is Array and saved_counts.size() == HOTBAR_SIZE:
        counts = saved_counts.duplicate()
    var saved_extra = data.get("extra_slots", [])
    var saved_extra_counts = data.get("extra_counts", [])
    if saved_extra is Array and saved_extra.size() == extra_slots.size():
        extra_slots = saved_extra.duplicate()
    if saved_extra_counts is Array and saved_extra_counts.size() == extra_counts.size():
        extra_counts = saved_extra_counts.duplicate()
    _refresh_hotbar()
    _refresh_inventory()
    _show_toast("دنیای ذخیره‌شده بارگذاری شد")

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
