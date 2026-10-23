# gdlint: disable=max-line-length,max-public-methods,max-file-lines
extends Node2D
## Game director. Owns the run, the entity lists, wave spawning, collisions,
## the story flow and every transition between menus and combat.

const PLAYER_SCENE: PackedScene = preload("res://res/scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://res/scenes/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://res/scenes/boss.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://res/scenes/projectile.tscn")
const PICKUP_SCENE: PackedScene = preload("res://res/scenes/pickup.tscn")
const HAZARD_SCENE: PackedScene = preload("res://res/scenes/hazard.tscn")

const ENDING_IDS: Array[String] = ["seal", "sovereign", "dawn"]

var run: RunState
var player: Player = null
var boss: Boss = null
var enemies: Array[Enemy] = []
var projectiles: Array[Projectile] = []
var pickups: Array[Pickup] = []
var hazards: Array[Hazard] = []
var arena: Rect2 = Rect2(60, 300, 1160, 380)
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
var _hitstop_until: int = 0
var _title_clock: float = 0.0

@onready var stage_root: Node2D = $Stage
@onready var background: Backdrop = $Stage/Background
@onready var world: Node2D = $Stage/World
@onready var effects: Effects = $Stage/Effects
@onready var hud: GameHUD = $HUD
@onready var menus: Menus = $Menus
@onready var dialogue: DialogueBox = $Dialogue
@onready var touch: TouchControls = $Touch
@onready var post_fx: PostFX = $PostFX



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	arena = GameConfig.arena_rect()
	run = RunState.new()
	run.name = "RunState"
	add_child(run)
	_wire_ui()
	_wire_story()
	SaveManager.settings_changed.connect(_apply_settings)
	back_to_title()


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
	dialogue.advance_requested.connect(_on_dialogue_advance)


func _wire_story() -> void:
	StoryManager.dialogue_started.connect(_on_dialogue_started)
	StoryManager.line_changed.connect(_on_dialogue_line)
	StoryManager.typing_updated.connect(_on_dialogue_typing)
	StoryManager.dialogue_finished.connect(_on_dialogue_finished)
	StoryManager.notification_requested.connect(_on_story_notification)


func _on_dialogue_started(_lines: Array) -> void:
	dialogue.open()
	hud.set_gameplay_visible(false)


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
	if button_name == "pause" and pressed:
		if state == "play":
			pause_game()
		elif state == "pause":
			resume_play()


func _apply_settings() -> void:
	if touch == null:
		return
	var enabled: bool = bool(SaveManager.settings.get("touch", true)) and state == "play"
	touch.set_visible_controls(enabled)


# ------------------------------------------------------------------ title
func back_to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_clear_world()
	state = "title"
	hud.set_gameplay_visible(false)
	hud.reset()
	dialogue.close()
	touch.set_visible_controls(false)
	post_fx.clear()
	background.set_stage(1)
	background.set_intensity(1.0)
	AudioManager.play_music("title")
	_player_for_title()
	menus.show_title({
		"checkpoint_stage": int(SaveManager.checkpoint.get("stage", 0)),
		"best_score": SaveManager.best_score,
		"endings": SaveManager.endings_found()
	})


func _player_for_title() -> void:
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.configure(run.modifiers)
	player.reset_for_stage(arena, true)
	player.position = Vector2(arena.get_center().x, arena.position.y + arena.size.y * 0.74)
	player.invuln = 0.0
	player.input = {}
	player.set_process(false)


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
	background.set_stage(stage_index)
	background.set_intensity(1.0)
	hud.set_gameplay_visible(false)
	hud.reset()
	dialogue.close()
	touch.set_visible_controls(false)
	menus.show_stage_intro(stage_index, last_note)
	last_note = ""
	AudioManager.play_music(_stage_theme())


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
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.configure(run.modifiers)
	player.reset_for_stage(arena, true)
	_wire_player()
	awakening_shown = false
	phase_two_shown = false
	spawn_timer = 1.4
	hazard_timer = 4.5
	pickup_timer = 6.0
	boss_timer = 1.1 if stage_index == 3 else -1.0
	hud.reset()
	hud.set_stage(stage_data)
	hud.set_hint("WASD move  ·  J attack  ·  K shot  ·  L burst  ·  SPACE jump + SHIFT dash  ·  H mend")


