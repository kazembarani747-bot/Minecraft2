extends Node3D

const WORLD_RADIUS := 12
const PLAYER_SPEED := 5.0
const GRAVITY := 14.0
const TOUCH_MODE_JOYSTICK_TAP := 0
const TOUCH_MODE_JOYSTICK_CROSSHAIR := 1
const TOUCH_MODE_DPAD_TAP := 2

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.15
var velocity_y := 0.0
var third_person := false
var touch_mode := TOUCH_MODE_JOYSTICK_TAP
var settings_open := false
var command_line: LineEdit
var command_output: Label
var status_label: Label
var touch_root: Control
var joystick_base: Control
var joystick_knob: Control
var dpad_root: Control
var look_touch_id := -1
var move_touch_id := -1
var move_start := Vector2.ZERO
var look_last := Vector2.ZERO
var move_vector := Vector2.ZERO

func _ready() -> void:
    _ensure_game_directories()
    _load_preferences()
    _setup_environment()
    _build_world()
    _build_player()
    _build_ui()
    _build_touch_controls()
    _update_touch_mode_ui()

func _ensure_game_directories() -> void:
    DirAccess.make_dir_recursive_absolute("user://mods")
    DirAccess.make_dir_recursive_absolute("user://resource_packs")
    DirAccess.make_dir_recursive_absolute("user://behavior_packs")
    DirAccess.make_dir_recursive_absolute("user://worlds")
    DirAccess.make_dir_recursive_absolute("user://config")
    var config := ConfigFile.new()
    if not FileAccess.file_exists("user://config/minecraft2.cfg"):
        config.set_value("game", "version", "0.2.0")
        config.set_value("controls", "touch_mode", touch_mode)
        config.set_value("camera", "third_person", third_person)
        config.save("user://config/minecraft2.cfg")

func _load_preferences() -> void:
    var config := ConfigFile.new()
    if config.load("user://config/minecraft2.cfg") == OK:
        touch_mode = int(config.get_value("controls", "touch_mode", TOUCH_MODE_JOYSTICK_TAP))
        third_person = bool(config.get_value("camera", "third_person", false))

func _save_preferences() -> void:
    var config := ConfigFile.new()
    config.set_value("game", "version", "0.2.0")
    config.set_value("controls", "touch_mode", touch_mode)
    config.set_value("camera", "third_person", third_person)
    config.save("user://config/minecraft2.cfg")

func _setup_environment() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.42, 0.68, 0.92)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.75, 0.82, 1.0)
    env.ambient_light_energy = 0.8
    env_node.environment = env
    add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    add_child(sun)

func _mat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    return material

func _block(pos: Vector3, color: Color, block_name: String = "grass") -> void:
    var body := StaticBody3D.new()
    body.name = block_name
    body.position = pos
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    box.material = _mat(color)
    mesh.mesh = box
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3.ONE
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

func _build_world() -> void:
    for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
        for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
            var wave := sin(float(x) * 0.55) + cos(float(z) * 0.47)
            var height := 1 + int((wave + 2.0) * 0.5)
            for y in range(height):
                var color := Color(0.32, 0.20, 0.10)
                var name := "dirt"
                if y == height - 1:
                    color = Color(0.25, 0.65, 0.18)
                    name = "grass"
                _block(Vector3(x, y - 1, z), color, name)
    for x in range(-4, 5):
        _block(Vector3(x, 1, -5), Color(0.55, 0.55, 0.58), "stone")

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 5, 5)
    add_child(player)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)
    camera = Camera3D.new()
    camera.current = true
    player.add_child(camera)
    _update_camera()

func _update_camera() -> void:
    if third_person:
        camera.position = Vector3(0, 2.1, 4.0)
    else:
        camera.position = Vector3(0, 1.55, 0)
    camera.rotation = Vector3(pitch, 0, 0)

func _physics_process(delta: float) -> void:
    if player == null or settings_open:
        return
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if move_vector.length() > 0.05:
        input_vec = move_vector
    var forward := -player.global_transform.basis.z
    var right := player.global_transform.basis.x
    var direction := (right * input_vec.x + forward * input_vec.y)
    direction.y = 0.0
    direction = direction.normalized()
    player.velocity.x = direction.x * PLAYER_SPEED
    player.velocity.z = direction.z * PLAYER_SPEED
    if not player.is_on_floor():
        velocity_y -= GRAVITY * delta
    else:
        velocity_y = -0.5
    player.velocity.y = velocity_y
    player.move_and_slide()
    if player.position.y < -10:
        player.position = Vector3(0, 5, 5)
        velocity_y = 0.0

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F5:
            third_person = not third_person
            _update_camera()
            _save_preferences()
            _refresh_status()
        elif event.keycode == KEY_ESCAPE:
            _toggle_settings()
        elif event.keycode == KEY_ENTER and command_line.has_focus():
            _run_command(command_line.text)
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not settings_open:
        _look(event.relative)
    if event is InputEventScreenTouch and not settings_open:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and move_touch_id == -1:
                move_touch_id = event.index
                move_start = event.position
                move_vector = Vector2.ZERO
                _set_joystick(move_start)
            elif event.position.x >= get_viewport().get_visible_rect().size.x * 0.45 and look_touch_id == -1:
                look_touch_id = event.index
                look_last = event.position
        else:
            if event.index == move_touch_id:
                move_touch_id = -1
                move_vector = Vector2.ZERO
                _reset_joystick()
            elif event.index == look_touch_id:
                look_touch_id = -1
    if event is InputEventScreenDrag and not settings_open:
        if event.index == look_touch_id:
            _look(event.relative)
        elif event.index == move_touch_id:
            var delta: Vector2 = event.position - move_start
            move_vector = delta.limit_length(80.0) / 80.0
            if touch_mode == TOUCH_MODE_DPAD_TAP:
                move_vector.x = 0.0 if abs(move_vector.x) < 0.35 else sign(move_vector.x)
                move_vector.y = 0.0 if abs(move_vector.y) < 0.35 else sign(move_vector.y)

