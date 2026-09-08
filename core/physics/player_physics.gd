class_name Minecraft2PlayerPhysics
extends RefCounted

const DEFAULT_GRAVITY := 24.0
const JUMP_SPEED := 8.0
const WALK_SPEED := 4.8
const SPRINT_SPEED := 7.2

var gravity: float = DEFAULT_GRAVITY
var velocity := Vector3.ZERO
var grounded := false

func step(delta: float, input_direction: Vector3, sprinting: bool, jump_pressed: bool) -> Vector3:
    var speed := SPRINT_SPEED if sprinting else WALK_SPEED
    velocity.x = input_direction.x * speed
    velocity.z = input_direction.z * speed

    if grounded and jump_pressed:
        velocity.y = JUMP_SPEED
        grounded = false
    else:
        velocity.y -= gravity * delta

    return velocity * delta

func land() -> void:
    grounded = true
    velocity.y = 0.0

func set_gravity(value: float) -> void:
    gravity = maxf(0.0, value)
