extends Node3D

var blocks: Array[Dictionary] = []
var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.15
var speed := 5.0
var gravity := 14.0
var velocity_y := 0.0

func _ready() -> void:
    _setup_environment()
    _build_world()
    _build_player()
    _build_ui()

func _setup_environment() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.42, 0.68, 0.92)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.75, 0.82, 1.0)
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.2
    add_child(sun)

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    return m

func _block(pos: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    box.material = _mat(color)
    mesh.mesh = box
    body.add_child(mesh)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3.ONE
    shape.shape = box_shape
    body.add_child(shape)
    add_child(body)

func _build_world() -> void:
    for x in range(-10, 11):
        for z in range(-10, 11):
            var h := 1 + int((sin(float(x) * 0.55) + cos(float(z) * 0.47)) * 0.5 + 1.0)
            for y in range(h):
                var c := Color(0.32, 0.20, 0.10)
                if y == h - 1:
                    c = Color(0.25, 0.65, 0.18)
                _block(Vector3(x, y - 1, z), c)
    for x in range(-3, 4):
        _block(Vector3(x, 1, -4), Color(0.55, 0.55, 0.58))

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0, 5, 5)
    add_child(player)
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    shape.shape = capsule
    shape.position.y = 0.9
    player.add_child(shape)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.55, 0)
    player.add_child(camera)
    camera.current = true

func _physics_process(delta: float) -> void:
    if player == null:
        return
    var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir := (player.transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
    player.velocity.x = dir.x * speed
    player.velocity.z = dir.z * speed
    if not player.is_on_floor():
        velocity_y -= gravity * delta
    else:
        velocity_y = -0.5
    player.velocity.y = velocity_y
    player.move_and_slide()
    if player.position.y < -10:
        player.position = Vector3(0, 5, 5)
        velocity_y = 0

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var title := Label.new()
    title.text = "MINECRAFT2 • 3D TEST"
    title.position = Vector2(28, 24)
    title.add_theme_font_size_override("font_size", 28)
    layer.add_child(title)
    var info := Label.new()
    info.text = "WASD حرکت • نسخه تست جهان سه‌بعدی\nهدف مرحله ۱: ورود به جهان و تست اجرای APK"
    info.position = Vector2(30, 64)
    info.add_theme_font_size_override("font_size", 18)
    layer.add_child(info)
    var cross := Label.new()
    cross.text = "+"
    cross.position = Vector2(638, 345)
    cross.add_theme_font_size_override("font_size", 28)
    layer.add_child(cross)
