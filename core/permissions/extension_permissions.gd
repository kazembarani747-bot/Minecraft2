class_name Minecraft2ExtensionPermissions
extends RefCounted

const PERMISSIONS := [
    "audio",
    "internet",
    "local_network",
    "microphone",
    "filesystem",
    "world",
    "entities",
    "commands",
    "ui"
]

var grants: Dictionary = {}

func request(extension_id: String, permission: String) -> bool:
    if permission not in PERMISSIONS:
        return false
    if not grants.has(extension_id):
        grants[extension_id] = {}
    # Permission decisions are intentionally explicit and persistent storage is added later.
    grants[extension_id][permission] = false
    return false

func grant(extension_id: String, permission: String) -> void:
    if permission not in PERMISSIONS:
        return
    if not grants.has(extension_id):
        grants[extension_id] = {}
    grants[extension_id][permission] = true

func revoke(extension_id: String, permission: String) -> void:
    if grants.has(extension_id):
        grants[extension_id].erase(permission)

func is_granted(extension_id: String, permission: String) -> bool:
    return bool(grants.get(extension_id, {}).get(permission, false))

func list_permissions(extension_id: String) -> Dictionary:
    return grants.get(extension_id, {}).duplicate(true)
