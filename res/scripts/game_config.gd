# gdlint: disable=max-line-length
extends Node
## Global tuning values for SINGULARITY: Vessel of the Fallen.
## Autoloaded as `GameConfig` — everything gameplay-facing lives here so the
## whole game can be balanced from one file.

# ---------------------------------------------------------------- view
const BASE_WIDTH: int = 1280
const BASE_HEIGHT: int = 720
const ARENA_TOP_RATIO: float = 0.455
const ARENA_BOTTOM_RATIO: float = 0.925
const ARENA_LEFT_RATIO: float = 0.045
const ARENA_RIGHT_RATIO: float = 0.955

# ---------------------------------------------------------------- player
const PLAYER_SPEED: float = 322.0
const PLAYER_SPEED_DEPTH: float = 0.18
const PLAYER_MAX_HP: int = 100
const PLAYER_MAX_ENERGY: float = 100.0
const ENERGY_REGEN: float = 10.0
const JUMP_VELOCITY: float = 780.0
const GRAVITY: float = 2350.0
const DASH_SPEED: float = 980.0
const DASH_DURATION: float = 0.17
const DASH_COOLDOWN: float = 1.35
const DASH_INVULN: float = 0.24
const MELEE_COOLDOWN: float = 0.32
const MELEE_DURATION: float = 0.20
const MELEE_DAMAGE: Array[float] = [15.0, 15.0, 24.0]
const MELEE_RANGE: float = 102.0
const SHOOT_COOLDOWN: float = 0.30
const SHOOT_COST: float = 7.0
const SHOOT_DAMAGE: float = 13.0
const PROJECTILE_SPEED: float = 760.0
const PROJECTILE_LIFE: float = 1.4
const SPECIAL_COST: float = 45.0
const SPECIAL_COOLDOWN: float = 2.4
const SPECIAL_DAMAGE: float = 36.0
const SPECIAL_RADIUS: float = 238.0
const SPECIAL_DURATION: float = 0.55
const INVULN_AFTER_HIT: float = 1.05
const HURT_KNOCKBACK: float = 240.0
const PLAYER_BODY_RADIUS: float = 22.0
const PLAYER_DEATH_DURATION: float = 1.6

# ---------------------------------------------------------------- enemies
const ENEMY_MAX_ACTIVE: int = 9
const ENEMY_MAX_ACTIVE_MOBILE: int = 7
const ENEMY_SPAWN_INTERVAL: float = 2.35
const ENEMY_SPAWN_VARIANCE: float = 0.55
const ENEMY_MATERIALIZE: float = 0.65
const ENEMY_SEPARATION: float = 46.0

const ENEMY_TYPES: Dictionary = {
	"grunt": {
		"hp": 34.0, "speed": 104.0, "damage": 8.0, "radius": 23.0,
		"contact_cd": 1.1, "score": 120, "xp": 14,
		"energy_drop": 0.55, "core_drop": 0.05, "height": 74.0
	},
	"stalker": {
		"hp": 28.0, "speed": 164.0, "damage": 10.0, "radius": 21.0,
		"contact_cd": 1.0, "score": 175, "xp": 19,
		"energy_drop": 0.60, "core_drop": 0.06, "height": 78.0,
		"shoot_cd": 2.5, "shoot_damage": 9.0, "prefer_range": 250.0
	},
	"brute": {
		"hp": 105.0, "speed": 62.0, "damage": 17.0, "radius": 33.0,
		"contact_cd": 1.35, "score": 330, "xp": 38,
		"energy_drop": 0.80, "core_drop": 0.16, "height": 112.0
	}
}

# ---------------------------------------------------------------- hazards / pickups
const HAZARD_INTERVAL: float = 5.2
const HAZARD_WARNING: float = 1.15
const HAZARD_ACTIVE: float = 0.55
const HAZARD_RADIUS: float = 74.0
const HAZARD_DAMAGE: float = 13.0
const HAZARD_MAX_ACTIVE: int = 6

