extends Node

var localization := M2Localization.new()

func _ready() -> void:
    localization.load()
    await get_tree().process_frame
    _install_language_button()

func _install_language_button() -> void:
    var panel := get_tree().current_scene.get_node_or_null("HUD/SettingsPanel")
    if panel == null or panel.get_node_or_null("LanguageButton") != null:
        return
    var button := Button.new()
    button.name = "LanguageButton"
    button.text = "زبان / Language"
    button.position = Vector2(318, 470)
    button.size = Vector2(270, 44)
    button.pressed.connect(_toggle_language)
    panel.add_child(button)

func _toggle_language() -> void:
    localization.set_language("en" if localization.language == "fa" else "fa")
    var panel := get_tree().current_scene.get_node_or_null("HUD/SettingsPanel")
    if panel:
        var header := panel.get_node_or_null("Label")
        if header:
            header.text = localization.tr("settings")
        var language_button := panel.get_node_or_null("LanguageButton")
        if language_button:
            language_button.text = "زبان / Language"
