@tool
extends PanelContainer

var target: Control
var editor_plugin: EditorPlugin

@onready var add_button: Button = $HBoxContainer/Button
@onready var type_selector: OptionButton = $HBoxContainer/PanelContainer/HBoxContainer/TypeSelector


func setup(control: Control, p_editor_plugin: EditorPlugin) -> void:
	editor_plugin = p_editor_plugin
	target = control


func _ready() -> void:
	var plus_icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	if is_instance_valid(plus_icon):
		add_button.icon = plus_icon
		add_button.text = ""
	if is_instance_valid(type_selector):
		type_selector.clear()
		var path = "res://addons/pixel_ui_effects/effect_resources/defaults/"
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if !dir.current_is_dir() and file_name.ends_with(".tres"):
					var resource = load(path + file_name)
					if resource is EffectSetting:
						type_selector.add_item(file_name.get_basename())
						var index = type_selector.item_count - 1
						type_selector.set_item_metadata(index, path + file_name)
						for config in ShaderRegistry.SHADER_CONFIGS:
							if config.name == resource.effect_type:
								type_selector.set_item_tooltip(index, config.get("tooltip", ""))
								break
				file_name = dir.get_next()
	if is_instance_valid(add_button):
		add_button.pressed.connect(_on_add_pressed)


func _on_add_pressed() -> void:
	if not is_instance_valid(target):
		return

	var index = type_selector.selected
	if index == -1:
		return

	var path = type_selector.get_item_metadata(index)
	if path:
		var resource = load(path)
		if resource:
			var new_resource = resource.duplicate(true)
			if "effect_definitions" in target:
				var new_array = target.effect_definitions.duplicate()
				new_array.append(new_resource)

				var undo_redo = editor_plugin.get_undo_redo()
				if undo_redo:
					undo_redo.create_action("Add Effect")
					undo_redo.add_do_property(target, "effect_definitions", new_array)
					undo_redo.add_undo_property(target, "effect_definitions", target.effect_definitions)
					undo_redo.add_do_method(target, "notify_property_list_changed")
					undo_redo.add_do_method(target, "update_configuration_warnings")
					undo_redo.add_undo_method(target, "notify_property_list_changed")
					undo_redo.add_undo_method(target, "update_configuration_warnings")
					undo_redo.commit_action()
				else:
					target.effect_definitions = new_array
					target.notify_property_list_changed()
					target.update_configuration_warnings()
			elif "effect" in target:
				var undo_redo = editor_plugin.get_undo_redo()
				if undo_redo:
					undo_redo.create_action("Set Effect")
					undo_redo.add_do_property(target, "effect", new_resource)
					undo_redo.add_undo_property(target, "effect", target.effect)
					undo_redo.add_do_method(target, "notify_property_list_changed")
					undo_redo.add_do_method(target, "update_configuration_warnings")
					undo_redo.add_undo_method(target, "notify_property_list_changed")
					undo_redo.add_undo_method(target, "update_configuration_warnings")
					undo_redo.commit_action()
				else:
					target.effect = new_resource
					target.notify_property_list_changed()
					target.update_configuration_warnings()
