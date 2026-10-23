# gdlint: disable=max-line-length,max-public-methods,max-file-lines
extends Node3D
## SINGULARITY: Vessel of the Fallen — 3D campaign director.
## Owns the run flow (title, stages, dialogues, crossroads, upgrades, boss,
## endings), spawns the 3D cast, and resolves all combat in the XZ arena.

const PLAYER_SCENE: PackedScene = preload("res://res/scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://res/scenes/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://res/scenes/boss.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://res/scenes/projectile.tscn")
const PICKUP_SCENE: PackedScene = preload("res://res/scenes/pickup.tscn")
const HAZARD_SCENE: PackedScene = preload("res://res/scenes/hazard.tscn")

const ENDING_IDS: Array[String] = ["seal", "sovereign", "dawn"]
const MISS_COLOR: Color = Color(0.92, 0.94, 1.0)

var run: RunState
var player: Player = null
var boss: Boss = null
var sara: HumanoidRig = null
var enemies: Array[Enemy] = []
var projectiles: Array[Projectile] = []
var pickups: Array[Pickup] = []
var hazards: Array[Hazard] = []
var stage_data: Dictionary = {}
var stage_index: int = 1
var state: String = "boot"

var spawn_timer: float = 0.0
var hazard_timer: float = 0.0
var pickup_timer: float = 0.0
var boss_timer: float = -1.0
var state_timer: float = 0.0
var awakening_shown: bool = false
var phase_two_shown: bool = false
var shake: float = 0.0
var last_note: String = ""
var touch_axis: Vector2 = Vector2.ZERO
var touch_buttons: Dictionary = {}
var autoplay: bool = false

var _hitstop_until: int = 0
var _ult_request: bool = false
var _slowmo_until: int = 0
var _title_clock: float = 0.0
var _autoplay_clock: float = 0.0
var _autoplay_logged: float = 0.0
var _autoplay_started: int = 0
var _autoplay_class_timer: float = 0.0

@onready var arena: Arena3D = $Arena
@onready var actors: Node3D = $Gameplay/Actors
@onready var props: Node3D = $Gameplay/Props
@onready var effects: Effects = $Gameplay/Effects
@onready var camera_rig: CameraRig = $CameraRig
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var hud: GameHUD = $HUD
@onready var menus: Menus = $Menus
@onready var dialogue: DialogueBox = $Dialogue
@onready var touch: TouchControls = $Touch
@onready var post_fx: PostFX = $PostFX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	run = RunState.new()
	run.name = "RunState"
	add_child(run)
	arena.setup(world_environment.environment, sun)
	_wire_ui()
	_wire_story()
	SaveManager.settings_changed.connect(_apply_settings)
	back_to_title()
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	if autoplay:
		_autoplay_started = Time.get_ticks_msec()
		print("AUTOPLAY: unattended 3D run starting")
		new_run()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ------------------------------------------------------------------ wiring
func _wire_ui() -> void:
	menus.new_run_requested.connect(new_run)
	menus.continue_requested.connect(continue_run)
	menus.resume_requested.connect(resume_play)
	menus.restart_stage_requested.connect(restart_stage)
	menus.title_requested.connect(back_to_title)
	menus.begin_stage_requested.connect(begin_stage_play)
	menus.victory_continue_requested.connect(_open_ending_choice)
	menus.quit_requested.connect(_quit_game)
	hud.pause_pressed.connect(pause_game)
	touch.axis_changed.connect(_on_touch_axis)
	touch.button_changed.connect(_on_touch_button)


func _wire_story() -> void:
	StoryManager.dialogue_started.connect(_on_dialogue_started)
	StoryManager.line_changed.connect(_on_dialogue_line)
	StoryManager.typing_updated.connect(_on_dialogue_typing)
	StoryManager.dialogue_finished.connect(_on_dialogue_finished)
	StoryManager.notification_requested.connect(_on_story_notification)
	dialogue.advance_requested.connect(_on_dialogue_advance)


func _on_dialogue_started(_lines: Array) -> void:
	dialogue.open()
	hud.set_gameplay_visible(false)
	touch.set_visible_controls(false)


func _on_dialogue_line(speaker: String, text: String) -> void:
	dialogue.set_line(speaker, text)


func _on_dialogue_typing(visible_text: String) -> void:
	dialogue.set_typing(visible_text)


func _on_dialogue_finished() -> void:
	dialogue.close()


func _on_story_notification(title: String, subtitle: String, seconds: float) -> void:
	hud.notify(title, subtitle, seconds)


func _on_dialogue_advance() -> void:
	StoryManager.advance()


func _on_touch_axis(axis: Vector2) -> void:
	touch_axis = axis


func _on_touch_button(button_name: String, pressed: bool) -> void:
	touch_buttons[button_name] = pressed
	if pressed and button_name == "class":
		cycle_class()
	elif pressed and button_name == "pause":
		pause_game()


func _apply_settings() -> void:
	var settings: Dictionary = SaveManager.settings
	AudioManager._apply_volumes()
	effects.set_reduced(not bool(settings.get("particles", true)))
	post_fx.set_low_health(0.0)
	if state == "play":
		touch.set_visible_controls(bool(settings.get("touch", true)))


# ------------------------------------------------------------------ title
func back_to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	state = "title"
	_clear_world()
	hud.set_gameplay_visible(false)
	hud.reset()
	dialogue.close()
	touch.set_visible_controls(false)
	arena.set_stage(1)
	arena.set_intensity(1.0)
	_title_clock = 0.0
	camera_rig.set_target(null)
	camera_rig.orbit(Vector3(0.0, 1.0, 0.0), 14.0, 17.0)
	AudioManager.play_music("title")
	menus.show_title({
		"best": SaveManager.best_score,
		"cleared": SaveManager.stages_cleared,
		"endings": SaveManager.endings_found(),
		"continue": not SaveManager.checkpoint.is_empty()
	})


# ------------------------------------------------------------------ run flow
func new_run() -> void:
	run.reset_run()
	SaveManager.clear_checkpoint()
	menus.hide_all()
	stage_index = 1
	_show_stage_intro(1)


func continue_run() -> void:
	var checkpoint: Dictionary = SaveManager.checkpoint
	if checkpoint.is_empty():
		new_run()
		return
	run.reset_run()
	run.set_score(int(checkpoint.get("score", 0)))
	stage_index = clampi(int(checkpoint.get("stage", 1)), 1, 3)
	_apply_continue_loadout(stage_index)
	menus.hide_all()
	_show_stage_intro(stage_index)


func _apply_continue_loadout(target_stage: int) -> void:
	for i in range(1, target_stage):
		if i == 1:
			run.apply_upgrade("power")
			run.apply_upgrade("vitality")
		else:
			run.apply_upgrade("current")
			run.apply_upgrade("mend")
	run.refresh_modifiers()


