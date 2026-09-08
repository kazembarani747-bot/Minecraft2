extends Node

# Lightweight mobile-friendly creature simulation. The visual representation is
# intentionally original; behavior is separated so richer models/animations can
# replace it later without changing the AI state machine.
const MAX_MOBS := 12
const SPAWN_RADIUS := 10.0
const TICK_RATE := 0.25

var scene: Node3D
var player: CharacterBody3D
var mobs: Array[CharacterBody3D] = []
var next_tick := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    await get_tree().process_frame
    scene = get_tree().current_scene as Node3D
    if scene == null:
        return
    player = scene.get_node_or_null("Player") as CharacterBody3D
    rng.seed = 20260908
    _spawn_initial_mobs()

func _process(delta: float) -> void:
    if scene == null or player == null:
        return
    next_tick -= delta
    if next_tick > 0.0:
        return
    next_tick = TICK_RATE
    _simulate_mobs()

func _spawn_initial_mobs() -> void:
    for i in range(6):
        var kind := "pig" if i % 2 == 0 else "zombie"
        var angle := rng.randf_range(0.0, TAU)
        var distance := rng.randf_range(4.0, SPAWN_RADIUS)
        _spawn_mob(kind, player.global_position + Vector3(cos(angle) * distance, 3.0, sin(angle) * distance))

func _spawn_mob(kind: String, position: Vector3) -> void:
    if mobs.size() >= MAX_MOBS:
        return
    var mob := CharacterBody3D.new()
    mob.name = kind
    mob.position = position
    mob.set_meta("kind", kind)
    mob.set_meta("mood", "calm")
    mob.set_meta("home", position)
    mob.set_meta("phase", rng.randf_range(0.0, TAU))

    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.9, 0.9, 0.9) if kind == "pig" else Vector3(0.8, 1.7, 0.8)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.82, 0.48, 0.58) if kind == "pig" else Color(0.18, 0.35, 0.22)
    box.material = material
    mesh.mesh = box
    mesh.position.y = box.size.y * 0.5
    mob.add_child(mesh)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box.size
    collision.shape = shape
    collision.position.y = box.size.y * 0.5
    mob.add_child(collision)
    scene.add_child(mob)
    mobs.append(mob)

func _simulate_mobs() -> void:
    for mob in mobs.duplicate():
        if not is_instance_valid(mob):
            mobs.erase(mob)
            continue
        var kind := str(mob.get_meta("kind", "pig"))
        var distance := mob.global_position.distance_to(player.global_position)
        var mood := "calm"
        var direction := Vector3.ZERO

        if kind == "zombie" and distance < 9.0:
            mood = "worried" if distance > 4.0 else "angry"
            direction = (player.global_position - mob.global_position).normalized()
        elif kind == "pig" and distance < 5.0:
            mood = "happy"
            direction = (mob.global_position - player.global_position).normalized()
        else:
            var phase := float(mob.get_meta("phase", 0.0)) + TICK_RATE
            mob.set_meta("phase", phase)
            direction = Vector3(cos(phase), 0.0, sin(phase)) * 0.35

        mob.set_meta("mood", mood)
        direction.y = 0.0
        if direction.length() > 0.05:
            mob.velocity = direction.normalized() * (1.15 if kind == "zombie" else 0.65)
            mob.move_and_slide()
            mob.rotation.y = lerp_angle(mob.rotation.y, atan2(-direction.x, -direction.z), 0.2)
        else:
            mob.velocity = Vector3.ZERO

func get_mob_state(mob: Node) -> Dictionary:
    if mob == null:
        return {}
    return {"kind": mob.get_meta("kind", "unknown"), "mood": mob.get_meta("mood", "calm")}
