#gdlint: disable=max-line-length
extends Control

const ROTATION_INTERVAL: float = 1.0
const INACTIVITY_TIMEOUT: float = 2.0

var _is_dissolved: Dictionary[EffectWrapper, bool]
var _fire_effect: Resource
var _after_image_effect: Resource

var _buttons: Array[Button] = []
var _current_rotate_index: int = -1
var _rotation_timer: float = 0.0
var _inactivity_timer: float = 0.0
var _is_auto_rotating: bool = true
var _programmatic_focus: bool = false

var _button_map: Dictionary = {}

@onready var dissolve_button: Button = $CenterContainer/HBoxContainer/GridContainer/DissolveEffectWrapper/SubViewport/Button
@onready var dissolve_v2_button: Button = $CenterContainer/HBoxContainer/GridContainer/DissolveV2EffectWrapper/SubViewport/Button
@onready var dissolve_effect_wrapper: EffectWrapper = $CenterContainer/HBoxContainer/GridContainer/DissolveEffectWrapper
@onready var dissolve_v2_effect_wrapper: EffectWrapper = $CenterContainer/HBoxContainer/GridContainer/DissolveV2EffectWrapper
@onready var fire_button: Button = $CenterContainer/HBoxContainer/GridContainer/FireEffectWrapper/SubViewport/Button
@onready var fire_effect_wrapper: EffectWrapper = $CenterContainer/HBoxContainer/GridContainer/FireEffectWrapper
@onready var after_image_button: Button = $CenterContainer/HBoxContainer/GridContainer/AfterImageEffectWrapper/SubViewport/Button
@onready var after_image_effect_wrapper: EffectWrapper = $CenterContainer/HBoxContainer/GridContainer/AfterImageEffectWrapper

@onready var after_image_slider: VSlider = $CenterContainer/HBoxContainer/SliderAfterImage/SubViewport/VSlider
@onready var fire_slider: VSlider = $CenterContainer/HBoxContainer/SliderFire/SubViewport/VSlider


func _ready() -> void:
	# Set focus behaviour with input to work in Godot 4.6 as in 4.5
	ProjectSettings.set_setting("gui/common/show_focus_state_on_pointer_event", 2)

	_buttons = [fire_button, after_image_button, dissolve_button, dissolve_v2_button]
	_button_map = {fire_button: fire_effect_wrapper, after_image_button: after_image_effect_wrapper, dissolve_button: dissolve_effect_wrapper, dissolve_v2_button: dissolve_v2_effect_wrapper}

	for btn in _buttons:
		btn.focus_entered.connect(_on_any_button_focus_entered.bind(btn))
	after_image_slider.focus_entered.connect(_on_any_slider_focus_entered)
	fire_slider.focus_entered.connect(_on_any_slider_focus_entered)

	dissolve_button.pressed.connect(_start_dissolve.bind(dissolve_effect_wrapper))
	dissolve_button.focus_entered.connect(_start_dissolve.bind(dissolve_effect_wrapper))
	dissolve_button.focus_exited.connect(_reverse_dissolve.bind(dissolve_effect_wrapper))
	dissolve_v2_button.pressed.connect(_start_dissolve.bind(dissolve_v2_effect_wrapper))
	dissolve_v2_button.focus_entered.connect(_start_dissolve.bind(dissolve_v2_effect_wrapper))
	dissolve_v2_button.focus_exited.connect(_reverse_dissolve.bind(dissolve_v2_effect_wrapper))

	_fire_effect = fire_effect_wrapper.effect
	_after_image_effect = after_image_effect_wrapper.effect

	fire_button.focus_entered.connect(func(): _update_button_state(fire_button, _fire_effect, "disable_emission"))
	fire_button.focus_exited.connect(func(): _update_button_state(fire_button, _fire_effect, "disable_emission"))

	after_image_button.focus_entered.connect(func(): _update_button_state(after_image_button, _after_image_effect))
	after_image_button.focus_exited.connect(func(): _update_button_state(after_image_button, _after_image_effect))

	_is_dissolved[dissolve_effect_wrapper] = true
	_is_dissolved[dissolve_v2_effect_wrapper] = true

	_update_all_effects()
	
	_reverse_dissolve(dissolve_effect_wrapper)
	_reverse_dissolve(dissolve_v2_effect_wrapper)


func _process(delta: float) -> void:
	if _is_auto_rotating:
		_rotation_timer += delta

		if _current_rotate_index != -1 and _current_rotate_index < _buttons.size():
			var btn = _buttons[_current_rotate_index]
			var wrapper = _button_map.get(btn)
			if wrapper:
				var rect = wrapper.get_global_rect()
				wrapper.use_global_mouse = false
				var progress = clamp(_rotation_timer / ROTATION_INTERVAL, 0.0, 1.0)
				var target_x = rect.position.x + (rect.size.x * progress * 3.0) - rect.size.x * 1.0
				var target_y = rect.position.y + (rect.size.y * 0.5)
				wrapper.update_cursor_position(Vector2(target_x, target_y))

		if _rotation_timer >= ROTATION_INTERVAL:
			if _current_rotate_index != -1:
				var btn = _buttons[_current_rotate_index]
				var wrapper = _button_map.get(btn)
				if wrapper:
					wrapper.use_global_mouse = true

			_rotation_timer = 0.0
			_rotate_focus()
	else:
		_inactivity_timer += delta
		if _inactivity_timer >= INACTIVITY_TIMEOUT:
			_start_auto_rotation()


func _rotate_focus() -> void:
	_current_rotate_index = (_current_rotate_index + 1) % _buttons.size()
	var btn = _buttons[_current_rotate_index]
	if is_instance_valid(btn):
		_programmatic_focus = true
		btn.grab_focus()
		_programmatic_focus = false


func _start_auto_rotation() -> void:
	_is_auto_rotating = true
	_rotation_timer = 0.0
	_rotate_focus()


func _on_any_button_focus_entered(btn: Button) -> void:
	if not _programmatic_focus:
		_is_auto_rotating = false
		_inactivity_timer = 0.0
		_current_rotate_index = _buttons.find(btn)


func _on_any_slider_focus_entered() -> void:
	if not _programmatic_focus:
		_is_auto_rotating = false
		_inactivity_timer = 0.0


func _update_all_effects() -> void:
	_update_button_state(fire_button, _fire_effect, "disable_emission")
	_update_button_state(after_image_button, _after_image_effect)


func _update_button_state(button: Button, effect: Resource = null, param_name: String = "disable") -> void:
	button.remove_theme_stylebox_override("normal")

	if not effect:
		return

	if param_name in effect.effect_parameters:
		effect.effect_parameters[param_name] = not button.has_focus()


func _start_dissolve(wrapper: EffectWrapper) -> void:
	print("Start")
	if _is_dissolved[wrapper]:
		return

	wrapper.play_animation({"anim-duration": 1.0, "anim-repeat": "once"})
	_is_dissolved[wrapper] = true


func _reverse_dissolve(wrapper: EffectWrapper) -> void:
	print("Reverse")
	if not _is_dissolved[wrapper]:
		return

	wrapper.play_animation({"anim-duration": 1.0, "anim-inverse": true, "anim-repeat": "once"})
	_is_dissolved[wrapper] = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _is_auto_rotating:
			for wrapper in _button_map.values():
				wrapper.use_global_mouse = true
		_inactivity_timer = 0.0
