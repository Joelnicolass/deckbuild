#gdlint: disable=max-line-length
@tool
extends EditorPlugin

const PixelEffectsTextInspectorPlugin := preload("res://addons/pixel_ui_effects/editor/inspector_plugin.gd")
var inspector_plugin: EditorInspectorPlugin = PixelEffectsTextInspectorPlugin.new()


func _enter_tree() -> void:
	inspector_plugin.editor_plugin = self
	add_inspector_plugin(inspector_plugin)
	add_custom_type("EffectWrapper", "MarginContainer", preload("res://addons/pixel_ui_effects/pixel_effects_wrapper.gd"), null)
	add_custom_type("EffectsLabel", "RichTextLabel", preload("res://addons/pixel_ui_effects/pixel_effects_label.gd"), null)


func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)
	remove_custom_type("EffectWrapper")
	remove_custom_type("EffectsLabel")