func _look(relative: Vector2) -> void:
    yaw -= relative.x * 0.003
    pitch = clamp(pitch - relative.y * 0.003, -1.4, 1.4)
    player.rotation.y = yaw
    camera.rotation.x = pitch

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    var title := Label.new()
    title.text = "MINECRAFT2"
    title.position = Vector2(28, 20)
    title.add_theme_font_size_override("font_size", 30)
    layer.add_child(title)
    var info := Label.new()
    info.name = "Help"
    info.text = "نسخه واقعی سه‌بعدی در حال توسعه • F5: دید سوم‌شخص • ESC: تنظیمات"
    info.position = Vector2(30, 60)
    info.add_theme_font_size_override("font_size", 16)
    layer.add_child(info)
    var cross := Label.new()
    cross.text = "+"
    cross.position = Vector2(638, 345)
    cross.add_theme_font_size_override("font_size", 28)
    cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(cross)
    status_label = Label.new()
    status_label.position = Vector2(30, 690)
    status_label.add_theme_font_size_override("font_size", 16)
    layer.add_child(status_label)
    _refresh_status()
    _build_settings(layer)

func _build_settings(layer: CanvasLayer) -> void:
    var panel := Panel.new()
    panel.name = "SettingsPanel"
    panel.position = Vector2(330, 90)
    panel.size = Vector2(620, 540)
    panel.visible = false
    layer.add_child(panel)
    var header := Label.new()
    header.text = "تنظیمات Minecraft2"
    header.position = Vector2(24, 20)
    header.add_theme_font_size_override("font_size", 26)
    panel.add_child(header)
    var mode_label := Label.new()
    mode_label.text = "نوع کنترل لمسی"
    mode_label.position = Vector2(24, 80)
    mode_label.add_theme_font_size_override("font_size", 18)
    panel.add_child(mode_label)
    var b0 := Button.new()
    b0.text = "Joystick & tap to interact"
    b0.position = Vector2(24, 120)
    b0.size = Vector2(270, 48)
    b0.pressed.connect(func(): _set_touch_mode(TOUCH_MODE_JOYSTICK_TAP))
    panel.add_child(b0)
    var b1 := Button.new()
    b1.text = "Joystick & aim crosshair"
    b1.position = Vector2(318, 120)
    b1.size = Vector2(270, 48)
    b1.pressed.connect(func(): _set_touch_mode(TOUCH_MODE_JOYSTICK_CROSSHAIR))
    panel.add_child(b1)
    var b2 := Button.new()
    b2.text = "D-Pad & tap to interact"
    b2.position = Vector2(24, 184)
    b2.size = Vector2(270, 48)
    b2.pressed.connect(func(): _set_touch_mode(TOUCH_MODE_DPAD_TAP))
    panel.add_child(b2)
    var cam := Button.new()
    cam.text = "تغییر دید اول‌شخص / سوم‌شخص"
    cam.position = Vector2(318, 184)
    cam.size = Vector2(270, 48)
    cam.pressed.connect(func(): _toggle_camera())
    panel.add_child(cam)
    var command_title := Label.new()
    command_title.text = "دستورات با /"
    command_title.position = Vector2(24, 252)
    command_title.add_theme_font_size_override("font_size", 18)
    panel.add_child(command_title)
    command_line = LineEdit.new()
    command_line.placeholder_text = "/help"
    command_line.position = Vector2(24, 288)
    command_line.size = Vector2(564, 46)
    command_line.text_submitted.connect(_run_command)
    panel.add_child(command_line)
    command_output = Label.new()
    command_output.text = "/help برای دیدن فرمان‌های آزمایشی"
    command_output.position = Vector2(24, 346)
    command_output.size = Vector2(564, 90)
    command_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(command_output)
    var close := Button.new()
    close.text = "بستن"
    close.position = Vector2(24, 470)
    close.size = Vector2(180, 44)
    close.pressed.connect(_toggle_settings)
    panel.add_child(close)

