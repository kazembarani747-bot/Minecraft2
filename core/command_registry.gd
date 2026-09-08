class_name Minecraft2CommandRegistry
extends RefCounted

var commands: Dictionary = {}

func register(name: String, handler: Callable, description: String = "") -> void:
    var normalized := name.strip_edges().trim_prefix("/").to_lower()
    if normalized.is_empty():
        return
    commands[normalized] = {"handler": handler, "description": description}

func has(name: String) -> bool:
    return commands.has(name.strip_edges().trim_prefix("/").to_lower())

func execute(line: String) -> String:
    var source := line.strip_edges()
    if source.is_empty():
        return ""
    if source.begins_with("/"):
        source = source.substr(1)
    var parts := source.split(" ", false)
    if parts.is_empty():
        return ""
    var name := parts[0].to_lower()
    if not commands.has(name):
        return "Unknown command: /" + name
    var args: Array[String] = []
    for i in range(1, parts.size()):
        args.append(parts[i])
    var result = commands[name]["handler"].call(args)
    return str(result)

func help_lines() -> Array[String]:
    var names: Array[String] = []
    for name in commands.keys():
        names.append("/" + str(name))
    names.sort()
    return names