const PICKUP_INTERVAL: float = 4.4
const PICKUP_ENERGY: float = 25.0
const PICKUP_HEAL: float = 14.0
const PICKUP_LIFE: float = 16.0
const PICKUP_MAX_ACTIVE: int = 9
const PICKUP_MAGNET: float = 120.0

# ---------------------------------------------------------------- boss
const BOSS_NAME: String = "KATLEEN"
const BOSS_HP: float = 1200.0
const BOSS_PHASE_THRESHOLD: float = 0.5
const BOSS_RADIUS: float = 46.0
const BOSS_CONTACT_DAMAGE: float = 7.0
const BOSS_CONTACT_CD: float = 1.2
const BOSS_INTRO_DURATION: float = 3.4
const BOSS_DEATH_DURATION: float = 2.6
const BOSS_PHASE2_SPEED: float = 1.28

const BOSS_MOVES: Dictionary = {
	"blast": {"windup": 0.85, "recover": 0.95, "cooldown": 2.6, "damage": 10.0, "shots": 4},
	"dash": {"windup": 0.80, "recover": 1.15, "cooldown": 3.5, "damage": 16.0, "speed": 900.0, "duration": 0.42},
	"nova": {"windup": 1.25, "recover": 0.90, "cooldown": 3.3, "damage": 15.0, "marks": 3},
	"barrage": {"windup": 1.00, "recover": 1.10, "cooldown": 4.4, "damage": 12.0, "marks": 4},
	"summon": {"windup": 1.10, "recover": 0.80, "cooldown": 7.5}
}

# ---------------------------------------------------------------- stages
const STAGES: Dictionary = {
	1: {
		"num": 1, "name": "THE AWAKENING", "sub": "PMIST CAMPUS - DUSK",
		"quote": "\"It all started at PMIST. The day the sky cracked.\"",
		"duration": 42.0, "kills_needed": 12, "spawn_interval": 2.25, "max_enemies": 6,
		"advanced_chance": 0.0, "brute_chance": 0.0, "hazards": false,
		"objective": "Defeat 12 wraiths and survive the courtyard.",
		"hp_mul": 0.9, "speed_mul": 0.92, "damage_mul": 0.85
	},
	2: {
		"num": 2, "name": "THE DIMENSIONAL RIFT", "sub": "CAMPUS - REALITY FRACTURED",
		"quote": "\"From your college to a broken world - every chapter is a wound.\"",
		"duration": 52.0, "kills_needed": 16, "spawn_interval": 1.95, "max_enemies": 8,
		"advanced_chance": 0.32, "brute_chance": 0.16, "hazards": true, "hazard_interval": 5.4,
		"objective": "Hold the rift: defeat 16 hostiles. Watch the burning ground.",
		"hp_mul": 1.05, "speed_mul": 1.02, "damage_mul": 0.95
	},
	3: {
		"num": 3, "name": "KATLEEN'S REALM", "sub": "BEYOND THE RIFT - THRONE OF GLASS",
		"quote": "\"You were born mortal. You will die a doorway.\"",
		"duration": 999.0, "kills_needed": 0, "spawn_interval": 999.0, "max_enemies": 4,
		"advanced_chance": 0.0, "brute_chance": 0.0, "hazards": true, "hazard_interval": 8.5,
		"objective": "Defeat Katleen. End the invasion.",
		"hp_mul": 1.0, "speed_mul": 1.0, "damage_mul": 1.0
	}
}

# ---------------------------------------------------------------- progression
const XP_BASE: int = 60
const XP_GROWTH: int = 46
const XP_MAX_LEVEL: int = 9
const XP_ORB: int = 7
const XP_STAGE_BONUS: int = 60
const XP_BOSS_BONUS: int = 160

