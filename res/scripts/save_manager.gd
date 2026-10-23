extends Node
## Persists records, settings and campaign checkpoints to `user://save.cfg`.
## Every read is validated and every write is guarded, so a blocked or corrupt
## save file can never stop the game from running.

signal settings_changed

const SAVE_PATH: String = "user://save.cfg"

var best_score: int = 0
var best_combo: float = 1.0
var stages_cleared: int = 0
var kills: int = 0
var victories: int = 0
var endings: Dictionary = {}
var checkpoint: Dictionary = {}
var available: bool = true
var had_data: bool = false

var settings: Dictionary = {
	"sfx": true,
	"music": true,
	"shake": true,
	"reduced_fx": false,
	"touch": true
}


func _ready() -> void:
	load_game()


func load_game() -> void:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(SAVE_PATH):
		settings["touch"] = DisplayServer.is_touchscreen_available()
		return
	var err: int = cfg.load(SAVE_PATH)
	if err != OK:
		available = false
		return
	had_data = true
	best_score = maxi(0, int(cfg.get_value("records", "best_score", 0)))
	best_combo = clampf(float(cfg.get_value("records", "best_combo", 1.0)), 1.0, 99.0)
	stages_cleared = clampi(int(cfg.get_value("records", "stages_cleared", 0)), 0, 3)
	kills = maxi(0, int(cfg.get_value("records", "kills", 0)))
	victories = maxi(0, int(cfg.get_value("records", "victories", 0)))
	var saved_endings: Variant = cfg.get_value("records", "endings", {})
	if saved_endings is Dictionary:
		endings = saved_endings.duplicate()
	var saved_settings: Variant = cfg.get_value("settings", "values", {})
	if saved_settings is Dictionary:
		for key in settings.keys():
			if saved_settings.has(key) and typeof(saved_settings[key]) == TYPE_BOOL:
				settings[key] = saved_settings[key]
	var cp: Variant = cfg.get_value("progress", "checkpoint", {})
	if cp is Dictionary and cp.has("stage"):
		var stage_num: int = clampi(int(cp.get("stage", 1)), 1, 3)
		checkpoint = {
			"stage": stage_num,
			"score": maxi(0, int(cp.get("score", 0))),
			"kills": maxi(0, int(cp.get("kills", 0))),
			"energy": maxi(0, int(cp.get("energy", 0))),
			"damage": maxi(0, int(cp.get("damage", 0))),
			"time": maxf(0.0, float(cp.get("time", 0.0)))
		}


func persist() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("records", "best_combo", best_combo)
	cfg.set_value("records", "stages_cleared", stages_cleared)
	cfg.set_value("records", "kills", kills)
	cfg.set_value("records", "victories", victories)
	cfg.set_value("records", "endings", endings)
	cfg.set_value("settings", "values", settings)
	cfg.set_value("progress", "checkpoint", checkpoint)
	var err: int = cfg.save(SAVE_PATH)
	available = err == OK


func save_settings(new_settings: Dictionary) -> void:
	settings = new_settings.duplicate()
	persist()
	settings_changed.emit()


func set_setting(key: String, value: bool) -> void:
	settings[key] = value
	persist()
	settings_changed.emit()


func submit_score(score: int, combo: float, victory: bool, cleared: int) -> bool:
	var is_best: bool = score > best_score
	if is_best:
		best_score = score
	best_combo = maxf(best_combo, combo)
	stages_cleared = maxi(stages_cleared, cleared)
	if victory:
		victories += 1
	persist()
	return is_best


func add_kills(total: int) -> void:
	kills = maxi(kills, total)
	persist()


func save_checkpoint(
	stage_num: int, score: int, kill_count: int, energy: int, damage: int, time: float
) -> void:
	checkpoint = {
		"stage": clampi(stage_num, 1, 3),
		"score": score,
		"kills": kill_count,
		"energy": energy,
		"damage": damage,
		"time": time
	}
	persist()


func clear_checkpoint() -> void:
	checkpoint = {}
	persist()


func record_ending(id: String) -> void:
	endings[id] = true
	persist()


func endings_found() -> int:
	var total: int = 0
	for key in ["seal", "sovereign", "dawn"]:
		if endings.get(key, false):
			total += 1
	return total


func reset_records() -> void:
	best_score = 0
	best_combo = 1.0
	stages_cleared = 0
	kills = 0
	victories = 0
	endings = {}
	checkpoint = {}
	persist()
