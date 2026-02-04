#gdlint: disable=max-line-length
@tool
extends EditorInspectorPlugin

var editor_plugin: EditorPlugin


func _can_handle(object: Object) -> bool:
	return object is PixelEffectRichTextLabel or object is EffectWrapper


func _parse_category(object: Object, category: String) -> void:
	if category == "PixelEffectRichTextLabel" or category == "EffectWrapper":  # custom class categories seems to not exist
		add_custom_control(_create_ui(object))


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint: PropertyHint, _hint_text: String, _usage: PropertyUsageFlags, _wide: bool) -> bool:
	if object is PixelEffectRichTextLabel and name == "effect_definitions":
		add_custom_control(_create_ui(object))
	if object is EffectWrapper and name == "effect":
		add_custom_control(_create_ui(object))
	return false


func _create_ui(object: Object) -> Control:
	var ui := preload("res://addons/pixel_ui_effects/editor/effect_generator_ui.tscn").instantiate()
	ui.setup(object, editor_plugin)
	return ui