const UPGRADES: Array[Dictionary] = [
	{
		"id": "power", "name": "Rift Edge", "icon": "*", "color": Color(0.56, 0.90, 1.0),
		"max": 5, "desc": "Melee and energy shots deal +12% damage."
	},
	{
		"id": "current", "name": "Vessel Current", "icon": "~", "color": Color(0.27, 0.86, 1.0),
		"max": 4, "desc": "Energy regenerates 25% faster."
	},
	{
		"id": "mend", "name": "Vessel Mend", "icon": "+", "color": Color(0.49, 1.0, 0.69),
		"max": 3, "desc": "Unlock Mend (H) and heal +14 more health."
	},
	{
		"id": "step", "name": "Phase Step", "icon": ">>", "color": Color(1.0, 0.60, 0.85),
		"max": 3, "desc": "Dash cools down 18% faster with longer invulnerability."
	},
	{
		"id": "vitality", "name": "Second Heart", "icon": "v", "color": Color(1.0, 0.48, 0.58),
		"max": 4, "desc": "+20 maximum health, granted immediately."
	},
	{
		"id": "burst", "name": "Singularity Core", "icon": "#", "color": Color(1.0, 0.81, 0.42),
		"max": 4, "desc": "Special burst hits +22% harder with a wider radius."
	},
	{
		"id": "flux", "name": "Rift Flux", "icon": "8", "color": Color(0.77, 0.36, 1.0),
		"max": 3, "desc": "+25 maximum energy and 12% cheaper shots."
	}
]

const HEAL_COST: float = 26.0
const HEAL_COOLDOWN: float = 6.5
const HEAL_AMOUNT: float = 22.0

# ---------------------------------------------------------------- ally
const ALLY_COOLDOWN: float = 2.4
const ALLY_DAMAGE: float = 11.0
const ALLY_SHOT_SPEED: float = 640.0
const ALLY_OFFSET: float = 0.085

# ---------------------------------------------------------------- combo / score
const COMBO_WINDOW: float = 2.6
const COMBO_PER_STEP: int = 10
const COMBO_MAX_MULT: float = 4.0
const COMBO_STEP_VALUE: float = 0.5

const SCORE_KILL: int = 120
const SCORE_ORB: int = 40
const SCORE_DAMAGE_POINT: float = 0.6
const SCORE_STAGE_CLEAR: int = 1500
const SCORE_FLAWLESS: int = 800
const SCORE_BOSS: int = 6000
const SCORE_SURVIVAL_PER_SEC: float = 2.0

# ---------------------------------------------------------------- effects
const MAX_PARTICLES: int = 320
const MAX_PARTICLES_REDUCED: int = 110
const MAX_FLOATERS: int = 26
const SHAKE_INTENSITY: float = 13.0
const HIT_STOP: float = 0.055

# ---------------------------------------------------------------- palettes
const COL_NAVY: Color = Color(0.02, 0.03, 0.08)
const COL_PURPLE: Color = Color(0.64, 0.36, 1.0)
const COL_VIOLET: Color = Color(0.38, 0.15, 0.79)
const COL_BLUE: Color = Color(0.27, 0.86, 1.0)
const COL_GOLD: Color = Color(1.0, 0.75, 0.36)
const COL_PINK: Color = Color(1.0, 0.37, 0.82)
const COL_RED: Color = Color(1.0, 0.30, 0.43)
const COL_GREEN: Color = Color(0.35, 0.96, 0.69)
const COL_TEXT: Color = Color(0.93, 0.95, 1.0)
const COL_MUTED: Color = Color(0.62, 0.66, 0.82)

# ---------------------------------------------------------------- helpers
func arena_rect() -> Rect2:
	var size: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(BASE_WIDTH, BASE_HEIGHT)
	var left: float = size.x * ARENA_LEFT_RATIO
	var right: float = size.x * ARENA_RIGHT_RATIO
	var top: float = size.y * ARENA_TOP_RATIO
	var bottom: float = size.y * ARENA_BOTTOM_RATIO
	return Rect2(left, top, right - left, bottom - top)


func depth_scale(y: float, rect: Rect2) -> float:
	var t: float = clampf((y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
	return 0.72 + 0.46 * (t * t * (3.0 - 2.0 * t))


func stage_data(index: int) -> Dictionary:
	return STAGES.get(clampi(index, 1, 3), STAGES[1])


func upgrade_def(id: String) -> Dictionary:
	for def in UPGRADES:
		if def["id"] == id:
			return def
	return {}
