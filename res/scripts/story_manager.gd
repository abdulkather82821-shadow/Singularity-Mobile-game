# gdlint: disable=max-line-length
extends Node
## Owns the narrative: dialogue playback with a typewriter effect, story
## crossroads, upgrades and the three endings.

signal dialogue_started(lines: Array)
signal line_changed(speaker: String, text: String)
signal typing_updated(visible_text: String)
signal dialogue_finished
signal notification_requested(title: String, subtitle: String, seconds: float)

const TYPE_SPEED: float = 54.0

const SPEAKERS: Dictionary = {
	"Ajees": {"color": Color(0.50, 0.89, 1.0), "narration": false},
	"Sara": {"color": Color(1.0, 0.60, 0.85), "narration": false},
	"Bala": {"color": Color(0.62, 0.71, 1.0), "narration": false},
	"Manmohan": {"color": Color(1.0, 0.76, 0.48), "narration": false},
	"Gokul": {"color": Color(0.61, 1.0, 0.77), "narration": false},
	"Prince": {"color": Color(1.0, 0.88, 0.40), "narration": false},
	"Katleen": {"color": Color(0.89, 0.65, 1.0), "narration": false},
	"narrator": {"color": Color(0.66, 0.71, 0.87), "narration": true}
}

const LINES: Dictionary = {
	"stage1_intro": [
		{"sp": "narrator", "text": "PMIST campus. 6:42 PM. The last bell had already rung."},
		{"sp": "Ajees", "text": "Another ordinary evening... so why is the sky cracking open?"},
		{"sp": "Sara", "text": "Ajees! Get back - something is coming through that rift!"},
		{"sp": "Ajees", "text": "Then I am not running. Not this time."}
	],
	"awakening": [
		{"sp": "narrator", "text": "The rift's energy pours into him - and something inside answers."},
		{"sp": "Ajees", "text": "It is not crushing me. It is... waiting for me."},
		{"sp": "Sara", "text": "Your eyes - Ajees, they are glowing!"},
		{"sp": "Ajees", "text": "I can hold it. I am the vessel now."}
	],
	"stage1_clear": [
		{"sp": "Prince", "text": "Dude. Did you just punch a hole in reality?"},
		{"sp": "Bala", "text": "Save the celebration! The rift is widening - that was not the last of them."},
		{"sp": "Ajees", "text": "Everyone get inside. I will hold the courtyard."}
	],
	"stage2_intro": [
		{"sp": "narrator", "text": "The courtyard folds inward. Gravity forgets which way is down."},
		{"sp": "Gokul", "text": "Manmohan, get the others to the shelter - now!"},
		{"sp": "Manmohan", "text": "Not without you two. We hold this line together."},
		{"sp": "Ajees", "text": "Stay behind me. The rift feeds on fear."}
	],
	"stage2_clear": [
		{"sp": "narrator", "text": "The rift stops breathing. A figure steps out of the wound in the sky."},
		{"sp": "Katleen", "text": "So the vessel chose a boy with a borrowed heartbeat."},
		{"sp": "Ajees", "text": "You did this to my campus."},
		{"sp": "Katleen", "text": "I opened a door. You walked through it. Now show me your miracle."}
	],
	"stage3_intro": [
		{"sp": "Sara", "text": "Ajees - whatever happens in there, come back to us."},
		{"sp": "Ajees", "text": "I will. I promise."},
		{"sp": "Katleen", "text": "Come then, little vessel. Let me see what you are made of."}
	],
	"boss_phase2": [
		{"sp": "Katleen", "text": "Impossible... that light. Where does it come from, boy?"},
		{"sp": "Ajees", "text": "From everyone who told me to keep standing."}
	],
	"victory": [
		{"sp": "Katleen", "text": "A vessel that refuses to break... how inconvenient."},
		{"sp": "Ajees", "text": "The door closes now, Katleen."},
		{"sp": "Katleen", "text": "Then I will remember your name, Ajees."},
		{"sp": "narrator", "text": "The rift seals. For the first time in hours, the campus breathes."},
		{"sp": "Sara", "text": "You are still here. You are still you."}
	]
}

