extends Node

# Small, versioned save layer for worlds and player state. It intentionally stores
# only gameplay data and keeps files inside Godot's app-private user:// sandbox.
const SAVE_DIR := "user://Minecraft2/worlds"
const SAVE_FILE := SAVE_DIR + "/world_001.json"
const SAVE_VERSION := 1

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save_game(data: Dictionary) -> bool:
    DirAccess.make_dir_recursive_absolute(SAVE_DIR)
    var payload := data.duplicate(true)
    payload["save_version"] = SAVE_VERSION
    payload["saved_at"] = Time.get_datetime_string_from_system(true)
    var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload, "  "))
    file.close()
    return true

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_FILE):
        return {}
    var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    if int(parsed.get("save_version", 0)) != SAVE_VERSION:
        return {}
    return parsed

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_FILE)

func delete_save() -> void:
    if FileAccess.file_exists(SAVE_FILE):
        DirAccess.remove_absolute(SAVE_FILE)
