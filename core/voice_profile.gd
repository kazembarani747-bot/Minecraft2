class_name M2VoiceProfile
extends RefCounted

var enabled := false
var push_to_talk := true
var voice_activation := false
var proximity_enabled := true
var proximity_distance := 32.0
var input_volume := 1.0
var output_volume := 1.0
var quality := "adaptive"
var noise_suppression := true
var echo_cancellation := true
var spatial_audio := true
var underwater_filter := true
var per_player_volume: Dictionary = {}
var muted_players: Dictionary = {}

func set_player_volume(player_id: String, value: float) -> void:
    per_player_volume[player_id] = clamp(value, 0.0, 2.0)

func get_player_volume(player_id: String) -> float:
    return float(per_player_volume.get(player_id, 1.0))

func set_muted(player_id: String, muted: bool) -> void:
    muted_players[player_id] = muted

func is_muted(player_id: String) -> bool:
    return bool(muted_players.get(player_id, false))
