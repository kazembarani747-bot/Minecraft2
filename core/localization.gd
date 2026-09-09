class_name M2Localization
extends RefCounted

const LANGUAGE_FILE := "user://Minecraft2/config/language.cfg"
const DEFAULT_LANGUAGE := "fa"

var language := DEFAULT_LANGUAGE
var strings := {
    "fa": {
        "game_title": "ماینکرفت۲",
        "play": "بازی",
        "settings": "تنظیمات",
        "controls": "کنترل‌ها",
        "video": "تصویر و گرافیک",
        "audio": "صدا",
        "language": "زبان",
        "first_person": "اول‌شخص",
        "third_person": "سوم‌شخص",
        "touch_mode": "نوع کنترل لمسی",
        "joystick_tap": "جوی‌استیک و لمس برای تعامل",
        "joystick_crosshair": "جوی‌استیک و نشانه‌گیر",
        "dpad_tap": "دی‌پد و لمس برای تعامل",
        "commands": "دستورات",
        "close": "بستن",
        "back": "بازگشت",
        "persian_ready": "زبان فارسی فعال است"
    },
    "en": {
        "game_title": "Minecraft2",
        "play": "Play",
        "settings": "Settings",
        "controls": "Controls",
        "video": "Video & Graphics",
        "audio": "Audio",
        "language": "Language",
        "first_person": "First Person",
        "third_person": "Third Person",
        "touch_mode": "Touch Control",
        "joystick_tap": "Joystick & tap to interact",
        "joystick_crosshair": "Joystick & aim crosshair",
        "dpad_tap": "D-Pad & tap to interact",
        "commands": "Commands",
        "close": "Close",
        "back": "Back",
        "persian_ready": "Persian language is active"
    }
}

func load() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(LANGUAGE_FILE) == OK:
        language = str(cfg.get_value("language", "code", DEFAULT_LANGUAGE))
    if not strings.has(language):
        language = DEFAULT_LANGUAGE

func set_language(code: String) -> void:
    if not strings.has(code):
        return
    language = code
    var cfg := ConfigFile.new()
    cfg.set_value("language", "code", language)
    cfg.save(LANGUAGE_FILE)

func translate(key: String) -> String:
    var table: Dictionary = strings.get(language, strings[DEFAULT_LANGUAGE])
    return str(table.get(key, key))
