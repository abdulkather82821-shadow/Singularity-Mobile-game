extends Node
## Procedurally generated soundtrack and sound effects.
## Streams live in `res/audio/`; if one is missing the game simply stays silent
## instead of crashing.

const SFX_FILES: Dictionary = {
	"ui": "res://res/audio/ui.wav",
	"select": "res://res/audio/select.wav",
	"swing": "res://res/audio/swing.wav",
	"hit": "res://res/audio/hit.wav",
	"crit": "res://res/audio/crit.wav",
	"shoot": "res://res/audio/shoot.wav",
	"special": "res://res/audio/special.wav",
	"dash": "res://res/audio/dash.wav",
	"jump": "res://res/audio/jump.wav",
	"hurt": "res://res/audio/hurt.wav",
	"pickup": "res://res/audio/pickup.wav",
	"core": "res://res/audio/core.wav",
	"awaken": "res://res/audio/awaken.wav",
	"boss": "res://res/audio/boss.wav",
	"boss_hit": "res://res/audio/boss_hit.wav",
	"phase": "res://res/audio/phase.wav",
	"gameover": "res://res/audio/gameover.wav",
	"victory": "res://res/audio/victory.wav",
	"stage": "res://res/audio/stage.wav",
	"warning": "res://res/audio/warning.wav",
	"explode": "res://res/audio/explode.wav",
	"orb": "res://res/audio/orb.wav"
}

const MUSIC_FILES: Dictionary = {
	"title": "res://res/audio/music_title.wav",
	"campus": "res://res/audio/music_campus.wav",
	"rift": "res://res/audio/music_rift.wav",
	"boss": "res://res/audio/music_boss.wav",
	"victory": "res://res/audio/music_victory.wav"
}

const SFX_POOL_SIZE: int = 10
const MUSIC_DB: float = -13.0
const SFX_DB: float = -6.0

var _sfx_streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer
var _current_theme: String = ""
var _available: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SFX_FILES.keys():
		var stream: Resource = _try_load(SFX_FILES[key])
		if stream != null:
			_sfx_streams[key] = stream
	for key in MUSIC_FILES.keys():
		var stream: Resource = _try_load(MUSIC_FILES[key])
		if stream != null:
			_music_streams[key] = stream
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	SaveManager.settings_changed.connect(_apply_volumes)
	_apply_volumes()


func _try_load(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res == null:
		_available = false
	return res


func _apply_volumes() -> void:
	if _music_player == null:
		return
	var music_on: bool = bool(SaveManager.settings.get("music", true))
	_music_player.volume_db = MUSIC_DB if music_on else -80.0
	if music_on and _current_theme != "":
		_music_player.stream_paused = false
	elif not music_on:
		_music_player.stream_paused = true


func play_sfx(name: String) -> void:
	if not bool(SaveManager.settings.get("sfx", true)):
		return
	if not _sfx_streams.has(name):
		return
	if _pool.is_empty():
		return
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	player.stream = _sfx_streams[name]
	player.volume_db = SFX_DB
	player.play()


func play_music(theme: String) -> void:
	if _music_player == null:
		return
	if theme == _current_theme and _music_player.playing:
		return
	_current_theme = theme
	if not _music_streams.has(theme):
		return
	_music_player.stream = _music_streams[theme]
	_music_player.volume_db = MUSIC_DB if bool(SaveManager.settings.get("music", true)) else -80.0
	_music_player.stream_paused = false
	_music_player.play()


func stop_music() -> void:
	_current_theme = ""
	if _music_player != null:
		_music_player.stop()


func _on_music_finished() -> void:
	# WAV imports do not loop by default, so loop the theme manually.
	if _current_theme != "" and _music_player.stream != null:
		_music_player.play()
