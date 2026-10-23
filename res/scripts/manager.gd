# gdlint: disable=max-public-methods
class_name RunState
extends Node
## Per-run progression: score, combo, experience, upgrades and story flags.
## The HUD and the player read their numbers from here, so one object owns
## every rule that shapes a run.

signal leveled_up(level: int)
signal upgraded(id: String, rank: int)
signal combo_changed(mult: float)
signal score_changed(score: int)

var stage_index: int = 1
var score: int = 0
var combo_mult: float = 1.0
var combo_timer: float = 0.0
var kills: int = 0
var kills_needed: int = 0
var stage_time: float = 0.0
var xp: int = 0
var level: int = 1
var xp_needed: int = 60
var pending_levels: int = 0
var upgrades: Dictionary = {}
var flags: Dictionary = {
	"scholar": false,
	"guardian": false,
	"ally": false,
	"lone_wolf": false,
	"faith": false,
	"rift_power": false,
	"resolve_set": false
}
var damage_taken: float = 0.0
var shots_fired: int = 0
var hits_landed: int = 0
var perfect_stage: bool = true
var modifiers: Dictionary = {}
var _score_float: float = 0.0


func _ready() -> void:
	reset_run()
	refresh_modifiers()


func reset_run() -> void:
	stage_index = 1
	score = 0
	_score_float = 0.0
	combo_mult = 1.0
	combo_timer = 0.0
	kills = 0
	kills_needed = 0
	stage_time = 0.0
	xp = 0
	level = 1
	xp_needed = xp_for_level(1)
	pending_levels = 0
	upgrades = {}
	damage_taken = 0.0
	shots_fired = 0
	hits_landed = 0
	perfect_stage = true
	for key in flags.keys():
		flags[key] = false
	refresh_modifiers()


func begin_stage(index: int, carried_kills: int = 0) -> void:
	stage_index = clampi(index, 1, 3)
	var data: Dictionary = GameConfig.stage_data(stage_index)
	kills = carried_kills
	kills_needed = int(data.get("kills_needed", 0))
	stage_time = 0.0
	perfect_stage = true
	damage_taken = 0.0
	refresh_modifiers()


func tick(delta: float) -> void:
	stage_time += delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0 and combo_mult > 1.0:
			combo_mult = 1.0
			combo_changed.emit(combo_mult)
	add_score(GameConfig.SCORE_SURVIVAL_PER_SEC * delta)


func set_score(value: int) -> void:
	score = maxi(0, value)
	_score_float = float(score)
	score_changed.emit(score)


func add_score(points: float, apply_combo: bool = false) -> void:
	var mult: float = combo_mult if apply_combo else 1.0
	_score_float += points * mult
	var rounded: int = int(round(_score_float))
	if rounded != score:
		score = rounded
		score_changed.emit(score)


func add_combo() -> void:
	combo_mult = minf(GameConfig.COMBO_MAX_MULT, combo_mult + GameConfig.COMBO_STEP_VALUE)
	combo_timer = GameConfig.COMBO_WINDOW
	combo_changed.emit(combo_mult)


func register_kill(enemy_def: Dictionary) -> Dictionary:
	kills += 1
	var base: int = int(enemy_def.get("score", GameConfig.SCORE_KILL))
	add_score(float(base), true)
	add_combo()
	var gain_xp: int = int(enemy_def.get("xp", 0))
	var levels: int = add_xp(gain_xp)
	return {"score": base, "xp": gain_xp, "levels": levels}


func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained: int = 0
	while level < GameConfig.XP_MAX_LEVEL and xp >= xp_needed:
		xp -= xp_needed
		level += 1
		gained += 1
		pending_levels += 1
		xp_needed = xp_for_level(level)
		leveled_up.emit(level)
	if level >= GameConfig.XP_MAX_LEVEL:
		xp = mini(xp, xp_needed)
	return gained


func xp_for_level(target_level: int) -> int:
	return GameConfig.XP_BASE + GameConfig.XP_GROWTH * maxi(0, target_level - 1)


func xp_ratio() -> float:
	return clampf(float(xp) / float(maxi(1, xp_needed)), 0.0, 1.0)


func upgrade_rank(id: String) -> int:
	return int(upgrades.get(id, 0))


func is_maxed(id: String) -> bool:
	var def: Dictionary = GameConfig.upgrade_def(id)
	return upgrade_rank(id) >= int(def.get("max", 1))


func take_pending_level() -> bool:
	if pending_levels <= 0:
		return false
	pending_levels -= 1
	return true


