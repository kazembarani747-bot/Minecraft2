class_name M2FeatureRegistry
extends RefCounted

var _features: Dictionary = {}

func register_feature(id: String, version: String, enabled := true, metadata: Dictionary = {}) -> void:
    _features[id] = {"version": version, "enabled": enabled, "metadata": metadata.duplicate(true)}

func has_feature(id: String) -> bool:
    return _features.has(id)

func is_enabled(id: String) -> bool:
    return _features.has(id) and bool(_features[id]["enabled"])

func set_enabled(id: String, enabled: bool) -> void:
    if _features.has(id):
        _features[id]["enabled"] = enabled

func get_feature(id: String) -> Dictionary:
    return _features.get(id, {}).duplicate(true)

func list_features() -> Dictionary:
    return _features.duplicate(true)