func _wire_player() -> void:
	player.melee_swing.connect(_on_player_melee)
	player.shot_fired.connect(_on_player_shot)
	player.special_used.connect(_on_player_special)
	player.ally_shot.connect(_on_ally_shot)
	player.mend_used.connect(_on_player_mend)
	player.player_damaged.connect(_on_player_damaged)
	player.player_died.connect(_on_player_died)
	player.dash_started.connect(_on_player_dash)
	player.jumped.connect(_on_player_jump)


func _start_combat() -> void:
	state = "play"
	get_tree().paused = false
	menus.hide_all()
	hud.set_gameplay_visible(true)
	_apply_settings()
	if stage_index <= 2:
		hud.notify(String(stage_data.get("name", "STAGE")), String(stage_data.get("objective", "")), 3.0)
		AudioManager.play_sfx("stage")
	else:
		hud.notify("KATLEEN", "Sovereign of the rift", 3.0)
		AudioManager.play_music("boss")


func _resume_combat() -> void:
	state = "play"
	get_tree().paused = false
	menus.hide_all()
	hud.set_gameplay_visible(true)
	_apply_settings()


func resume_play() -> void:
	if state != "pause" and state != "upgrade":
		return
	menus.hide_all()
	get_tree().paused = false
	state = "play"
	hud.set_gameplay_visible(true)
	_apply_settings()


func pause_game() -> void:
	if state != "play":
		return
	state = "pause"
	get_tree().paused = true
	touch.set_visible_controls(false)
	menus.show_pause()
	AudioManager.play_sfx("ui")


func restart_stage() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	menus.hide_all()
	dialogue.close()
	state = "story"
	_prepare_stage()
	get_tree().paused = false
	_start_combat()


func _quit_game() -> void:
	AudioManager.stop_music()
	get_tree().quit()


# ------------------------------------------------------------------ dialogue
func _play_dialogue(key: String, callback: Callable = Callable()) -> void:
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
	AudioManager.play_music("title")
	for enemy in enemies:
		if is_instance_valid(enemy):
			effects.burst(enemy.body_center(), Color(1.0, 0.82, 0.5), 10, 200.0, 0.5, 3.0)
			enemy.queue_free()
	enemies.clear()
	for hazard in hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	hazards.clear()
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.queue_free()
	projectiles.clear()
	post_fx.flash(Color(1.0, 0.92, 0.62), 0.28, 0.4)
	hud.notify("STAGE CLEAR", "+%d score  ·  +%d flawless" % [int(result.get("bonus", 0)), int(result.get("flawless", 0))], 2.8)
	touch.set_visible_controls(false)
	var clear_key: String = "stage1_clear" if stage_index == 1 else "stage2_clear"
	_play_dialogue(clear_key, _open_stage_crossroad)


func _open_stage_crossroad() -> void:
	var key: String = "path" if stage_index == 1 else "allies"
	_open_choice(key, _after_stage_crossroad)


func _open_choice(key: String, next_action: Callable) -> void:
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
		if next_action.is_valid():
			next_action.call()
	)


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
		effects.ring(player.position, 8.0, 130.0, GameConfig.COL_GREEN, 0.5, 4.0)
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
	state_timer = 1.7
	AudioManager.stop_music()
	AudioManager.play_sfx("gameover")
	post_fx.flash(Color(1.0, 0.25, 0.3), 0.5, 0.6)
	shake = 18.0
	if is_instance_valid(player):
		effects.burst(player.body_center(), Color(1.0, 0.4, 0.45), 26, 320.0, 0.9, 4.0)
		effects.ring(player.position, 10.0, 220.0, Color(1.0, 0.35, 0.45), 0.7, 6.0)


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


