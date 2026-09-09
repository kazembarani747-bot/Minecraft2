class_name M2NpcMind
extends RefCounted

# Lightweight, deterministic mood model. It simulates reactions; it is not consciousness.
const MOODS := ["calm", "happy", "sad", "worried", "excited", "angry"]

var mood := "calm"
var mood_strength := 0.0
var trust: Dictionary = {}
var memory: Array[Dictionary] = []

func observe_player(player_id: String, event: String, intensity: float = 1.0) -> void:
    var amount: float = clampf(intensity, 0.0, 1.0)
    memory.push_back({"player": player_id, "event": event, "time": Time.get_ticks_msec()})
    if memory.size() > 32:
        memory.pop_front()
    match event:
        "kindness":
            mood = "happy"
            trust[player_id] = clamp(float(trust.get(player_id, 0.5)) + 0.08 * amount, 0.0, 1.0)
        "insult":
            mood = "sad"
            trust[player_id] = clamp(float(trust.get(player_id, 0.5)) - 0.08 * amount, 0.0, 1.0)
        "danger":
            mood = "worried"
        "victory":
            mood = "excited"
        _:
            mood = "calm"
    mood_strength = clamp(mood_strength * 0.7 + amount * 0.3, 0.0, 1.0)

func response_style() -> String:
    match mood:
        "sad": return "empathetic"
        "worried": return "reassuring"
        "happy", "excited": return "cheerful"
        "angry": return "firm"
        _: return "friendly"
