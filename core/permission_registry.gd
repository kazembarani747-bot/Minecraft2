class_name M2PermissionRegistry
extends RefCounted

const PERMISSIONS := {
    "audio": "Read/play game audio",
    "internet": "Access internet services",
    "microphone": "Capture microphone input",
    "local_network": "Discover/connect to local network peers",
    "filesystem": "Read/write the add-on sandbox",
    "world": "Read/change world data",
    "entities": "Create/change entities",
    "commands": "Register or execute commands",
    "ui": "Create UI surfaces"
}

var _grants: Dictionary = {}

func request(addon_id: String, permission: String) -> bool:
    if not PERMISSIONS.has(permission):
        return false
    if not _grants.has(addon_id):
        _grants[addon_id] = {}
    # Sensitive permissions default to denied. The UI can grant them explicitly.
    return bool(_grants[addon_id].get(permission, false))

func set_grant(addon_id: String, permission: String, granted: bool) -> void:
    if not PERMISSIONS.has(permission):
        return
    if not _grants.has(addon_id):
        _grants[addon_id] = {}
    _grants[addon_id][permission] = granted

func revoke_all(addon_id: String) -> void:
    _grants.erase(addon_id)

func permissions_for(addon_id: String) -> Dictionary:
    return _grants.get(addon_id, {}).duplicate(true)