func _on_boss_defeated() -> void:
	if state != "play":
		return
	state = "story"
	run.boss_defeated()
	AudioManager.play_music("victory")
	AudioManager.play_sfx("victory")
	post_fx.flash(Color(1.0, 0.95, 0.75), 0.45, 0.8)
	shake = 16.0
	effects.ring(boss.position if is_instance_valid(boss) else arena.get_center(), 20.0, 420.0, Color(1.0, 0.85, 0.6), 1.1, 8.0)
	effects.burst(boss.position if is_instance_valid(boss) else arena.get_center(), Color(1.0, 0.9, 0.7), 40, 340.0, 1.2, 4.0)
	touch.set_visible_controls(false)
	_play_dialogue("victory", _show_victory)


func _show_victory() -> void:
	state = "victory"
	get_tree().paused = true
	hud.set_gameplay_visible(false)
	menus.show_victory(run.summary())


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


# ------------------------------------------------------------------ frame loop
func _process(delta: float) -> void:
	_release_hitstop()
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
			background.set_focus(0.5 + sin(_title_clock * 0.16) * 0.28)
	_update_shake(delta)


func _tick_play(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	run.tick(delta)
	player.input = _gather_input()
	var focus: float = clampf((player.position.x - arena.position.x) / maxf(1.0, arena.size.x), 0.0, 1.0)
	background.set_focus(focus)
	if is_instance_valid(boss):
		boss.player_pos = player.position
		boss.player_alive = player.alive
	_update_ally_target()
	_apply_separation(delta)
	_tick_spawning(delta)
	_resolve_collisions(delta)
	_cleanup()
	_check_stage_progress()
	hud.refresh(player, run, boss if is_instance_valid(boss) and boss.is_targetable() else null)
	post_fx.set_low_health(player.hp / maxf(1.0, player.max_hp))
	if stage_index == 1 and not awakening_shown and run.kills >= 5:
		awakening_shown = true
		_play_dialogue("awakening", _resume_combat)


func _gather_input() -> Dictionary:
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
	return {
		"move": move,
		"attack": attack,
		"shoot": shoot,
		"dash": dash,
		"special": special,
		"heal": heal_pressed,
		"jump": jump_pressed
	}


func _update_ally_target() -> void:
	if not is_instance_valid(player):
		return
	var best = null
	var best_distance: float = 1e9
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_targetable():
			var distance: float = enemy.position.distance_to(player.position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	if is_instance_valid(boss) and boss.is_targetable():
		best = boss
	if best != null:
		player.set_ally_target(best.body_center(), true)
	else:
		player.set_ally_target(Vector2.ZERO, false)


func _apply_separation(delta: float) -> void:
	for i in enemies.size():
		var a: Enemy = enemies[i]
		if not is_instance_valid(a):
			continue
		var push := Vector2.ZERO
		for j in enemies.size():
			if i == j:
				continue
			var b: Enemy = enemies[j]
			if not is_instance_valid(b) or not b.is_targetable():
				continue
			var offset: Vector2 = a.position - b.position
			var min_distance: float = (a.radius + b.radius) * 0.82
			if offset.length() < min_distance and offset.length() > 0.01:
				push += offset.normalized() * (min_distance - offset.length()) * 0.5
		if push != Vector2.ZERO:
			a.apply_separation(push * clampf(delta * 6.0, 0.0, 1.0))


func _tick_spawning(delta: float) -> void:
	if stage_index <= 2:
		var max_active: int = int(stage_data.get("max_enemies", 6))
		if DisplayServer.is_touchscreen_available():
			max_active = mini(max_active, GameConfig.ENEMY_MAX_ACTIVE_MOBILE)
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			if enemies.size() < max_active:
				_spawn_wave()
				spawn_timer = float(stage_data.get("spawn_interval", 2.3)) * randf_range(0.82, 1.2)
			else:
				spawn_timer = 0.6
		if bool(stage_data.get("hazards", false)):
			hazard_timer -= delta
			if hazard_timer <= 0.0 and hazards.size() < GameConfig.HAZARD_MAX_ACTIVE:
				hazard_timer = float(stage_data.get("hazard_interval", GameConfig.HAZARD_INTERVAL)) * randf_range(0.85, 1.15)
				_spawn_ground_hazard()
	else:
		if boss_timer > 0.0:
			boss_timer -= delta
			if boss_timer <= 0.0:
				_spawn_boss()
	pickup_timer -= delta
	if pickup_timer <= 0.0 and pickups.size() < GameConfig.PICKUP_MAX_ACTIVE:
		pickup_timer = GameConfig.PICKUP_INTERVAL * randf_range(0.85, 1.2)
		var kind: String = "heal" if player.hp < player.max_hp * 0.45 else "energy"
		_spawn_pickup(kind, _random_arena_point(140.0))


func _spawn_wave() -> void:
	var roll: float = randf()
	var type_id: String = "grunt"
	if roll < float(stage_data.get("brute_chance", 0.0)):
		type_id = "brute"
	elif roll < float(stage_data.get("brute_chance", 0.0)) + float(stage_data.get("advanced_chance", 0.0)):
		type_id = "stalker"
	var point: Vector2 = _spawn_point_away_from_player(260.0)
	_spawn_enemy(type_id, point)
	if stage_index >= 2 and randf() < 0.28:
		_spawn_enemy("grunt", _spawn_point_away_from_player(240.0))


func _spawn_enemy(type_id: String, point: Vector2) -> void:
	if not GameConfig.ENEMY_TYPES.has(type_id):
		return
	var base: Dictionary = GameConfig.ENEMY_TYPES[type_id]
	var scaled: Dictionary = base.duplicate()
	scaled["hp"] = float(base.get("hp", 34.0)) * float(stage_data.get("hp_mul", 1.0))
	scaled["speed"] = float(base.get("speed", 100.0)) * float(stage_data.get("speed_mul", 1.0))
	scaled["damage"] = float(base.get("damage", 8.0)) * float(stage_data.get("damage_mul", 1.0))
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	world.add_child(enemy)
	enemy.setup(type_id, scaled, point, arena)
	enemy.died.connect(_on_enemy_died)
	enemy.shot_requested.connect(_on_enemy_shot)
	enemies.append(enemy)
	effects.ring(point, 6.0, 70.0, Color(0.62, 0.4, 1.0), 0.5, 3.0)


func _spawn_boss() -> void:
	if is_instance_valid(boss):
		return
	boss = BOSS_SCENE.instantiate()
	world.add_child(boss)
	boss.setup(arena)
	boss.projectile_requested.connect(_on_boss_projectile)
	boss.hazard_requested.connect(_on_boss_hazard)
	boss.summon_requested.connect(_on_boss_summon)
	boss.phase_changed.connect(_on_boss_phase)
	boss.defeated.connect(_on_boss_defeated)
	hud.notify("KATLEEN", "Sovereign of the rift", 3.0)
	AudioManager.play_music("boss")
	AudioManager.play_sfx("warning")
	post_fx.flash(Color(0.8, 0.45, 1.0), 0.3, 0.5)
	shake = 12.0


func _on_boss_phase(_phase: int) -> void:
	if phase_two_shown:
		return
	phase_two_shown = true
	AudioManager.play_sfx("phase")
	post_fx.flash(Color(1.0, 0.55, 0.7), 0.4, 0.55)
	shake = 14.0
	if is_instance_valid(boss):
		effects.ring(boss.position, 10.0, 380.0, Color(1.0, 0.45, 0.65), 0.8, 7.0)
	_hitstop(0.12)
	_play_dialogue("boss_phase2", func() -> void:
		state = "play"
		get_tree().paused = false
		hud.set_gameplay_visible(true)
		hud.notify("PHASE II", "Katleen draws on the rift itself", 2.6)
		_apply_settings()
	)


func _on_boss_projectile(origin: Vector2, dir: Vector2, damage: float, speed: float, radius: float, color: Color) -> void:
	_spawn_projectile("boss", origin, dir, damage, speed, 4.0, color, radius)


func _on_boss_hazard(center: Vector2, radius: float, damage: float, warn: float, live: float, color: Color, kind: String) -> void:
	_spawn_hazard(center, radius, damage, warn, live, color, kind)


func _on_boss_summon(count: int) -> void:
	AudioManager.play_sfx("warning")
	for i in count:
		var angle: float = TAU * float(i) / float(maxi(1, count)) + randf() * 0.5
		var point: Vector2 = boss.position + Vector2(cos(angle), sin(angle) * 0.5) * 210.0
		point.x = clampf(point.x, arena.position.x + 60.0, arena.end.x - 60.0)
		point.y = clampf(point.y, arena.position.y + 30.0, arena.end.y - 40.0)
		_spawn_enemy("stalker" if i % 2 == 0 else "grunt", point)


# ------------------------------------------------------------------ combat events
func _on_player_melee(center: Vector2, radius: float, damage: float, facing: float, heavy: bool, up: bool) -> void:
	effects.slash(center, facing, Color(0.78, 0.98, 1.0), radius, up)
	AudioManager.play_sfx("swing")
	var connected: bool = false
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		if enemy.body_center().distance_to(center) <= radius + enemy.radius:
			var direction: Vector2 = (enemy.position - player.position).normalized()
			enemy.hurt(damage, player.position, heavy)
			effects.damage_number(enemy.body_center(), damage, GameConfig.COL_GOLD if heavy else Color(0.95, 0.98, 1.0), heavy)
			effects.sparks(enemy.body_center(), direction, Color(0.85, 0.95, 1.0), 7, 280.0)
			connected = true
	if is_instance_valid(boss) and boss.is_targetable():
		if boss.body_center().distance_to(center) <= radius + GameConfig.BOSS_RADIUS:
			boss.hurt(damage * (1.0 if not heavy else 1.1), player.position, heavy)
			effects.damage_number(boss.body_center(), damage, GameConfig.COL_GOLD, heavy)
			effects.sparks(boss.body_center(), Vector2(facing, -0.2), Color(1.0, 0.8, 1.0), 10, 320.0)
			connected = true
	if connected:
		AudioManager.play_sfx("crit" if heavy else "hit")
		_hitstop(0.05 if not heavy else 0.08)
		shake = maxf(shake, 5.0 if not heavy else 9.0)
		run.add_score(float(GameConfig.SCORE_DAMAGE_POINT) * damage * 2.0, false)


func _on_player_shot(origin: Vector2, dir: Vector2, damage: float) -> void:
	_spawn_projectile("player", origin, dir, damage, GameConfig.PROJECTILE_SPEED, GameConfig.PROJECTILE_LIFE, Color(0.42, 0.92, 1.0), 9.0)
	run.shots_fired += 1
	AudioManager.play_sfx("shoot")
	effects.sparks(origin, dir, Color(0.45, 0.95, 1.0), 3, 150.0)


func _on_ally_shot(origin: Vector2, dir: Vector2, damage: float) -> void:
	_spawn_projectile("ally", origin, dir, damage, GameConfig.ALLY_SHOT_SPEED, 1.8, Color(1.0, 0.55, 0.9), 7.0)
	AudioManager.play_sfx("shoot")


func _on_player_special(center: Vector2, radius: float, damage: float) -> void:
	AudioManager.play_sfx("special")
	post_fx.flash(Color(1.0, 0.85, 0.5), 0.20, 0.35)
	shake = maxf(shake, 11.0)
	effects.ring(center, 12.0, radius, Color(1.0, 0.86, 0.52), 0.55, 7.0)
	effects.ring(center, 6.0, radius * 0.7, Color(1.0, 0.95, 0.85), 0.4, 4.0)
	effects.burst(center, Color(1.0, 0.85, 0.5), 26, 320.0, 0.65, 3.4)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_targetable():
			if enemy.body_center().distance_to(center) <= radius + enemy.radius:
				enemy.hurt(damage, center, true)
				effects.damage_number(enemy.body_center(), damage, GameConfig.COL_GOLD, true)
	if is_instance_valid(boss) and boss.is_targetable():
		if boss.body_center().distance_to(center) <= radius + GameConfig.BOSS_RADIUS:
			boss.hurt(damage, center, true)
	for shot in projectiles:
		if is_instance_valid(shot) and String(shot.kind) in ["enemy", "boss"]:
			if shot.position.distance_to(center) <= radius:
				shot.alive = false
	_hitstop(0.07)


func _on_player_mend(_amount: float) -> void:
	AudioManager.play_sfx("core")
	effects.ring(player.position if is_instance_valid(player) else arena.get_center(), 8.0, 120.0, GameConfig.COL_GREEN, 0.5, 4.0)
	effects.burst(player.position if is_instance_valid(player) else arena.get_center(), GameConfig.COL_GREEN, 12, 150.0, 0.6, 3.0)


func _on_player_damaged(amount: float) -> void:
	AudioManager.play_sfx("hurt")
	run.take_damage(amount)
	shake = maxf(shake, 8.0)
	_hitstop(0.04)
	post_fx.flash(Color(1.0, 0.2, 0.28), 0.30, 0.3)
	if is_instance_valid(player):
		effects.burst(player.body_center(), Color(1.0, 0.35, 0.42), 12, 190.0, 0.5, 3.0)
	if player.hp < player.max_hp * 0.3:
		hud.notify("VESSEL FAILING", "Health critical - Mend or dash clear", 1.2)


func _on_player_jump() -> void:
	AudioManager.play_sfx("jump")


func _on_player_dash(from_pos: Vector2, toward: Vector2) -> void:
	AudioManager.play_sfx("dash")
	effects.burst(from_pos, Color(1.0, 0.65, 0.9), 8, 160.0, 0.35, 2.6)
	effects.beam(from_pos + Vector2(0, -40), toward + Vector2(0, -40), Color(1.0, 0.72, 0.92, 0.5), 5.0, 0.22)


func _on_enemy_shot(origin: Vector2, dir: Vector2, damage: float) -> void:
	_spawn_projectile("enemy", origin, dir, damage, 330.0, 3.2, Color(1.0, 0.45, 0.65), 9.0)
	AudioManager.play_sfx("orb")


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var stats: Dictionary = enemy.def
	var result: Dictionary = run.register_kill(stats)
	var center: Vector2 = enemy.body_center()
	effects.burst(center, Color(0.72, 0.5, 1.0), 10, 200.0, 0.5, 3.0)
	effects.burst(center, Color(1.0, 0.85, 0.9), 14, 230.0, 0.6, 3.2)
	effects.ring(enemy.position, 4.0, enemy.radius * 2.2, Color(0.78, 0.55, 1.0), 0.35, 3.0)
	effects.popup(center + Vector2(0, -16), "+%d" % int(result.get("score", 0)), GameConfig.COL_GOLD, 18)
	AudioManager.play_sfx("explode" if enemy.type_id == "brute" else "hit")
	_spawn_pickup("xp", enemy.position + Vector2(randf_range(-14, 14), randf_range(-8, 8)))
	if randf() < float(stats.get("energy_drop", 0.5)):
		_spawn_pickup("energy", enemy.position + Vector2(randf_range(-20, 20), randf_range(-12, 12)))
	if randf() < float(stats.get("core_drop", 0.05)):
		_spawn_pickup("core", enemy.position + Vector2(randf_range(-16, 16), randf_range(-8, 8)))
	if enemy.type_id == "brute":
		shake = maxf(shake, 9.0)
		post_fx.flash(Color(1.0, 0.8, 0.6), 0.16, 0.25)
	_maybe_level_up()


# ------------------------------------------------------------------ spawns
func _spawn_projectile(kind: String, origin: Vector2, dir: Vector2, damage: float, speed: float, life: float, color: Color, radius: float) -> void:
	var shot: Projectile = PROJECTILE_SCENE.instantiate()
	world.add_child(shot)
	shot.setup(kind, origin, dir, speed, damage, life, color, radius)
	shot.set_arena(arena)
	projectiles.append(shot)


func _spawn_pickup(kind: String, point: Vector2) -> void:
	var value: float = GameConfig.PICKUP_ENERGY
	var color: Color = Color(0.42, 0.86, 1.0)
	match kind:
		"heal":
			value = GameConfig.PICKUP_HEAL
			color = GameConfig.COL_GREEN
		"xp":
			value = float(GameConfig.XP_ORB)
			color = Color(1.0, 0.82, 0.45)
		"core":
			value = 45.0
			color = Color(1.0, 0.55, 0.85)
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	world.add_child(pickup)
	pickup.setup(kind, point, value, color)
	pickup.target = player.position if is_instance_valid(player) else point
	pickup.magnet_range = GameConfig.PICKUP_MAGNET * (1.6 if kind == "xp" else 1.0)
	pickups.append(pickup)


func _spawn_hazard(center: Vector2, radius: float, damage: float, warn: float, live: float, color: Color, kind: String) -> void:
	var hazard: Hazard = HAZARD_SCENE.instantiate()
	world.add_child(hazard)
	hazard.setup(center, radius, damage, warn, live, color, kind)
	hazard.arena = arena
	hazards.append(hazard)


func _spawn_ground_hazard() -> void:
	var point: Vector2 = _random_arena_point(90.0)
	_spawn_hazard(point, GameConfig.HAZARD_RADIUS, GameConfig.HAZARD_DAMAGE, GameConfig.HAZARD_WARNING, GameConfig.HAZARD_ACTIVE, Color(1.0, 0.42, 0.36), "burn")
	AudioManager.play_sfx("warning")


func _random_arena_point(margin: float) -> Vector2:
	return Vector2(
		randf_range(arena.position.x + margin, arena.end.x - margin),
		randf_range(arena.position.y + margin * 0.4, arena.end.y - margin * 0.6)
	)


func _spawn_point_away_from_player(min_distance: float) -> Vector2:
	for i in 12:
		var point: Vector2 = _random_arena_point(70.0)
		if not is_instance_valid(player) or point.distance_to(player.position) >= min_distance:
			return point
	return _random_arena_point(70.0)


# ------------------------------------------------------------------ collisions
func _resolve_collisions(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var player_center: Vector2 = player.body_center()
	for shot in projectiles:
		if not is_instance_valid(shot) or not shot.alive:
			continue
		if String(shot.kind) in ["player", "ally"]:
			_check_player_shot(shot)
		else:
			_check_enemy_shot(shot, player_center)
	for pickup in pickups:
		if not is_instance_valid(pickup) or not pickup.alive:
			continue
		pickup.target = player.position
		if pickup.position.distance_to(player.position) < 38.0:
			_collect_pickup(pickup)
	for hazard in hazards:
		if not is_instance_valid(hazard) or not hazard.is_dangerous():
			continue
		var offset: Vector2 = player.position - hazard.position
		var inside: bool = Vector2(offset.x, offset.y / 0.42).length() <= hazard.radius
		if offset.length() > hazard.radius * 1.25:
			inside = false
		if inside and (not player.airborne or player.jump_h < 46.0):
			if player.take_damage(hazard.damage, hazard.position):
				hazard.consume()
	if not player.alive:
		return
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		if enemy.body_center().distance_to(player_center) < enemy.radius + 26.0:
			if player.take_damage(enemy.damage, enemy.position):
				effects.sparks(player_center, (player.position - enemy.position).normalized(), Color(1.0, 0.4, 0.45), 8, 240.0)
	if is_instance_valid(boss) and boss.is_targetable() and player.alive:
		if boss.body_center().distance_to(player_center) < GameConfig.BOSS_RADIUS + 30.0:
			player.take_damage(GameConfig.BOSS_CONTACT_DAMAGE, boss.position)


func _check_player_shot(shot: Projectile) -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_targetable():
			continue
		if shot.position.distance_to(enemy.body_center()) <= enemy.radius + float(shot.radius) + 4.0:
			enemy.hurt(shot.damage, shot.position, false)
			effects.damage_number(enemy.body_center(), shot.damage, Color(0.9, 0.97, 1.0), false)
			effects.burst(shot.position, Color(0.6, 0.92, 1.0), 6, 160.0, 0.35, 2.4, 120.0)
			shot.alive = false
			if String(shot.kind) == "player":
				run.hits_landed += 1
				run.add_score(GameConfig.SCORE_DAMAGE_POINT * shot.damage, false)
			AudioManager.play_sfx("hit")
			return
	if is_instance_valid(boss) and boss.is_targetable():
		if shot.position.distance_to(boss.body_center()) <= GameConfig.BOSS_RADIUS + float(shot.radius) + 6.0:
			boss.hurt(shot.damage, shot.position, false)
			effects.damage_number(boss.body_center(), shot.damage, Color(0.9, 0.97, 1.0), false)
			effects.burst(shot.position, Color(0.75, 0.9, 1.0), 6, 170.0, 0.35, 2.4, 120.0)
			shot.alive = false
			if String(shot.kind) == "player":
				run.hits_landed += 1
				run.add_score(GameConfig.SCORE_DAMAGE_POINT * shot.damage, false)
			AudioManager.play_sfx("boss_hit")


func _check_enemy_shot(shot: Projectile, player_center: Vector2) -> void:
	if not player.alive:
		return
	if shot.position.distance_to(player_center) <= float(shot.radius) + 24.0:
		if player.take_damage(shot.damage, shot.position):
			shot.alive = false
			effects.burst(shot.position, Color(1.0, 0.5, 0.6), 8, 170.0, 0.4, 2.6)


func _collect_pickup(pickup: Pickup) -> void:
	if not is_instance_valid(pickup):
		return
	pickup.alive = false
	match String(pickup.kind):
		"heal":
			player.heal(pickup.amount)
			AudioManager.play_sfx("pickup")
			effects.popup(pickup.position, "+%d HP" % int(pickup.amount), GameConfig.COL_GREEN, 18)
			effects.ring(pickup.position, 4.0, 60.0, GameConfig.COL_GREEN, 0.3, 3.0)
		"energy":
			player.add_energy(pickup.amount)
			AudioManager.play_sfx("pickup")
			effects.popup(pickup.position, "+%d EN" % int(pickup.amount), Color(0.55, 0.9, 1.0), 16)
		"core":
			player.add_energy(pickup.amount)
			player.heal(6.0)
			run.add_score(float(GameConfig.SCORE_ORB), true)
			AudioManager.play_sfx("core")
			effects.popup(pickup.position, "RIFT CORE", GameConfig.COL_PINK, 18)
			post_fx.flash(Color(1.0, 0.6, 0.9), 0.12, 0.22)
		_:
			run.add_xp(int(pickup.amount))
			run.add_score(float(GameConfig.SCORE_ORB) * 0.5, false)
			AudioManager.play_sfx("pickup")
			_maybe_level_up()


func _cleanup() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Enemy = enemies[i]
		if not is_instance_valid(enemy) or enemy.finished():
			if is_instance_valid(enemy):
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


# ------------------------------------------------------------------ presentation helpers
func _hitstop(seconds: float) -> void:
	if bool(SaveManager.settings.get("reduced_fx", false)):
		return
	_hitstop_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	Engine.time_scale = 0.12


func _release_hitstop() -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0


func _update_shake(delta: float) -> void:
	if shake > 0.2 and bool(SaveManager.settings.get("shake", true)):
		stage_root.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
		shake = lerpf(shake, 0.0, clampf(delta * 7.0, 0.0, 1.0))
	else:
		stage_root.position = Vector2.ZERO
		shake = 0.0


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
	if is_instance_valid(player):
		player.queue_free()
	player = null
	if is_instance_valid(effects):
		effects.clear_all()
	touch_buttons.clear()


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
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			if menus.current_screen() == "title":
				new_run()
				get_viewport().set_input_as_handled()
		elif key == KEY_R and state == "gameover":
			restart_stage()
			get_viewport().set_input_as_handled()