func _show_stage_intro(index: int) -> void:
	stage_index = clampi(index, 1, 3)
	state = "stage_intro"
	get_tree().paused = true
	_clear_world()
	run.stage_index = stage_index
	stage_data = GameConfig.stage_data(stage_index)
	arena.set_stage(stage_index)
	arena.set_intensity(1.0)
	hud.set_gameplay_visible(false)
	hud.reset()
	dialogue.close()
	touch.set_visible_controls(false)
	camera_rig.set_target(null)
	camera_rig.orbit(Vector3(0.0, 1.0, 0.0), 26.0, 16.0)
	menus.show_stage_intro(stage_index, last_note)
	last_note = ""
	AudioManager.play_music(_stage_theme())
	if autoplay:
		begin_stage_play.call_deferred()


func _stage_theme() -> String:
	match stage_index:
		1:
			return "campus"
		2:
			return "rift"
		_:
			return "boss"


func begin_stage_play() -> void:
	menus.hide_all()
	_prepare_stage()
	get_tree().paused = false
	if stage_index == 3 and not bool(run.flags.get("resolve_set", false)):
		run.flags["resolve_set"] = true
		_open_choice("resolve", _stage_three_dialogue)
	else:
		_stage_three_dialogue()


func _stage_three_dialogue() -> void:
	var key: String = "stage1_intro"
	if stage_index == 2:
		key = "stage2_intro"
	elif stage_index == 3:
		key = "stage3_intro"
	state = "story"
	_play_dialogue(key, _start_combat)


func _prepare_stage() -> void:
	_clear_world()
	stage_data = GameConfig.stage_data(stage_index)
	run.begin_stage(stage_index, 0)
	player = PLAYER_SCENE.instantiate() as Player
	actors.add_child(player)
	player.configure(run.modifiers)
	player.set_class(run.active_class)
	player.reset_for_stage(GameConfig.random_arena_point(3.0))
	_wire_player()
	spawn_timer = 1.2
	hazard_timer = float(stage_data.get("hazard_interval", 5.4))
	pickup_timer = 5.0
	boss_timer = 1.6 if stage_index == 3 else -1.0
	awakening_shown = false
	phase_two_shown = false
	effects.clear_all()
	hud.set_stage(stage_data)
	hud.set_gameplay_visible(true)
	hud.refresh(player, run, null)


func _wire_player() -> void:
	player.melee_swing.connect(_on_player_melee)
	player.shot_fired.connect(_on_player_shot)
	player.special_used.connect(_on_player_special)
	player.ult_used.connect(_on_player_ult)
	player.ally_shot.connect(_on_ally_shot)
	player.mend_used.connect(_on_player_mend)
	player.player_damaged.connect(_on_player_damaged)
	player.player_died.connect(_on_player_died)
	player.jumped.connect(_on_player_jump)
	player.dash_started.connect(_on_player_dash)
	player.class_changed.connect(_on_player_class_changed)


func _start_combat() -> void:
	state = "play"
	get_tree().paused = false
	menus.hide_all()
	hud.set_gameplay_visible(true)
	touch.set_visible_controls(bool(SaveManager.settings.get("touch", true)))
	camera_rig.set_target(player)
	camera_rig.snap_to_target()
	AudioManager.play_music(_stage_theme())
	var hint: String = "WASD move  ·  J attack  ·  K shot  ·  L special  ·  SHIFT dash  ·  1/2/3 class  ·  Q ultimate"
	hud.set_hint(hint)
	hud.notify(String(stage_data.get("name", "STAGE")), String(stage_data.get("objective", "")), 3.2)


func _resume_combat() -> void:
	state = "play"
	get_tree().paused = false
	hud.set_gameplay_visible(true)
	touch.set_visible_controls(bool(SaveManager.settings.get("touch", true)))
	camera_rig.set_target(player)


func resume_play() -> void:
	menus.hide_all()
	_resume_combat()


func pause_game() -> void:
	if state != "play":
		return
	state = "pause"
	get_tree().paused = true
	touch.set_visible_controls(false)
	menus.show_pause()


func restart_stage() -> void:
	menus.hide_all()
	_show_stage_intro(stage_index)
	begin_stage_play.call_deferred()


func _quit_game() -> void:
	AudioManager.stop_music()
	get_tree().quit()


# ------------------------------------------------------------------ class system
func switch_class(id: String) -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	if not run.switch_class(id):
		hud.notify("CLASS LOCKED", "Wait for the vessel to settle.", 1.2)
		return
	player.set_class(run.active_class)
	var info: Dictionary = run.class_def()
	effects.ring(player.position, 0.6, 3.4, info["color"], 0.6, 2.2)
	effects.burst(player.body_center(), info["color"], 26, 7.0, 0.6, 0.11, 2.0)
	post_fx.flash(info["color"], 0.22, 0.3)
	camera_rig.add_shake(0.25)
	AudioManager.play_sfx("select")
	hud.notify("CLASS  //  %s" % String(info["name"]), String(info["tag"]), 2.0)


func cycle_class() -> void:
	if not is_instance_valid(run):
		return
	var next: int = GameConfig.class_index(run.active_class) + 1
	switch_class(GameConfig.class_for_index(next))


func _on_player_class_changed(_id: String) -> void:
	player.configure(run.modifiers)


# ------------------------------------------------------------------ dialogue
func _play_dialogue(key: String, callback: Callable = Callable()) -> void:
	if autoplay:
		if callback.is_valid():
			callback.call()
		return
	var lines: Array = StoryManager.LINES.get(key, [])
	state = "story"
	get_tree().paused = true
	hud.set_gameplay_visible(false)
	touch.set_visible_controls(false)
	menus.hide_all()
	if lines.is_empty():
		get_tree().paused = false
		if callback.is_valid():
			callback.call()
		return
	StoryManager.start_dialogue(lines, func() -> void: _after_dialogue(callback))


func _after_dialogue(callback: Callable) -> void:
	get_tree().paused = false
	if callback.is_valid():
		callback.call()
	else:
		state = "play"
		hud.set_gameplay_visible(true)
		_apply_settings()


