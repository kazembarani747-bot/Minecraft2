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
    env_node.name = "WorldEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.42, 0.68, 0.92)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.70, 0.78, 0.96)
    env.ambient_light_energy = 0.65
    env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    env_node.environment = env
    add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.35
    sun.light_color = Color(1.0, 0.97, 0.90)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 96.0
    sun.directional_shadow_fade_start = 0.78
    sun.shadow_bias = 0.035
    sun.shadow_normal_bias = 1.0
    sun.distance_fade_enabled = true
    sun.distance_fade_begin = 72.0
    sun.distance_fade_shadow = 0.85
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

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 5, 5)
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    var collision := CollisionShape3D.new()
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)
    add_child(player)

    camera = Camera3D.new()
    camera.position = Vector3(0, 1.6, 0)
    camera.current = true
    player.add_child(camera)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    status_label = Label.new()
    status_label.position = Vector2(24, 24)
    status_label.text = "Minecraft2 • Survival"
    status_label.add_theme_font_size_override("font_size", 20)
    layer.add_child(status_label)
    var crosshair := Label.new()
    crosshair.text = "+"
    crosshair.position = Vector2(637, 347)
    crosshair.add_theme_font_size_override("font_size", 24)
    layer.add_child(crosshair)
    command_line = LineEdit.new()
    command_line.position = Vector2(24, 620)
    command_line.size = Vector2(360, 42)
    command_line.placeholder_text = "Command..."
    layer.add_child(command_line)
    command_output = Label.new()
    command_output.position = Vector2(24, 570)
    command_output.size = Vector2(700, 45)
    layer.add_child(command_output)

func _build_touch_controls() -> void:
    touch_root = Control.new()
    touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(touch_root)

func _update_touch_mode_ui() -> void:
    pass
