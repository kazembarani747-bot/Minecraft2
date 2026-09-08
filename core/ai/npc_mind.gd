class_name Minecraft2NpcMind
extends RefCounted

const MOODS := ["calm", "happy", "sad", "angry", "worried", "excited"]

var mood := "calm"
var mood_strength := 0.0
var trust: Dictionary = {}
var memories: Array[Dictionary] = []

func observe_player(player_id: String, event: String, intensity: float = 1.0) -> void:
    var value := clampf(intensity, 0.0, 1.0)
    match event:
        "kindness":
            _shift_trust(player_id, value * 0.08)
            _set_mood("happy", value)
        "insult":
            _shift_trust(player_id, -value * 0.10)
            _set_mood("sad", value)
        "help":
            _shift_trust(player_id, value * 0.12)
            _set_mood("excited", value)
        "danger":
            _set_mood("worried", value)
        _:
            _set_mood("calm", 0.05)
    memories.push_back({"player": player_id, "event": event, "intensity": value})
    if memories.size() > 32:
        memories.pop_front()

func comfort_player(player_id: String) -> String:
    var trust_value := float(trust.get(player_id, 0.0))
    if trust_value >= 0.25:
        return "I am here with you. You do not have to handle everything alone."
    return "It is okay to take a breath. I can stay here with you."

func get_state() -> Dictionary:
    return {"mood": mood, "mood_strength": mood_strength, "trust": trust.duplicate(true)}

func _shift_trust(player_id: String, amount: float) -> void:
    trust[player_id] = clampf(float(trust.get(player_id, 0.0)) + amount, -1.0, 1.0)

func _set_mood(new_mood: String, strength: float) -> void:
    if new_mood in MOODS:
        mood = new_mood
        mood_strength = clampf(strength, 0.0, 1.0)