# ------------------------------------------------------------------ story beats
func _stage_cleared() -> void:
	if state != "play":
		return
	state = "story"
	var result: Dictionary = run.complete_stage()
	AudioManager.play_sfx("victory")
	AudioManager.play_music("victory")
	post_fx.flash(Color(0.9, 0.95, 1.0), 0.3, 0.5)
	camera_rig.add_shake(0.5)
	effects.ring(player.position, 1.0, 10.0, Color(0.75, 0.92, 1.0), 0.9, 3.0)
	effects.burst(player.body_center(), Color(0.8, 0.95, 1.0), 40, 9.0, 1.0, 0.12, 3.0)
	hud.notify("STAGE CLEAR", "+%d score" % (int(result["bonus"]) + int(result["flawless"])), 3.4)
	touch.set_visible_controls(false)
	for enemy in enemies:
		if is_instance_valid(enemy):
			effects.burst(enemy.body_center(), Color(0.7, 0.5, 1.0), 10, 5.0, 0.5, 0.1, 2.0)
			enemy.queue_free()
	enemies.clear()
	for hazard in hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	hazards.clear()
	if stage_index == 1:
		_play_dialogue("stage1_clear", _open_stage_crossroad)
	elif stage_index == 2:
		_play_dialogue("stage2_clear", _open_stage_crossroad)
	else:
		_show_victory()


func _open_stage_crossroad() -> void:
	if stage_index == 1:
		_open_choice("path", _after_stage_crossroad)
	else:
		_open_choice("allies", _after_stage_crossroad)


func _open_choice(key: String, next_action: Callable) -> void:
	if autoplay:
		var note: String = run.choose_crossroad(key, 0)
		if is_instance_valid(player):
			player.configure(run.modifiers)
		last_note = note
		print("AUTOPLAY: crossroad %s -> %s" % [key, note])
		_invoke_choice(next_action, key, 0)
		return
	state = "choice"
	get_tree().paused = true
	hud.set_gameplay_visible(false)
	touch.set_visible_controls(false)
	var data: Dictionary = StoryManager.crossroad(key)
	menus.show_choice(key, data, func(chosen_key: String, index: int) -> void:
		var note: String = run.choose_crossroad(chosen_key, index)
		if is_instance_valid(player):
			player.configure(run.modifiers)
			player.hp = minf(player.max_hp, player.hp + 18.0)
		AudioManager.play_sfx("select")
		post_fx.flash(Color(0.85, 0.75, 1.0), 0.22, 0.35)
		menus.hide_all()
		last_note = note
		hud.notify("CROSSROADS SET", note, 3.0)
		_invoke_choice(next_action, chosen_key, index)
	)


func _invoke_choice(action: Callable, key: String, index: int) -> void:
	if not action.is_valid():
		return
	if action.get_argument_count() >= 2:
		action.call(key, index)
	else:
		action.call()


func _after_stage_crossroad() -> void:
	var energy_now: int = int(player.energy) if is_instance_valid(player) else 0
	SaveManager.save_checkpoint(stage_index + 1, run.score, run.kills, energy_now, int(run.damage_taken), run.stage_time)
	stage_index += 1
	if stage_index > 3:
		stage_index = 3
	_open_upgrade(func() -> void: _show_stage_intro(stage_index))


# ------------------------------------------------------------------ upgrades
func _maybe_level_up() -> void:
	if state == "play" and run.pending_levels > 0:
		_open_upgrade()


func _open_upgrade(next_action: Callable = Callable()) -> void:
	if autoplay:
		_autoplay_upgrade(next_action)
		return
	if run.pending_levels <= 0:
		if next_action.is_valid():
			next_action.call()
		elif state == "play" or state == "upgrade":
			resume_play()
		return
	run.take_pending_level()
	state = "upgrade"
	get_tree().paused = true
	touch.set_visible_controls(false)
	var offers: Array[Dictionary] = run.offer_upgrades(3)
	menus.show_upgrade(offers, run.level, func(id: String) -> void: _on_upgrade_picked(id, next_action))


func _on_upgrade_picked(id: String, next_action: Callable) -> void:
	var note: String = run.apply_upgrade(id)
	if is_instance_valid(player):
		player.configure(run.modifiers)
		player.hp = minf(player.max_hp, player.hp + 12.0)
		player.energy = minf(player.max_energy, player.energy + 22.0)
		effects.ring(player.position, 0.8, 3.2, GameConfig.COL_GREEN, 0.5, 2.0)
	AudioManager.play_sfx("select")
	hud.notify("LEVEL %d" % run.level, note, 2.4)
	menus.hide_all()
	if run.pending_levels > 0:
		_open_upgrade(next_action)
	elif next_action.is_valid():
		next_action.call()
	else:
		resume_play()


# ------------------------------------------------------------------ boss / ending
func _on_player_died() -> void:
	if state != "play":
		return
	state = "dying"
	state_timer = 1.9
	AudioManager.stop_music()
	AudioManager.play_sfx("gameover")
	post_fx.flash(Color(1.0, 0.25, 0.3), 0.5, 0.7)
	camera_rig.add_shake(0.9)
	if is_instance_valid(player):
		effects.burst(player.body_center(), Color(1.0, 0.4, 0.45), 34, 8.0, 1.0, 0.12, 3.0)
		effects.ring(player.position, 0.6, 5.0, Color(1.0, 0.35, 0.45), 0.8, 3.0)


func _show_gameover() -> void:
	state = "gameover"
	get_tree().paused = true
	touch.set_visible_controls(false)
	hud.set_gameplay_visible(false)
	SaveManager.submit_score(run.score, run.combo_mult, false, maxi(0, stage_index - 1))
	SaveManager.add_kills(run.kills)
	if SaveManager.checkpoint.is_empty():
		SaveManager.save_checkpoint(stage_index, run.score, 0, 0, int(run.damage_taken), run.stage_time)
	menus.show_gameover(run.summary(), stage_index)
	if autoplay:
		_autoplay_end("gameover")


func _on_boss_defeated() -> void:
	if state != "play" and state != "story":
		return
	state = "story"
	run.boss_defeated()
	AudioManager.play_music("victory")
	AudioManager.play_sfx("victory")
	post_fx.flash(Color(1.0, 0.95, 0.75), 0.45, 0.9)
	camera_rig.add_shake(1.1)
	var center: Vector3 = boss.position if is_instance_valid(boss) else Vector3.ZERO
	effects.ring(center, 1.0, 16.0, Color(1.0, 0.85, 0.6), 1.1, 4.0)
	effects.burst(center + Vector3(0.0, 1.2, 0.0), Color(1.0, 0.9, 0.7), 48, 10.0, 1.3, 0.14, 2.0)
	touch.set_visible_controls(false)
	_play_dialogue("victory", _show_victory)


func _show_victory() -> void:
	state = "victory"
	get_tree().paused = true
	hud.set_gameplay_visible(false)
	menus.show_victory(run.summary())
	if autoplay:
		_open_ending_choice.call_deferred()


func _open_ending_choice() -> void:
	_open_choice("ending", _on_ending_chosen)


