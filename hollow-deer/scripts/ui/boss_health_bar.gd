class_name BossHealthBar
extends CanvasLayer
## Screen-space boss health bar, hidden until a fight starts.
## A parent wires it to a boss with track(boss), or drives it directly with
## open(), close(), set_health() and set_phase().
## Ticks on the bar mark the health levels where the boss changes phase, and a
## pale trail drains behind each hit so the player can see how much it took.

@export var boss_name: String = "The Big Bad Lonesome Wolf"
## Bar fill colour for each phase, starting with phase 1. The last one repeats.
@export var phase_colors: Array[Color] = [
	Color(0.78, 0.16, 0.18),
	Color(0.62, 0.22, 0.72),
	Color(0.95, 0.68, 0.2),
]
@export var tick_color: Color = Color(0.08, 0.06, 0.08)
@export var fade_time: float = 0.3
## After a hit, the trail waits this long, then drains to the new health.
@export var trail_delay: float = 0.35
@export var trail_drain_time: float = 0.4
## How long the bar stays on screen after the boss dies.
@export var linger_time: float = 1.5

var _fill_style: StyleBoxFlat
var _fade_tween: Tween
var _trail_tween: Tween
var _flash_tween: Tween

@onready var _root: Control = %Root
@onready var _name_label: Label = %NameLabel
@onready var _bar_frame: Control = %BarFrame
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _trail_bar: ProgressBar = %TrailBar
@onready var _ticks: Control = %Ticks


func _ready() -> void:
	assert(not phase_colors.is_empty(), "phase_colors needs at least one colour")
	# Own copy, so recolouring per phase doesn't edit the scene's shared resource.
	_fill_style = _health_bar.get_theme_stylebox("fill").duplicate()
	_health_bar.add_theme_stylebox_override("fill", _fill_style)
	_name_label.text = boss_name
	_root.modulate.a = 0.0
	_root.hide()
	set_phase(1)


## Connects to a boss's signals so the bar runs itself. The boss needs
## fight_started, health_changed(current, maximum), phase_changed(phase),
## died and fight_reset. If it has get_phase_thresholds(), ticks are drawn.
func track(boss: Node) -> void:
	boss.connect("fight_started", _on_boss_fight_started.bind(boss))
	boss.connect("health_changed", set_health)
	boss.connect("phase_changed", set_phase)
	boss.connect("died", close.bind(linger_time))
	boss.connect("fight_reset", close)


func open() -> void:
	_fade_to(1.0, 0.0)


func close(delay: float = 0.0) -> void:
	_fade_to(0.0, delay)


func set_health(current: int, maximum: int) -> void:
	var took_damage := maximum == int(_health_bar.max_value) and current < int(_health_bar.value)
	_health_bar.max_value = maximum
	_trail_bar.max_value = maximum
	_health_bar.value = current

	if _trail_tween:
		_trail_tween.kill()
	if not took_damage:
		# Fight start or reset: no trail, just snap to the new value.
		_trail_bar.value = current
		return
	# Hits in quick succession restart the delay, so the trail shows the combo.
	_trail_tween = create_tween()
	_trail_tween.tween_interval(trail_delay)
	_trail_tween.tween_property(_trail_bar, "value", float(current), trail_drain_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash()


func set_phase(phase: int) -> void:
	_fill_style.bg_color = phase_colors[clampi(phase - 1, 0, phase_colors.size() - 1)]


## Draws a tick at each health fraction (0 to 1) where a new phase starts.
func set_phase_thresholds(fractions: Array[float]) -> void:
	for tick in _ticks.get_children():
		tick.queue_free()
	for fraction: float in fractions:
		var tick := ColorRect.new()
		tick.color = tick_color
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.anchor_left = fraction
		tick.anchor_right = fraction
		tick.anchor_bottom = 1.0
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		_ticks.add_child(tick)


func _fade_to(alpha: float, delay: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	if alpha > 0.0:
		_root.show()
	_fade_tween = create_tween()
	if delay > 0.0:
		_fade_tween.tween_interval(delay)
	_fade_tween.tween_property(_root, "modulate:a", alpha, fade_time)
	if alpha == 0.0:
		_fade_tween.tween_callback(_root.hide)


func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_bar_frame.modulate = Color(1.8, 1.8, 1.8)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_bar_frame, "modulate", Color.WHITE, 0.15)


func _on_boss_fight_started(boss: Node) -> void:
	if boss.has_method("get_phase_thresholds"):
		set_phase_thresholds(boss.call("get_phase_thresholds"))
	open()