func _build_touch_controls() -> void:
    var layer := CanvasLayer.new()
    layer.name = "TouchHUD"
    add_child(layer)
    touch_root = Control.new()
    touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(touch_root)
    joystick_base = Panel.new()
    joystick_base.position = Vector2(55, 515)
    joystick_base.size = Vector2(150, 150)
    joystick_base.modulate = Color(1, 1, 1, 0.22)
    touch_root.add_child(joystick_base)
    joystick_knob = Panel.new()
    joystick_knob.position = Vector2(100, 560)
    joystick_knob.size = Vector2(60, 60)
    joystick_knob.modulate = Color(1, 1, 1, 0.45)
    touch_root.add_child(joystick_knob)
    dpad_root = Control.new()
    dpad_root.position = Vector2(50, 500)
    dpad_root.size = Vector2(170, 170)
    touch_root.add_child(dpad_root)
    _make_dpad_button("▲", Vector2(60, 0), Vector2(50, 50), Vector2(0, -1))
    _make_dpad_button("▼", Vector2(60, 115), Vector2(50, 50), Vector2(0, 1))
    _make_dpad_button("◀", Vector2(0, 58), Vector2(50, 50), Vector2(-1, 0))
    _make_dpad_button("▶", Vector2(120, 58), Vector2(50, 50), Vector2(1, 0))
    var jump := Button.new()
    jump.text = "↑"
    jump.position = Vector2(1080, 540)
    jump.size = Vector2(90, 70)
    jump.pressed.connect(_jump)
    touch_root.add_child(jump)
    var third := Button.new()
    third.text = "👁"
    third.position = Vector2(1090, 460)
    third.size = Vector2(70, 60)
    third.pressed.connect(_toggle_camera)
    touch_root.add_child(third)
    var menu := Button.new()
    menu.text = "☰"
    menu.position = Vector2(1160, 24)
    menu.size = Vector2(80, 60)
    menu.pressed.connect(_toggle_settings)
    touch_root.add_child(menu)

func _make_dpad_button(text: String, pos: Vector2, size: Vector2, dir: Vector2) -> void:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.pressed.connect(func(): move_vector = dir)
    dpad_root.add_child(b)

func _set_joystick(center: Vector2) -> void:
    joystick_base.position = center - joystick_base.size * 0.5
    joystick_knob.position = center - joystick_knob.size * 0.5

func _reset_joystick() -> void:
    joystick_base.position = Vector2(55, 515)
    joystick_knob.position = Vector2(100, 560)

func _jump() -> void:
    if player != null and player.is_on_floor():
        velocity_y = 6.5

func _set_touch_mode(mode: int) -> void:
    touch_mode = mode
    _update_touch_mode_ui()
    _save_preferences()

func _update_touch_mode_ui() -> void:
    if joystick_base == null or dpad_root == null:
        return
    var use_dpad := touch_mode == TOUCH_MODE_DPAD_TAP
    joystick_base.visible = not use_dpad
    joystick_knob.visible = not use_dpad
    dpad_root.visible = use_dpad

func _toggle_camera() -> void:
    third_person = not third_person
    _update_camera()
    _save_preferences()
    _refresh_status()

func _toggle_settings() -> void:
    settings_open = not settings_open
    var panel := get_node_or_null("HUD/SettingsPanel")
    if panel != null:
        panel.visible = settings_open
    if settings_open and command_line != null:
        command_line.release_focus()

func _refresh_status() -> void:
    if status_label == null:
        return
    var mode_name := "Joystick & tap to interact"
    if touch_mode == TOUCH_MODE_JOYSTICK_CROSSHAIR:
        mode_name = "Joystick & aim crosshair"
    elif touch_mode == TOUCH_MODE_DPAD_TAP:
        mode_name = "D-Pad & tap to interact"
    var camera_name := "سوم‌شخص" if third_person else "اول‌شخص"
    status_label.text = "کنترل: %s • دید: %s • پوشه مود: user://mods" % [mode_name, camera_name]

func _run_command(raw_command: String) -> void:
    var text := raw_command.strip_edges()
    if text.is_empty():
        return
    if not text.begins_with("/"):
        command_output.text = "فرمان باید با / شروع شود."
        return
    var parts := text.split(" ", false)
    var command := parts[0].to_lower()
    match command:
        "/help", "/?":
            command_output.text = "/help  /gamemode <survival|creative>  /time <day|night>  /tp <x> <y> <z>"
        "/gamemode":
            command_output.text = "حالت بازی آمادهٔ اتصال به سیستم بازی است: " + (parts[1] if parts.size() > 1 else "survival")
        "/time":
            command_output.text = "زمان آزمایشی: " + (parts[1] if parts.size() > 1 else "day")
        "/tp":
            if parts.size() >= 4:
                player.position = Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
                command_output.text = "تلپورت انجام شد."
            else:
                command_output.text = "استفاده: /tp <x> <y> <z>"
        _:
            command_output.text = "Unknown command. برای فرمان‌ها /help را بزن."
    command_line.text = ""
