extends Node

# Explicit mobile voxel actions. Buttons are separate from the look area so
# jump/camera/menu touches cannot accidentally edit a block.
var bridge
var layer: CanvasLayer

func _ready() -> void:
    await get_tree().process_frame
    bridge = get_node_or_null("/root/Minecraft2BlockEditBridge")
    _build_buttons()

func _build_buttons() -> void:
    layer = CanvasLayer.new()
    layer.name = "MobileActions"
    add_child(layer)
    var break_button := Button.new()
    break_button.name = "BreakBlock"
    break_button.text = "⛏"
    break_button.tooltip_text = "شکستن بلاک"
    break_button.position = Vector2(930, 555)
    break_button.size = Vector2(95, 70)
    break_button.modulate = Color(1, 1, 1, 0.82)
    break_button.pressed.connect(_break)
    layer.add_child(break_button)

    var place_button := Button.new()
    place_button.name = "PlaceBlock"
    place_button.text = "＋"
    place_button.tooltip_text = "گذاشتن بلاک"
    place_button.position = Vector2(1035, 555)
    place_button.size = Vector2(95, 70)
    place_button.modulate = Color(1, 1, 1, 0.82)
    place_button.pressed.connect(_place)
    layer.add_child(place_button)

func _break() -> void:
    if bridge != null and bridge.has_method("break_target"):
        bridge.call("break_target")

func _place() -> void:
    if bridge != null and bridge.has_method("place_target"):
        bridge.call("place_target")