func _on_ending_chosen(_key: String, index: int) -> void:
	var ending_id: String = ENDING_IDS[clampi(index, 0, ENDING_IDS.size() - 1)]
	SaveManager.record_ending(ending_id)
	SaveManager.submit_score(run.score, run.combo_mult, true, 3)
	SaveManager.add_kills(run.kills)
	SaveManager.clear_checkpoint()
	AudioManager.play_music("victory")
	state = "ending"
	get_tree().paused = true
	menus.show_ending(StoryManager.ending(ending_id), run.summary(), SaveManager.endings_found(), 3)
	if autoplay:
		_autoplay_end("ending")


# ------------------------------------------------------------------ frame loop
func _process(delta: float) -> void:
	_release_time_fx()
	arena.pulse(delta)
	if autoplay:
		_autoplay_tick(delta)
	if get_tree().paused:
		return
	match state:
		"play":
			_tick_play(delta)
		"dying":
			state_timer -= delta
			if state_timer <= 0.0:
				_show_gameover()
		"title":
			_title_clock += delta
			if _title_clock > 14.0:
				_title_clock = 0.0
				camera_rig.orbit(Vector3(0.0, 1.0, 0.0), 14.0, 17.0)


func _tick_play(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	run.tick(delta)
	player.input = _gather_input()
	if is_instance_valid(boss):
		boss.player_pos = player.position
		boss.player_alive = player.alive
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.player_pos = player.position
			enemy.player_alive = player.alive
	_apply_separation(delta)
	_update_sara(delta)
	_tick_spawning(delta)
	_resolve_collisions()
	_cleanup()
	_check_stage_progress()
	hud.refresh(player, run, boss if is_instance_valid(boss) and boss.is_targetable() else null)
	post_fx.set_low_health(player.hp / maxf(1.0, player.max_hp))
	if stage_index == 1 and not awakening_shown and run.kills >= 5:
		awakening_shown = true
		_play_dialogue("awakening", _resume_combat)


func _gather_input() -> Dictionary:
	if autoplay:
		return _autoplay_input()
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		move.x -= 1.0
	if Input.is_action_pressed("move_right"):
		move.x += 1.0
	if Input.is_action_pressed("move_up"):
		move.y -= 1.0
	if Input.is_action_pressed("move_down"):
		move.y += 1.0
	move += touch_axis
	if move.length() > 1.0:
		move = move.normalized()
	var attack: bool = Input.is_action_pressed("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or bool(touch_buttons.get("attack", false))
	var shoot: bool = Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or bool(touch_buttons.get("shoot", false))
	var dash: bool = Input.is_action_pressed("dash") or bool(touch_buttons.get("dash", false))
	var special: bool = Input.is_action_pressed("special") or bool(touch_buttons.get("special", false))
	var heal_pressed: bool = Input.is_action_pressed("heal") or bool(touch_buttons.get("heal", false))
	var jump_pressed: bool = Input.is_action_pressed("jump") or bool(touch_buttons.get("jump", false))
	var ult_pressed: bool = _ult_request or bool(touch_buttons.get("ult", false))
	_ult_request = false
	return {
		"move": move,
		"attack": attack,
		"shoot": shoot,
		"dash": dash,
		"special": special,
		"heal": heal_pressed,
		"jump": jump_pressed,
		"ult": ult_pressed,
		"aim": _nearest_target_direction()
	}


func _nearest_target_direction() -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_distance: float = INF
	if is_instance_valid(player):
		if is_instance_valid(boss) and boss.is_targetable():
			var offset: Vector3 = boss.position - player.position
			offset.y = 0.0
			best = offset
			best_distance = offset.length()
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy.is_targetable():
				continue
			var to_enemy: Vector3 = enemy.position - player.position
			to_enemy.y = 0.0
			var distance: float = to_enemy.length()
			if distance < best_distance:
				best_distance = distance
				best = to_enemy
	return best.normalized() if best.length() > 0.01 else Vector3.ZERO


func _apply_separation(delta: float) -> void:
	var count: int = enemies.size()
	for i in count:
		var a: Enemy = enemies[i]
		if not is_instance_valid(a) or not a.is_targetable():
			continue
		var push := Vector3.ZERO
		for j in count:
			if i == j:
				continue
			var b: Enemy = enemies[j]
			if not is_instance_valid(b):
				continue
			var offset: Vector3 = a.position - b.position
			offset.y = 0.0
			var minimum: float = float(GameConfig.ENEMY_SEPARATION_3D)
			if offset.length() < minimum and offset.length() > 0.01:
				push += offset.normalized() * (minimum - offset.length()) * 0.5
		if push.length() > 0.001:
			a.apply_separation(push * clampf(delta * 6.0, 0.0, 1.0))


func _update_sara(delta: float) -> void:
	var ally_on: bool = bool(player.mods.get("ally", false))
	if not ally_on:
		if is_instance_valid(sara):
			sara.queue_free()
			sara = null
		return
	if not is_instance_valid(sara):
		sara = HumanoidRig.new()
		sara.build({
			"skin": Color(0.99, 0.85, 0.76),
			"hair": Color(0.82, 0.42, 0.6),
			"coat": Color(0.82, 0.88, 1.0),
			"trim": Color(1.0, 0.6, 0.8),
			"shirt": Color(1.0, 0.96, 0.98),
			"pants": Color(0.24, 0.22, 0.3),
			"eye": Color(1.0, 0.55, 0.8),
			"core": Color(1.0, 0.55, 0.82),
			"cape": Color(0.9, 0.9, 1.0),
			"hair_style": "long",
			"cape_on": false,
			"weapon": "",
			"scale": 0.94
		})
		actors.add_child(sara)
	var behind: Vector3 = player.position - player.facing * 1.5 + Vector3(-0.9, 0.0, 0.0)
	sara.position = sara.position.lerp(Vector3(behind.x, 0.0, behind.z), clampf(delta * 5.0, 0.0, 1.0))
	sara.rotation.y = lerp_angle(sara.rotation.y, player.rig.rotation.y if is_instance_valid(player.rig) else 0.0, clampf(delta * 6.0, 0.0, 1.0))
	sara.animate(delta, "idle", 0.0)


func _tick_spawning(delta: float) -> void:
	if stage_index >= 3:
		if boss_timer > 0.0 and not is_instance_valid(boss):
			boss_timer -= delta
			if boss_timer <= 0.0:
				_spawn_boss()
		return
	var maximum: int = int(stage_data.get("max_enemies", 6))
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		if enemies.size() < maximum:
			_spawn_wave()
			spawn_timer = float(stage_data.get("spawn_interval", 2.2)) * randf_range(0.82, 1.22)
		else:
			spawn_timer = 0.6
	if bool(stage_data.get("hazards", false)):
		hazard_timer -= delta
		if hazard_timer <= 0.0 and hazards.size() < GameConfig.HAZARD_MAX_ACTIVE:
			hazard_timer = float(stage_data.get("hazard_interval", GameConfig.HAZARD_INTERVAL))
			_spawn_ground_hazard()
	pickup_timer -= delta
	if pickup_timer <= 0.0:
		pickup_timer = GameConfig.PICKUP_INTERVAL * randf_range(1.1, 1.6)
		if pickups.size() < GameConfig.PICKUP_MAX_ACTIVE:
			var kind: String = "heal" if player.hp < player.max_hp * 0.45 else "energy"
			_spawn_pickup(kind, GameConfig.random_arena_point(3.0))


func _spawn_wave() -> void:
	var advanced: float = float(stage_data.get("advanced_chance", 0.0))
	var brute: float = float(stage_data.get("brute_chance", 0.0))
	var type_id: String = "grunt"
	var roll: float = randf()
	if roll < brute:
		type_id = "brute"
	elif roll < brute + advanced:
		type_id = "stalker"
	var point: Vector3 = _spawn_point_away_from_player(9.0)
	_spawn_enemy(type_id, point)
	if stage_index >= 2 and randf() < 0.35:
		_spawn_enemy("grunt", _spawn_point_away_from_player(9.0))


func _spawn_point_away_from_player(min_distance: float) -> Vector3:
	for i in 14:
		var point: Vector3 = GameConfig.random_arena_point(2.0)
		if not is_instance_valid(player) or point.distance_to(player.position) >= min_distance:
			return point
	return GameConfig.random_arena_point(2.0)


func _spawn_enemy(type_id: String, point: Vector3) -> Enemy:
	var base: Dictionary = GameConfig.ENEMY_TYPES.get(type_id, GameConfig.ENEMY_TYPES["grunt"])
	var stats: Dictionary = base.duplicate()
	stats["hp"] = float(stats.get("hp", 34.0)) * float(stage_data.get("hp_mul", 1.0))
	stats["speed"] = float(stats.get("speed", 104.0)) * float(stage_data.get("speed_mul", 1.0))
	stats["damage"] = float(stats.get("damage", 8.0)) * float(stage_data.get("damage_mul", 1.0))
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(type_id, stats, point)
	actors.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.shot_requested.connect(_on_enemy_shot)
	effects.ring(point, 0.2, 2.2, Color(0.6, 0.3, 1.0), 0.5, 1.6)
	enemies.append(enemy)
	return enemy


func _spawn_boss() -> void:
	if is_instance_valid(boss):
		return
	boss = BOSS_SCENE.instantiate() as Boss
	actors.add_child(boss)
	boss.setup(Vector3(0.0, 0.0, -4.0))
	boss.projectile_requested.connect(_on_boss_projectile)
	boss.hazard_requested.connect(_on_boss_hazard)
	boss.summon_requested.connect(_on_boss_summon)
	boss.phase_changed.connect(_on_boss_phase)
	boss.defeated.connect(_on_boss_defeated)
	camera_rig.add_shake(0.7)
	post_fx.flash(Color(0.8, 0.3, 0.6), 0.3, 0.6)
	AudioManager.play_sfx("phase")


func _on_boss_phase(new_phase: int) -> void:
	state = "play"
	phase_two_shown = true
	camera_rig.add_shake(1.0)
	post_fx.flash(Color(1.0, 0.25, 0.45), 0.45, 0.7)
	effects.ring(boss.position if is_instance_valid(boss) else Vector3.ZERO, 1.0, 12.0, Color(1.0, 0.3, 0.5), 0.9, 3.0)
	hud.notify("PHASE II", "Katleen stops pretending.", 2.6)
	AudioManager.play_sfx("phase")
	if not autoplay and new_phase >= 2:
		_play_dialogue("boss_phase2", _resume_combat)


func _on_boss_projectile(origin: Vector3, dir: Vector3, damage: float, speed: float, radius_value: float, color: Color) -> void:
	_spawn_projectile("boss", origin, dir, damage, speed, 2.6, color, radius_value)
	AudioManager.play_sfx("orb")


func _on_boss_hazard(center: Vector3, radius_value: float, damage: float, warn: float, live: float, color: Color, kind: String) -> void:
	_spawn_hazard(center, radius_value, damage, warn, live, color, kind)
	if damage > 0.0:
		AudioManager.play_sfx("warning")


func _on_boss_summon(count: int) -> void:
	for i in count:
		var angle: float = TAU * float(i) / float(maxi(1, count)) + randf()
		var point: Vector3 = boss.position + Vector3(cos(angle) * 2.6, 0.0, sin(angle) * 2.6)
		_spawn_enemy("stalker" if randf() < 0.5 else "grunt", GameConfig.clamp_to_arena(point))
	AudioManager.play_sfx("awaken")


# ------------------------------------------------------------------ combat events
func _on_player_melee(center: Vector3, facing: Vector3, radius_value: float, damage: float, heavy: bool, up: bool) -> void:
	var color: Color = player.class_data.get("color", GameConfig.COL_BLUE)
	effects.slash(center, facing, color, radius_value, heavy, up)
	AudioManager.play_sfx("swing")
	var flat_facing := Vector3(facing.x, 0.0, facing.z).normalized()
	var applied: bool = false
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		var offset: Vector3 = enemy.body_center() - center
		var flat := Vector3(offset.x, 0.0, offset.z)
		var distance: float = flat.length()
		if distance > radius_value + enemy.radius:
			continue
		if distance > 0.2 and flat_facing.dot(flat.normalized()) < cos(deg_to_rad(GameConfig.MELEE_ARC_3D * 0.5)):
			continue
		var killed: bool = enemy.hurt(damage, player.position, heavy)
		effects.damage_number(enemy.body_center(), damage, GameConfig.COL_GOLD if heavy else MISS_COLOR, heavy)
		effects.sparks(enemy.body_center(), flat.normalized(), color, 10 if heavy else 6, 7.0)
		run.add_score(GameConfig.SCORE_DAMAGE_POINT * damage, false)
		player.add_ult(GameConfig.ULT_GAIN_HIT * (1.6 if heavy else 1.0))
		applied = true
		if killed:
			effects.burst(enemy.body_center(), Color(0.85, 0.6, 1.0), 18, 7.0, 0.6, 0.11, 3.0)
	if is_instance_valid(boss) and boss.is_targetable():
		var boss_offset: Vector3 = boss.body_center() - center
		var boss_flat := Vector3(boss_offset.x, 0.0, boss_offset.z)
		if boss_flat.length() <= radius_value + GameConfig.BOSS_RADIUS_3D:
			if boss_flat.length() <= 0.2 or flat_facing.dot(boss_flat.normalized()) >= cos(deg_to_rad(GameConfig.MELEE_ARC_3D * 0.5)):
				boss.hurt(damage, player.position, heavy)
				effects.damage_number(boss.body_center(), damage, GameConfig.COL_GOLD if heavy else MISS_COLOR, heavy)
				effects.sparks(boss.body_center(), flat_facing, color, 12, 8.0)
				run.add_score(GameConfig.SCORE_DAMAGE_POINT * damage, false)
				player.add_ult(GameConfig.ULT_GAIN_HIT * 1.4)
				applied = true
	if applied:
		_hit_feedback(heavy)


func _hit_feedback(heavy: bool) -> void:
	camera_rig.add_shake(0.35 if heavy else 0.16)
	AudioManager.play_sfx("crit" if heavy else "hit")
	if heavy:
		_hit_stop(0.05)


func _on_player_shot(origin: Vector3, dir: Vector3, damage: float) -> void:
	var color: Color = player.class_data.get("color", GameConfig.COL_BLUE)
	_spawn_projectile("player", origin, dir, damage, GameConfig.PROJECTILE_SPEED_3D, GameConfig.PROJECTILE_LIFE_3D, color, 0.2)
	run.shots_fired += 1
	AudioManager.play_sfx("shoot")
	effects.burst(origin, color, 4, 2.6, 0.25, 0.06, 0.0)


func _on_ally_shot(origin: Vector3, dir: Vector3, damage: float) -> void:
	_spawn_projectile("ally", origin, dir, damage, GameConfig.ALLY_SHOT_SPEED * 0.04, 1.2, Color(1.0, 0.6, 0.85), 0.16)
	AudioManager.play_sfx("orb")


func _on_player_special(center: Vector3, radius_value: float, damage: float) -> void:
	var color: Color = player.class_data.get("color", GameConfig.COL_GOLD)
	effects.ring(center, 0.6, radius_value * 1.6, color, 0.55, 3.0)
	effects.burst(center + Vector3(0.0, 1.0, 0.0), color, 44, 9.5, 0.6, 0.13, 2.0)
	camera_rig.add_shake(0.55)
	post_fx.flash(color, 0.18, 0.25)
	AudioManager.play_sfx("special")
	_run_aoe(center, radius_value, damage, color)


func _on_player_ult(center: Vector3, radius_value: float, damage: float, ability_name: String, color: Color) -> void:
	effects.ring(center, 1.0, radius_value * 1.8, color, 1.0, 4.0)
	effects.burst(center + Vector3(0.0, 1.2, 0.0), color, 70, 12.0, 1.1, 0.16, 1.5)
	camera_rig.add_shake(1.2)
	post_fx.flash(color, 0.55, 0.55)
	_slow_motion(0.45, 0.45)
	AudioManager.play_sfx("special")
	hud.notify(ability_name, "VESSEL ULTIMATE", 2.4)
	_run_aoe(center, radius_value, damage, color)


func _run_aoe(center: Vector3, radius_value: float, damage: float, color: Color) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		var offset: Vector3 = enemy.position - center
		offset.y = 0.0
		if offset.length() <= radius_value + enemy.radius:
			var killed: bool = enemy.hurt(damage, center, true)
			effects.damage_number(enemy.body_center(), damage, GameConfig.COL_GOLD, true)
			effects.sparks(enemy.body_center(), offset.normalized() if offset.length() > 0.01 else Vector3.FORWARD, color, 8, 8.0)
			if killed:
				player.add_ult(GameConfig.ULT_GAIN_KILL)
			else:
				player.add_ult(GameConfig.ULT_GAIN_HIT * 2.0)
	if is_instance_valid(boss) and boss.is_targetable():
		var boss_offset: Vector3 = boss.position - center
		boss_offset.y = 0.0
		if boss_offset.length() <= radius_value + GameConfig.BOSS_RADIUS_3D:
			boss.hurt(damage, center, true)
			effects.damage_number(boss.body_center(), damage, GameConfig.COL_GOLD, true)
			effects.sparks(boss.body_center(), Vector3.FORWARD, color, 14, 9.0)
	for projectile in projectiles:
		if not is_instance_valid(projectile) or not projectile.alive:
			continue
		if String(projectile.kind) == "enemy" or String(projectile.kind) == "boss":
			var shot_offset: Vector3 = projectile.position - center
			shot_offset.y = 0.0
			if shot_offset.length() <= radius_value:
				projectile.kill()
				effects.burst(projectile.position, color, 5, 4.0, 0.3, 0.08, 0.0)


func _on_player_mend(amount: float) -> void:
	effects.ring(player.position, 0.4, 2.8, GameConfig.COL_GREEN, 0.6, 2.0)
	effects.burst(player.body_center(), GameConfig.COL_GREEN, 14, 2.4, 0.8, 0.09, -2.0)
	effects.popup(player.body_center() + Vector3(0.0, 0.5, 0.0), "+%d" % int(amount), GameConfig.COL_GREEN, 52)
	AudioManager.play_sfx("pickup")


func _on_player_damaged(amount: float) -> void:
	run.take_damage(amount)
	post_fx.flash(Color(1.0, 0.25, 0.32), 0.28, 0.35)
	camera_rig.add_shake(0.45)
	AudioManager.play_sfx("hurt")
	effects.sparks(player.body_center(), Vector3.FORWARD, Color(1.0, 0.4, 0.45), 8, 5.0)


func _on_player_jump() -> void:
	AudioManager.play_sfx("jump")


func _on_player_dash(from_pos: Vector3, toward: Vector3) -> void:
	AudioManager.play_sfx("dash")
	effects.ring(from_pos, 0.3, 1.6, Color(0.7, 0.9, 1.0), 0.35, 1.4)
	effects.sparks(from_pos + Vector3(0.0, 1.0, 0.0), -toward, Color(0.75, 0.92, 1.0), 10, 4.0)
	camera_rig.add_shake(0.12)


func _on_enemy_shot(origin: Vector3, dir: Vector3, damage: float) -> void:
	_spawn_projectile("enemy", origin, dir, damage, 11.0, 2.4, Color(1.0, 0.35, 0.75), 0.22)
	AudioManager.play_sfx("orb")


func _on_enemy_died(enemy: Enemy) -> void:
	var stats: Dictionary = enemy.def
	var result: Dictionary = run.register_kill(stats)
	effects.burst(enemy.body_center(), Color(0.8, 0.55, 1.0), 20, 7.5, 0.7, 0.11, 2.5)
	effects.ring(enemy.position, 0.2, 1.8, Color(0.7, 0.45, 1.0), 0.45, 1.4)
	AudioManager.play_sfx("explode")
	_spawn_pickup("xp", enemy.position + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)))
	if randf() < float(stats.get("energy_drop", 0.55)):
		_spawn_pickup("energy", enemy.position + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)))
	if randf() < float(stats.get("core_drop", 0.05)):
		_spawn_pickup("core", enemy.position)
	player.add_ult(GameConfig.ULT_GAIN_KILL)
	if int(result.get("levels", 0)) > 0:
		hud.notify("LEVEL UP", "A new power surfaces.", 2.0)
	_maybe_level_up()