func offer_upgrades(count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for def in GameConfig.UPGRADES:
		if not is_maxed(String(def["id"])):
			pool.append(def)
	if pending_levels >= 2 and pool.size() > count:
		var trimmed: Array[Dictionary] = []
		for def in pool:
			if not String(def["id"]).begins_with("mend"):
				trimmed.append(def)
		pool = trimmed
	var offers: Array[Dictionary] = []
	while offers.size() < count and not pool.is_empty():
		var pick: int = randi() % pool.size()
		offers.append(pool[pick])
		pool.remove_at(pick)
	if offers.is_empty():
		offers.append({
			"id": "power", "name": "Rift Edge", "icon": "*", "max": 99,
			"color": GameConfig.COL_GOLD, "desc": "Already mastered - +150 score instead."
		})
	return offers


func apply_upgrade(id: String) -> String:
	var def: Dictionary = GameConfig.upgrade_def(id)
	upgrades[id] = upgrade_rank(id) + 1
	refresh_modifiers()
	upgraded.emit(id, upgrade_rank(id))
	var label: String = String(def.get("name", "Upgrade"))
	if id == "mend" and upgrade_rank(id) == 1:
		return "%s unlocked - press H to Mend" % label
	return "%s  -  rank %d" % [label, upgrade_rank(id)]


func refresh_modifiers() -> void:
	var dmg: float = 1.0
	dmg += 0.12 * float(upgrade_rank("power"))
	var max_hp: int = GameConfig.PLAYER_MAX_HP + 20 * upgrade_rank("vitality")
	var max_energy: float = GameConfig.PLAYER_MAX_ENERGY + 25.0 * float(upgrade_rank("flux"))
	var heal: float = GameConfig.HEAL_AMOUNT + 14.0 * float(upgrade_rank("mend"))
	if bool(flags["scholar"]):
		dmg += 0.25
	if bool(flags["lone_wolf"]):
		dmg += 0.18
	if bool(flags["faith"]):
		dmg += 0.06
		heal += 6.0
	if bool(flags["rift_power"]):
		dmg += 0.22
	if bool(flags["guardian"]):
		max_hp += 15
	if bool(flags["ally"]):
		max_hp += 20
	modifiers = {
		"damage_mul": dmg,
		"energy_regen_mul": 1.0 + 0.25 * float(upgrade_rank("current")),
		"dash_cd_mul": 0.82 ** float(upgrade_rank("step")),
		"invuln_bonus": 0.10 * float(upgrade_rank("step")),
		"max_hp_bonus": max_hp - GameConfig.PLAYER_MAX_HP,
		"max_hp": float(max_hp),
		"max_energy": max_energy,
		"heal_amount": heal,
		"heal_unlocked": upgrade_rank("mend") > 0,
		"special_mul": 1.0 + 0.22 * float(upgrade_rank("burst")),
		"special_radius_mul": 1.0 + 0.09 * float(upgrade_rank("burst")),
		"shoot_cost_mul": 1.0 - 0.12 * float(upgrade_rank("flux")),
		"ally": bool(flags["ally"]),
		"heal_cooldown": maxf(3.6, GameConfig.HEAL_COOLDOWN - 0.35 * float(upgrade_rank("mend")))
	}


func choose_crossroad(key: String, index: int) -> String:
	var note: String = ""
	match key:
		"path":
			if index == 0:
				flags["scholar"] = true
				flags["guardian"] = false
				note = "Scholar path - your burst burns 25% hotter."
			else:
				flags["guardian"] = true
				flags["scholar"] = false
				upgrades["mend"] = maxi(1, upgrade_rank("mend"))
				note = "Guardian path - Mend unlocked, +15 max health."
		"allies":
			if index == 0:
				flags["ally"] = true
				flags["lone_wolf"] = false
				note = "Sara joins the fight - support fire online."
			else:
				flags["lone_wolf"] = true
				flags["ally"] = false
				note = "You send them to shelter - strikes cut 18% deeper."
		"resolve":
			if index == 0:
				flags["faith"] = true
				flags["rift_power"] = false
				note = "Faith held - Mend heals more, +6% damage."
			else:
				flags["rift_power"] = true
				flags["faith"] = false
				note = "Rift power taken - +22% damage. It remembers you."
	refresh_modifiers()
	return note


func complete_stage() -> Dictionary:
	var bonus: int = GameConfig.SCORE_STAGE_CLEAR
	var flawless: int = 0
	if perfect_stage:
		flawless = GameConfig.SCORE_FLAWLESS
	add_score(float(bonus + flawless))
	var levels: int = add_xp(GameConfig.XP_STAGE_BONUS)
	return {"bonus": bonus, "flawless": flawless, "levels": levels}


func boss_defeated() -> void:
	add_score(float(GameConfig.SCORE_BOSS))
	add_xp(GameConfig.XP_BOSS_BONUS)


func take_damage(amount: float) -> void:
	damage_taken += amount
	if amount > 0.0:
		perfect_stage = false
	combo_mult = 1.0
	combo_timer = 0.0
	combo_changed.emit(combo_mult)


func accuracy() -> int:
	if shots_fired <= 0:
		return 0
	return int(round(100.0 * float(hits_landed) / float(shots_fired)))


func summary() -> Dictionary:
	return {
		"score": score,
		"kills": kills,
		"level": level,
		"accuracy": accuracy(),
		"time": stage_time,
		"damage": int(round(damage_taken)),
		"combo": combo_mult
	}
