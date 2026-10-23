# gdlint: disable=max-line-length
class_name PostFX
extends CanvasLayer
## Screen-space finishing: vignette, animated grain, scanlines, a red
## low-health pulse and white/coloured impact flashes.

var _vignette: TextureRect
var _grain: TextureRect
var _scan: TextureRect
var _danger: TextureRect
var _flash: ColorRect
var _time: float = 0.0
var _flash_life: float = 0.0
var _flash_max: float = 1.0
var _danger_target: float = 0.0
var _grain_offset: float = 0.0


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var root := Control.new()
	UI.full_rect(root)
	add_child(root)
	_scan = _texture_rect(root, "res://res/textures/scanline.png", 0.10, TextureRect.STRETCH_SCALE)
	_vignette = _texture_rect(root, "res://res/textures/vignette.png", 0.72, TextureRect.STRETCH_SCALE)
	_danger = _texture_rect(root, "res://res/textures/vignette.png", 0.0, TextureRect.STRETCH_SCALE)
	_danger.modulate = Color(1.0, 0.18, 0.24, 0.0)
	_grain = _texture_rect(root, "res://res/textures/grain.png", 0.055, TextureRect.STRETCH_TILE)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	UI.full_rect(_flash)
	root.add_child(_flash)


func _texture_rect(parent: Node, path: String, alpha: float, mode: int) -> TextureRect:
	var rect := TextureRect.new()
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = mode
	rect.modulate = Color(1, 1, 1, alpha)
	UI.full_rect(rect)
	parent.add_child(rect)
	return rect


func _process(delta: float) -> void:
	_time += delta
	if _grain != null:
		_grain_offset += delta * 13.0
		_grain.position = Vector2(-fmod(_grain_offset, 96.0), -fmod(_grain_offset * 1.7, 96.0))
	if _flash_life > 0.0:
		_flash_life = maxf(0.0, _flash_life - delta)
		_flash.color.a = (_flash_life / maxf(0.01, _flash_max)) * 0.55
	else:
		_flash.color.a = 0.0
	if _danger != null:
		var pulse: float = 0.55 + 0.45 * sin(_time * 4.6)
		_danger.modulate.a = lerpf(_danger.modulate.a, _danger_target * pulse, clampf(delta * 5.0, 0.0, 1.0))


func flash(color: Color = Color(1, 1, 1), strength: float = 0.35, duration: float = 0.22) -> void:
	_flash.color = Color(color.r, color.g, color.b, strength)
	_flash_max = duration
	_flash_life = duration


func set_low_health(ratio: float) -> void:
	if ratio > 0.35:
		_danger_target = 0.0
	else:
		_danger_target = clampf((0.35 - ratio) / 0.35, 0.0, 1.0) * 0.55


func clear() -> void:
	_flash_life = 0.0
	_danger_target = 0.0