# ------------------------------------------------------------------ spawns
func _spawn_projectile(kind: String, origin: Vector3, dir: Vector3, damage: float, speed: float, life: float, color: Color, radius_value: float) -> void:
	if projectiles.size() > 90:
		return
	var shot: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	shot.setup(kind, origin, dir, damage, speed, life, color, radius_value)
	shot.effects = effects
	props.add_child(shot)
	projectiles.append(shot)


func _spawn_pickup(kind: String, point: Vector3) -> void:
	if pickups.size() >= GameConfig.PICKUP_MAX_ACTIVE + 6:
		return
	var pickup: Pickup = PICKUP_SCENE.instantiate() as Pickup
	pickup.setup(kind, point)
	if is_instance_valid(player):
		pickup.target = player.position
	pickups.append(pickup)
	props.add_child(pickup)


func _spawn_hazard(center: Vector3, radius_value: float, damage: float, warn: float, live: float, color: Color, kind: String) -> void:
	if hazards.size() > GameConfig.HAZARD_MAX_ACTIVE + 6:
		return
	var hazard: Hazard = HAZARD_SCENE.instantiate() as Hazard
	hazard.setup(center, radius_value, damage, warn, live, color, kind)
	props.add_child(hazard)
	hazards.append(hazard)


func _spawn_ground_hazard() -> void:
	_spawn_hazard(
		_spawn_point_away_from_player(6.0),
		GameConfig.HAZARD_RADIUS_3D,
		GameConfig.HAZARD_DAMAGE,
		GameConfig.HAZARD_WARNING,
		GameConfig.HAZARD_ACTIVE,
		Color(1.0, 0.42, 0.36),
		"burn"
	)


