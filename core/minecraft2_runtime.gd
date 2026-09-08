class_name Minecraft2Runtime
extends RefCounted

const GAME_DIR := "user://Minecraft2"
const MODS_DIR := GAME_DIR + "/mods"
const RESOURCE_PACKS_DIR := GAME_DIR + "/resource_packs"
const BEHAVIOR_PACKS_DIR := GAME_DIR + "/behavior_packs"
const WORLDS_DIR := GAME_DIR + "/worlds"
const CONFIG_DIR := GAME_DIR + "/config"
const CACHE_DIR := GAME_DIR + "/cache"
const LOG_DIR := GAME_DIR + "/logs"
const INTERNAL_API_VERSION := "1.0.0"

var block_registry: Dictionary = {}
var item_registry: Dictionary = {}
var entity_registry: Dictionary = {}
var command_registry: Dictionary = {}
var loaded_extensions: Array[String] = []
var diagnostics: Array[String] = []

func bootstrap() -> Dictionary:
    _ensure_directories()
    _ensure_default_files()
    _register_builtin_api()
    _scan_extensions()
    return {
        "api_version": INTERNAL_API_VERSION,
        "mods_path": MODS_DIR,
        "resource_packs_path": RESOURCE_PACKS_DIR,
        "behavior_packs_path": BEHAVIOR_PACKS_DIR,
        "loaded_extensions": loaded_extensions.duplicate(),
        "diagnostics": diagnostics.duplicate()
    }

func _ensure_directories() -> void:
    for path in [GAME_DIR, MODS_DIR, RESOURCE_PACKS_DIR, BEHAVIOR_PACKS_DIR, WORLDS_DIR, CONFIG_DIR, CACHE_DIR, LOG_DIR]:
        DirAccess.make_dir_recursive_absolute(path)

func _ensure_default_files() -> void:
    _write_if_missing(CONFIG_DIR + "/runtime.json", JSON.stringify({
        "api_version": INTERNAL_API_VERSION,
        "auto_repair": true,
        "auto_create_missing_api": true,
        "allow_external_extensions": true,
        "version": "0.3.0"
    }, "  "))
    _write_if_missing(LOG_DIR + "/bootstrap.log", "Minecraft2 runtime bootstrap started.\n")

func _write_if_missing(path: String, content: String) -> void:
    if FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(content)
        file.close()

func _register_builtin_api() -> void:
    # Built-in compatibility surface. External extensions target this stable layer
    # instead of depending directly on Godot internals.
    register_block("minecraft2:air", {"solid": false, "texture_size": 16})
    register_block("minecraft2:grass", {"solid": true, "texture_size": 16})
    register_block("minecraft2:dirt", {"solid": true, "texture_size": 16})
    register_block("minecraft2:stone", {"solid": true, "texture_size": 16})
    register_item("minecraft2:stick", {"stack": 64, "texture_size": 16})
    register_entity("minecraft2:player", {"type": "player"})
    register_entity("minecraft2:pig", {"type": "mob"})
    register_entity("minecraft2:zombie", {"type": "mob"})
    register_command("help", "Show registered commands")
    register_command("gamemode", "Change game mode")
    register_command("give", "Give an item")
    register_command("tp", "Teleport an entity")
    register_command("summon", "Summon an entity")
    register_command("setblock", "Change a block")
    register_command("fill", "Fill a region")
    register_command("execute", "Run a command with context")
    register_command("time", "Change world time")
    register_command("weather", "Change weather")
    register_command("scoreboard", "Manage scoreboards")
    register_command("function", "Run a function file")

func register_block(identifier: String, definition: Dictionary) -> void:
    block_registry[identifier] = definition.duplicate(true)

func register_item(identifier: String, definition: Dictionary) -> void:
    item_registry[identifier] = definition.duplicate(true)

func register_entity(identifier: String, definition: Dictionary) -> void:
    entity_registry[identifier] = definition.duplicate(true)

func register_command(name: String, description: String) -> void:
    command_registry[name] = description

func _scan_extensions() -> void:
    _scan_directory(MODS_DIR, "mods")
    _scan_directory(RESOURCE_PACKS_DIR, "resource_packs")
    _scan_directory(BEHAVIOR_PACKS_DIR, "behavior_packs")

func _scan_directory(path: String, kind: String) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        diagnostics.append("Could not open " + kind + ": " + path)
        return
    dir.list_dir_begin()
    while true:
        var entry := dir.get_next()
        if entry == "":
            break
        if dir.current_is_dir():
            continue
        var lower := entry.to_lower()
        if lower.ends_with(".jar"):
            loaded_extensions.append(kind + ":" + entry)
            diagnostics.append("Java extension detected: " + entry + " (compatibility bridge required)")
        elif lower.ends_with(".json") or lower.ends_with(".mcfunction"):
            loaded_extensions.append(kind + ":" + entry)
    dir.list_dir_end()

func command_help() -> Array[String]:
    var names: Array[String] = []
    for key in command_registry.keys():
        names.append("/" + str(key))
    names.sort()
    return names

func capability_report() -> Dictionary:
    return {
        "api": INTERNAL_API_VERSION,
        "blocks": block_registry.size(),
        "items": item_registry.size(),
        "entities": entity_registry.size(),
        "commands": command_registry.size(),
        "extensions": loaded_extensions.duplicate(),
        "diagnostics": diagnostics.duplicate()
    }
