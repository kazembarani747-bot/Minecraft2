extends Node

# Mobile-friendly frame pacing and safe runtime render tuning.
const TARGET_FPS := 120
const MIN_FPS := 45.0
const SAMPLE_SECONDS := 1.0
const RECOVERY_SECONDS := 4.0

var sample_time := 0.0
var low_time := 0.0
var recovery_time := 0.0
var quality_level := 2
var diagnostic_label: Label

func _ready() -> void:
    Engine.max_fps = TARGET_FPS
    Engine.physics_ticks_per_second = 60
    await get_tree().process_frame
    _apply_quality()
    _build_hud()

func _process(delta: float) -> void:
    sample_time += delta
    var fps := Engine.get_frames_per_second()
    if fps > 0.0 and fps < MIN_FPS:
        low_time += delta
        recovery_time = 0.0
    elif fps >= 60.0:
        recovery_time += delta
        low_time = maxf(0.0, low_time - delta * 0.5)

    if low_time >= SAMPLE_SECONDS and quality_level > 0:
        quality_level -= 1
        low_time = 0.0
        recovery_time = 0.0
        _apply_quality()
    elif recovery_time >= RECOVERY_SECONDS and quality_level < 2:
        quality_level += 1
        recovery_time = 0.0
        _apply_quality()

    if sample_time >= SAMPLE_SECONDS:
        sample_time = 0.0
        _update_hud(fps)

func _apply_quality() -> void:
    var viewport := get_viewport()
    if viewport == null:
        return
    # Keep the game sharp by default; only lower 3D scaling when sustained
    # frame pressure is detected. This is intentionally conservative for mobile.
    if quality_level >= 2:
        viewport.scaling_3d_scale = 1.0
    elif quality_level == 1:
        viewport.scaling_3d_scale = 0.90
    else:
        viewport.scaling_3d_scale = 0.78
    viewport.msaa_3d = Viewport.MSAA_DISABLED

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "PerformanceHUD"
    add_child(layer)
    diagnostic_label = Label.new()
    diagnostic_label.position = Vector2(28, 650)
    diagnostic_label.add_theme_font_size_override("font_size", 12)
    diagnostic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(diagnostic_label)

func _update_hud(fps: float) -> void:
    if diagnostic_label == null:
        return
    var names := ["Eco", "Balanced", "Quality"]
    diagnostic_label.text = "PERF • %s • FPS %d • 3D %.0f%% • Max %d" % [names[quality_level], int(fps), get_viewport().scaling_3d_scale * 100.0, TARGET_FPS]