# ------------------------------------------------------------------ collisions
func _resolve_collisions() -> void:
	if not is_instance_valid(player):
		return
	for shot in projectiles:
		if not is_instance_valid(shot) or not shot.alive:
			continue
		if String(shot.kind) in ["player", "ally"]:
			_check_player_shot(shot)
		else:
			_check_enemy_shot(shot)
	for pickup in pickups:
		if not is_instance_valid(pickup) or not pickup.alive:
			continue
		pickup.target = player.position
		var offset: Vector3 = pickup.position - player.position
		offset.y = 0.0
		if offset.length() < 1.1:
			_collect_pickup(pickup)
	for hazard in hazards:
		if not is_instance_valid(hazard) or not hazard.is_dangerous():
			continue
		var offset: Vector3 = player.position - hazard.position
		offset.y = 0.0
		if offset.length() <= hazard.radius and player.jump_h < 0.85:
			if player.take_damage(hazard.damage, hazard.position):
				hazard.consume()
				effects.burst(player.position + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.5, 0.4), 10, 4.0, 0.4, 0.09, 2.0)
	if not player.alive:
		return
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		var offset: Vector3 = enemy.position - player.position
		offset.y = 0.0
		if offset.length() < enemy.radius + 0.62:
			if player.take_damage(enemy.damage, enemy.position):
				effects.sparks(player.body_center(), offset.normalized() if offset.length() > 0.01 else Vector3.FORWARD, Color(1.0, 0.45, 0.5), 9, 5.0)
	if is_instance_valid(boss) and boss.is_targetable() and player.alive:
		var boss_offset: Vector3 = boss.position - player.position
		boss_offset.y = 0.0
		var contact: float = GameConfig.BOSS_RADIUS_3D + 0.7
		if boss_offset.length() < contact:
			player.take_damage(GameConfig.BOSS_CONTACT_DAMAGE if not boss.is_dashing() else 16.0, boss.position)


