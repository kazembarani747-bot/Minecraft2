extends Node

func _ready() -> void:
    var runtime := Minecraft2Runtime.new()
    var report := runtime.bootstrap()
    print("Minecraft2 runtime API ", report["api_version"])
    print("Minecraft2 extension folders ready: ", report["mods_path"])
    if report["diagnostics"].size() > 0:
        for diagnostic in report["diagnostics"]:
            print("[Minecraft2] ", diagnostic)
