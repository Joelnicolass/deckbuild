#gdlint: disable=max-line-length
@tool
extends Control

const DEBOUNCE_DELAY: float = 0.2
const MAX_WAIT_DELAY: float = 2.0
const FONT_SETTINGS = {
	"NJ-PixelLessSmooth.ttf": {"name": "LessSmooth", "font_size": 29, "scale": 1.9, "minimum_size_x": 360.0},
	"NJ-PixelSmooth.ttf": {"name": "Smooth", "font_size": 30, "scale": 1.8, "minimum_size_x": 380.0},
	"NJ-OnePixelOff.ttf": {"name": "OnePixelOff", "font_size": 30, "scale": 1.8, "minimum_size_x": 380.0},
}
const MOBILE_TEXT = "This custom RichTextLabel, let's you [pas id=iterative_fire]add some [wave amp=50.0 freq=5.0 connected=1]burning hot[/wave] effects[/pas] using BBCode. Upgrade your text with a [pas id=dissolve anim-repeat=ping-pong]growing collection[/pas] of effects to add [pas id=afterimage anim-duration=1.0]more character[/pas] to your texts."
const MOBILE_TEXT_HINT = "The TextEdit on mobile is not yet available, but you can test this on desktop!"

var _debounce_timer: float = 0.0
var _max_wait_timer: float = 0.0

@onready var pixel_effect_rich_text_label: PixelEffectRichTextLabel = $MarginContainer/HBoxContainer/MarginContainer/Control/PixelEffectRichTextLabel
@onready var v_box_container: VBoxContainer = $MarginContainer/HBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/PanelContainer/VBoxContainer
@onready var option_button: OptionButton = $MarginContainer/HBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/PanelContainer2/VBoxContainer/OptionButton
@onready var effect_selection: PanelContainer = $MarginContainer/HBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/PanelContainer
@onready var hint_label: Label = $MarginContainer/HBoxContainer/MarginContainer2/HBoxContainer/PanelContainer2/VBoxContainer/Label
@onready var text_edit: TextEdit = $MarginContainer/HBoxContainer/MarginContainer2/HBoxContainer/PanelContainer2/VBoxContainer/TextEdit


func _ready() -> void:
	# Set focus behaviour with input to work in Godot 4.6 as in 4.5
	ProjectSettings.set_setting("gui/common/show_focus_state_on_pointer_event", 2)

	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		text_edit.text = MOBILE_TEXT
		hint_label.text = MOBILE_TEXT_HINT
		effect_selection.visible = false
		text_edit.editable = false

	pixel_effect_rich_text_label.text = text_edit.text
	text_edit.text_changed.connect(
		func():
			_debounce_timer = DEBOUNCE_DELAY
			if _max_wait_timer <= 0.0:
				_max_wait_timer = MAX_WAIT_DELAY
	)

	for child in v_box_container.get_children():
		if child is Button:
			child.queue_free()

	if pixel_effect_rich_text_label.effect_definitions:
		for effect in pixel_effect_rich_text_label.effect_definitions:
			if not effect:
				continue

			var btn := Button.new()
			btn.theme_type_variation = "InPanelButton"
			btn.text = effect.name
			v_box_container.add_child(btn)

			btn.pressed.connect(
				func():
					var bbcode := "[pas id=%s]%s[/pas]" % [effect.name, effect.name]
					text_edit.insert_text_at_caret(bbcode)
					text_edit.grab_focus()
			)

	_setup_font_selector()


func _process(delta: float) -> void:
	if _debounce_timer > 0.0:
		_debounce_timer -= delta
		_max_wait_timer -= delta
		if _debounce_timer <= 0.0 or _max_wait_timer <= 0.0:
			pixel_effect_rich_text_label.text = text_edit.text
			_debounce_timer = 0.0
			_max_wait_timer = 0.0


func _setup_font_selector() -> void:
	option_button.clear()
	var fonts_dir := "res://addons/pixel_ui_effects/fonts/"

	var keys = FONT_SETTINGS.keys()
	keys.sort()

	for file_name in keys:
		var config = FONT_SETTINGS[file_name]
		option_button.add_item(config.name)
		option_button.set_item_metadata(option_button.item_count - 1, file_name)

	option_button.item_selected.connect(
		func(index: int):
			var file_name = option_button.get_item_metadata(index)
			if FONT_SETTINGS.has(file_name):
				var config = FONT_SETTINGS[file_name]
				var font_path = fonts_dir + file_name
				var font = load(font_path)
				if font:
					pixel_effect_rich_text_label.add_theme_font_override("normal_font", font)
					pixel_effect_rich_text_label.add_theme_font_size_override("normal_font_size", config.font_size)
					pixel_effect_rich_text_label.custom_minimum_size = Vector2(config.minimum_size_x, 0.0)
					pixel_effect_rich_text_label.size.x = pixel_effect_rich_text_label.custom_minimum_size.x
					pixel_effect_rich_text_label.scale = Vector2(config.scale, config.scale)
					pixel_effect_rich_text_label.custom_minimum_size.x = (2.0 * 335.0) / config.scale
	)

	if option_button.item_count > 0:
		var default_index = 0
		for i in range(option_button.item_count):
			if option_button.get_item_text(i) == "LessSmooth":
				default_index = i
				break

		option_button.select(default_index)
		option_button.item_selected.emit(default_index)