func _check_player_shot(shot: Projectile) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		if shot.position.distance_to(enemy.body_center()) <= enemy.radius + shot.radius_value + 0.18:
			enemy.hurt(shot.damage, shot.position, false)
			effects.damage_number(enemy.body_center(), shot.damage, MISS_COLOR, false)
			effects.burst(shot.position, Color(0.65, 0.92, 1.0), 7, 5.0, 0.35, 0.08, 2.0)
			shot.kill()
			if String(shot.kind) == "player":
				run.hits_landed += 1
				run.add_score(GameConfig.SCORE_DAMAGE_POINT * shot.damage, false)
				player.add_ult(GameConfig.ULT_GAIN_HIT)
			AudioManager.play_sfx("hit")
			return
	if is_instance_valid(boss) and boss.is_targetable():
		if shot.position.distance_to(boss.body_center()) <= GameConfig.BOSS_RADIUS_3D + shot.radius_value:
			boss.hurt(shot.damage, shot.position, false)
			effects.damage_number(boss.body_center(), shot.damage, MISS_COLOR, false)
			effects.burst(shot.position, Color(0.8, 0.9, 1.0), 7, 5.0, 0.35, 0.08, 2.0)
			shot.kill()
			if String(shot.kind) == "player":
				run.hits_landed += 1
				run.add_score(GameConfig.SCORE_DAMAGE_POINT * shot.damage, false)
				player.add_ult(GameConfig.ULT_GAIN_HIT)
			AudioManager.play_sfx("boss_hit")


func _check_enemy_shot(shot: Projectile) -> void:
	if not player.alive:
		return
	if shot.position.distance_to(player.body_center()) <= shot.radius_value + 0.55:
		if player.take_damage(shot.damage, shot.position):
			shot.kill()
			effects.burst(shot.position, Color(1.0, 0.5, 0.6), 9, 5.0, 0.4, 0.09, 2.0)


func _collect_pickup(pickup: Pickup) -> void:
	pickup.collect()
	match String(pickup.kind):
		"energy":
			player.add_energy(pickup.value)
			effects.popup(pickup.position, "+%d EN" % int(pickup.value), Color(0.4, 0.9, 1.0), 42)
		"heal":
			player.heal(pickup.value)
			effects.popup(pickup.position, "+%d HP" % int(pickup.value), GameConfig.COL_GREEN, 42)
		"core":
			player.add_energy(pickup.value)
			player.add_ult(12.0)
			run.add_score(GameConfig.SCORE_ORB * 2, false)
			effects.popup(pickup.position, "CORE", Color(1.0, 0.85, 0.5), 52)
		_:
			run.add_xp(int(pickup.value))
			run.add_score(GameConfig.SCORE_ORB * 0.4, false)
			effects.burst(pickup.position, Color(0.8, 0.6, 1.0), 5, 2.0, 0.4, 0.07, -1.5)
	player.add_ult(1.5)
	AudioManager.play_sfx("pickup")
	_maybe_level_up()