const CROSSROADS: Dictionary = {
	"path": {
		"head": "CROSSROADS - THE RIFT ANSWERS",
		"options": [
			{"title": "Chase the answers", "note": "Scholar path - your burst hits 25% harder."},
			{"title": "Protect the others", "note": "Guardian path - unlock Mend and +15 max health."}
		]
	},
	"allies": {
		"head": "CROSSROADS - HOLD THE LINE TOGETHER",
		"options": [
			{"title": "Stand with Sara and the others", "note": "Sara joins as support fire, +20 max health."},
			{"title": "Send them to shelter - fight alone", "note": "No support, but your strikes cut 18% deeper."}
		]
	},
	"resolve": {
		"head": "CROSSROADS - WHAT THE VESSEL HOLDS",
		"options": [
			{"title": "Have faith in the people behind you", "note": "Mend heals more, +6% damage."},
			{"title": "Take the rift's power for yourself", "note": "+22% damage. The rift remembers this."}
		]
	},
	"ending": {
		"head": "THE FINAL CHOICE",
		"options": [
			{"title": "Seal the rift and give the power back", "note": "Ending - The Vessel's Choice."},
			{"title": "Keep the singularity inside you", "note": "Ending - The Sovereign of the Rift."},
			{"title": "Walk away and live an ordinary life", "note": "Ending - A Quiet Morning."}
		]
	}
}

const ENDINGS: Dictionary = {
	"seal": {
		"id": "seal",
		"title": "THE VESSEL'S CHOICE",
		"text": "Ajees pours every spark of the singularity back into the wound in the sky. The rift folds shut like a held breath, and the campus lights come back on one window at a time.",
		"epilogue": "Power given, not taken."
	},
	"sovereign": {
		"id": "sovereign",
		"title": "THE SOVEREIGN OF THE RIFT",
		"text": "He does not close the door. He becomes the lock. The rift still whispers at the edge of campus, and the boy who was mortal now keeps watch over a world that does not know his name.",
		"epilogue": "Power kept - and the price waits."
	},
	"dawn": {
		"id": "dawn",
		"title": "A QUIET MORNING",
		"text": "The vessel empties. Ajees wakes on the courtyard grass with no light in his hands and the whole ordinary day ahead of him. Somewhere far away, the rift remembers him anyway.",
		"epilogue": "Power released. Life resumed."
	}
}

var active: bool = false
var lines: Array = []
var index: int = 0
var full_text: String = ""
var speaker: String = ""
var typed: float = 0.0
var typing: bool = false
var _callback: Callable = Callable()
var _pending_choice: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not active or not typing:
		return
	typed += delta * TYPE_SPEED
	var count: int = mini(full_text.length(), int(typed))
	var visible_text: String = full_text.substr(0, count)
	if count < full_text.length():
		visible_text += "|"
	typing_updated.emit(visible_text)
	if count >= full_text.length():
		typing = false
		line_changed.emit(speaker, full_text)


func start_dialogue(line_list: Array, callback: Callable = Callable()) -> void:
	if line_list.is_empty():
		if callback.is_valid():
			callback.call()
		return
	lines = line_list.duplicate(true)
	index = 0
	active = true
	_callback = callback
	dialogue_started.emit(lines)
	_show_line(0)


func _show_line(i: int) -> void:
	if i < 0 or i >= lines.size():
		_finish()
		return
	var line: Dictionary = lines[i]
	speaker = String(line.get("sp", "narrator"))
	full_text = String(line.get("text", ""))
	typed = 0.0
	typing = true
	line_changed.emit(speaker, "")
	typing_updated.emit("")


## Advances the dialogue: first tap completes the typing, second tap continues.
func advance() -> bool:
	if not active:
		return false
	if typing:
		typing = false
		typed = full_text.length()
		line_changed.emit(speaker, full_text)
		return true
	if index < lines.size() - 1:
		index += 1
		_show_line(index)
		return true
	_finish()
	return true


func _finish() -> void:
	active = false
	var callback: Callable = _callback
	_callback = Callable()
	dialogue_finished.emit()
	if callback.is_valid():
		callback.call()


func has_next() -> bool:
	return index < lines.size() - 1


func speaker_color(sp: String) -> Color:
	var data: Dictionary = SPEAKERS.get(sp, SPEAKERS["narrator"])
	return data.get("color", Color.WHITE)


func is_narration(sp: String) -> bool:
	var data: Dictionary = SPEAKERS.get(sp, SPEAKERS["narrator"])
	return bool(data.get("narration", false))


func display_name(sp: String) -> String:
	if sp == "narrator":
		return "THE RIFT"
	return sp.to_upper()


func crossroad(key: String) -> Dictionary:
	return CROSSROADS.get(key, {})


func ending(id: String) -> Dictionary:
	return ENDINGS.get(id, ENDINGS["seal"])


func notify(title: String, subtitle: String, seconds: float = 2.6) -> void:
	notification_requested.emit(title, subtitle, seconds)


func set_pending_choice(key: String) -> void:
	_pending_choice = key


func take_pending_choice() -> String:
	var key: String = _pending_choice
	_pending_choice = ""
	return key