func _cleanup() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Enemy = enemies[i]
		if not is_instance_valid(enemy):
			enemies.remove_at(i)
			continue
		if enemy.finished():
			enemy.queue_free()
			enemies.remove_at(i)
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Projectile = projectiles[i]
		if not is_instance_valid(shot) or not shot.alive:
			if is_instance_valid(shot):
				shot.queue_free()
			projectiles.remove_at(i)
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Pickup = pickups[i]
		if not is_instance_valid(pickup) or not pickup.alive:
			if is_instance_valid(pickup):
				pickup.queue_free()
			pickups.remove_at(i)
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Hazard = hazards[i]
		if not is_instance_valid(hazard) or not hazard.alive:
			if is_instance_valid(hazard):
				hazard.queue_free()
			hazards.remove_at(i)


func _check_stage_progress() -> void:
	if state != "play":
		return
	if stage_index <= 2:
		var needed: int = int(stage_data.get("kills_needed", 0))
		var duration: float = float(stage_data.get("duration", 60.0))
		if run.kills >= needed or run.stage_time >= duration:
			_stage_cleared()


func _clear_world() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	projectiles.clear()
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	pickups.clear()
	for hazard in hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	hazards.clear()
	if is_instance_valid(boss):
		boss.queue_free()
	boss = null
	if is_instance_valid(sara):
		sara.queue_free()
	sara = null
	if is_instance_valid(player):
		player.queue_free()
	player = null
	if is_instance_valid(effects):
		effects.clear_all()
	touch_buttons.clear()


# ------------------------------------------------------------------ time feel
func _hit_stop(seconds: float) -> void:
	_hitstop_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	Engine.time_scale = 0.12


func _slow_motion(scale_value: float, seconds: float) -> void:
	_slowmo_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	Engine.time_scale = scale_value


func _release_time_fx() -> void:
	var now: int = Time.get_ticks_msec()
	if Engine.time_scale < 1.0 and now >= maxi(_hitstop_until, _slowmo_until):
		Engine.time_scale = 1.0


# ------------------------------------------------------------------ keyboard
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if dialogue.is_open():
			return
		if key == KEY_ESCAPE or key == KEY_P:
			if state == "play":
				pause_game()
			elif state == "pause":
				resume_play()
			elif menus.is_open() and state != "title":
				menus.back()
			get_viewport().set_input_as_handled()
		elif key == KEY_1:
			switch_class("vessel")
			get_viewport().set_input_as_handled()
		elif key == KEY_2:
			switch_class("blade")
			get_viewport().set_input_as_handled()
		elif key == KEY_3:
			switch_class("caster")
			get_viewport().set_input_as_handled()
		elif key == KEY_TAB:
			cycle_class()
			get_viewport().set_input_as_handled()
		elif key == KEY_Q:
			_ult_request = true
			get_viewport().set_input_as_handled()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			if menus.current_screen() == "title":
				new_run()
				get_viewport().set_input_as_handled()
		elif key == KEY_R and state == "gameover":
			restart_stage()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ autoplay
func _autoplay_input() -> Dictionary:
	var move := Vector2.ZERO
	var attack := false
	var shoot := false
	var dash := false
	var special := false
	var heal := false
	var ult := false
	var aim := Vector3.ZERO
	if is_instance_valid(player):
		var target: Vector3 = _autoplay_target()
		var to_target: Vector3 = target - player.position
		to_target.y = 0.0
		var distance: float = to_target.length()
		if distance > 0.05:
			var direction: Vector3 = to_target.normalized()
			aim = direction
			if distance > 2.1:
				move = Vector2(direction.x, direction.z)
			else:
				move = Vector2(-direction.x, -direction.z) * 0.35
		attack = distance < 3.0
		shoot = distance > 3.4 and distance < 22.0
		special = distance < 6.0 and player.energy > player.max_energy * 0.5
		heal = player.hp < player.max_hp * 0.45
		ult = player.ult_ready and distance < 9.0
		dash = player.hp < player.max_hp * 0.3 or distance > 14.0
	return {
		"move": move,
		"attack": attack,
		"shoot": shoot,
		"dash": dash,
		"special": special,
		"heal": heal,
		"jump": randf() < 0.004,
		"ult": ult,
		"aim": aim
	}


func _autoplay_target() -> Vector3:
	if is_instance_valid(boss) and boss.is_targetable():
		return boss.position
	var best: Vector3 = Vector3.ZERO
	var best_distance: float = INF
	if is_instance_valid(player):
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy.is_targetable():
				continue
			var distance: float = enemy.position.distance_to(player.position)
			if distance < best_distance:
				best_distance = distance
				best = enemy.position
	if best_distance == INF:
		return Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-5.0, 5.0))
	return best


func _autoplay_upgrade(next_action: Callable) -> void:
	if run.pending_levels <= 0:
		if next_action.is_valid():
			next_action.call()
		elif state == "play" or state == "upgrade":
			resume_play()
		return
	run.take_pending_level()
	var offers: Array[Dictionary] = run.offer_upgrades(3)
	var pick: String = "power"
	if not offers.is_empty():
		pick = String(offers[0].get("id", "power"))
	print("AUTOPLAY: level %d upgrade -> %s" % [run.level, pick])
	_on_upgrade_picked(pick, next_action)


func _autoplay_tick(delta: float) -> void:
	_autoplay_clock += delta
	_autoplay_class_timer += delta
	if _autoplay_class_timer > 18.0 and state == "play":
		_autoplay_class_timer = 0.0
		cycle_class()
	if _autoplay_clock - _autoplay_logged > 4.0:
		_autoplay_logged = _autoplay_clock
		var hp: float = 0.0
		var max_hp: float = 0.0
		if is_instance_valid(player):
			hp = player.hp
			max_hp = player.max_hp
		print("AUTOPLAY t=%.1f state=%s paused=%s ts=%.2f stage=%d class=%s hp=%.0f/%.0f kills=%d score=%d enemies=%d boss=%s" % [
			_autoplay_clock, state, str(get_tree().paused), Engine.time_scale, stage_index,
			run.active_class, hp, max_hp, run.kills, run.score, enemies.size(), str(is_instance_valid(boss))
		])
	var wall_seconds: float = float(Time.get_ticks_msec() - _autoplay_started) / 1000.0
	if wall_seconds > 300.0 or _autoplay_clock > 420.0:
		_autoplay_end("timeout")


func _autoplay_end(reason: String) -> void:
	print("AUTOPLAY_RESULT reason=%s stage=%d class=%s score=%d kills=%d level=%d endings=%d" % [
		reason, stage_index, run.active_class, run.score, run.kills, run.level, SaveManager.endings_found()
	])
	autoplay = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().quit(0)
