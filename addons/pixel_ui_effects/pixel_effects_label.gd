#gdlint: disable=max-line-length
@tool
class_name PixelEffectRichTextLabel
extends RichTextLabel

const _IGNORE_PROPS = ["editor_description", "modulate", "self_modulate", "top_level", "light_mask", "visibility_layer", "z_index", "z_as_relative", "y_sort_enabled", "material", "use_parent_material", "position", "rotation", "scale", "pivot_offset", "tooltip_text", "tooltip_auto_translate_mode", "focus_neighbor_left", "focus_neighbor_top", "focus_neighbor_right", "focus_neighbor_bottom", "focus_next", "focus_previous", "focus_mode", "focus_behavior_recursive", "mouse_filter", "mouse_behavior_recursive", "mouse_force_pass_scroll_events", "mouse_default_cursor_shape", "shortcut_context", "accessibility_name", "accessibility_description", "accessibility_live", "accessibility_controls_nodes", "accessibility_described_by_nodes", "accessibility_labeled_by_nodes", "accessibility_flow_to_nodes", "context_menu_enabled", "shortcut_keys_enabled", "selection_enabled", "deselect_on_focus_loss_enabled", "drag_and_drop_selection_enabled", "script", "metadata/_custom_type_script"]
const _TEXT_EFFECT_CLASS = {"pas": preload("res://addons/pixel_ui_effects/pixel_rich_text_effect.gd"), "pasm": preload("res://addons/pixel_ui_effects/pixel_rich_text_effect_mask.gd")}

static var _regex: RegEx

## [b]Effect Definitions[/b]
## The list of effect definitions to apply to the text.
## Each definition can be used in the bbcode with the [code]id[/code] param of the [code][pas][/code] tag.
@export var effect_definitions: Array[EffectSetting] = []:
	set(value):
		if effect_definitions:
			for e in effect_definitions:
				if e and e.is_connected("changed", _on_effect_changed):
					e.disconnect("changed", _on_effect_changed)

		effect_definitions = value

		if effect_definitions:
			for e in effect_definitions:
				if e:
					if not e.is_connected("changed", _on_effect_changed):
						e.changed.connect(_on_effect_changed)
		_on_effect_changed()

## [b]Border Size[/b]
## The size of the border around the text.
## This expands the label's margin to fit effects that extend beyond the text.
## This is useful for effects that make the text larger or add outlines.
@export var border_size: Vector2 = Vector2(0, 0):
	set(value):
		var previous_border_size = border_size
		border_size = value
		if is_instance_valid(_margin_container):
			_margin_container.add_theme_constant_override("margin_left", -int(border_size.x))
			_margin_container.add_theme_constant_override("margin_right", -int(border_size.x))
			_margin_container.add_theme_constant_override("margin_top", -int(border_size.y))
			_margin_container.add_theme_constant_override("margin_bottom", -int(border_size.y))
			for child in _margin_container.get_children():
				if child in [FeedbackTextureMasked, ExtendTextureRect, PreprocessTexture]:
					child.border_size = Vector2.ZERO
					child.position = border_size * scale
			_margin_container.size = Vector2.ZERO

			var size_difference: Vector2i = Vector2i(-2.0 * previous_border_size + 2.0 * border_size)
			_label_viewport.size = _label_viewport.size + size_difference
			_mask_viewport.size = _mask_viewport.size + size_difference
			_label.position = border_size
			_mask_label.position = border_size
		_on_effect_changed()

## [b]Disable Effects[/b]
## If true, all effects will be hidden.
@export var disable_effects: bool = false:
	set(value):
		if value != disable_effects:
			disable_effects = value
			_update_active_effects()

## [b]Optimize Updates[/b]
## [color=gray]If true, updating the effect will only apply parameter changes instead of recreating the effect node.
## Note: Some effects, particularly those using preprocessing, may require a full reset (node recreation) to apply changes correctly.[/color]
@export var optimize_updates: bool = true

## [b]Disable Visibility Time Reset[/b]
## If true, the animation time will NOT be reset when the label's visibility changes.
## This is useful if you want to pause/resume animations or control reset manually.
@export var disable_visibility_time_reset: bool = false

var _palette_textures: Dictionary = {}
var _tracked_properties: Dictionary = {}
var _trigger_update: bool = false
var _instance_state: Dictionary = {}
var _instance_color_map: Dictionary = {}
var _cursor_position: Vector2 = Vector2(0.5, 0.5)
var _preprocessor: Dictionary = {}

var _margin_container: MarginContainer
var _label_viewport: SubViewport
var _label: RichTextLabel
var _mask_viewport: SubViewport
var _mask_label: RichTextLabel


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll_active = false

	_margin_container = MarginContainer.new()
	_margin_container.add_theme_constant_override("margin_left", -int(border_size.x))
	_margin_container.add_theme_constant_override("margin_right", -int(border_size.x))
	_margin_container.add_theme_constant_override("margin_top", -int(border_size.y))
	_margin_container.add_theme_constant_override("margin_bottom", -int(border_size.y))
	add_child(_margin_container)

	_label_viewport = SubViewport.new()
	_label_viewport.transparent_bg = true
	_label_viewport.disable_3d = true
	_label_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_label_viewport)
	_label = RichTextLabel.new()
	_label_viewport.add_child(_label)

	_mask_viewport = SubViewport.new()
	_mask_viewport.transparent_bg = true
	_mask_viewport.disable_3d = true
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask_viewport)
	_mask_label = RichTextLabel.new()
	_mask_viewport.add_child(_mask_label)

	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	_add_pas()
	_initialize_tracking()

	if effect_definitions:
		for e in effect_definitions:
			if e:
				if not e.is_connected("changed", _on_effect_changed):
					e.changed.connect(_on_effect_changed)

	_update_active_effects()
	resized.connect(_on_effect_changed)


func _process(delta: float) -> void:
	if not is_instance_valid(_label) or not is_instance_valid(_mask_label):
		return

	_update_cursor_position(get_global_mouse_position())
	_process_animations(delta)
	_check_tracked_properties()

	if _label.position != Vector2.ZERO:
		_label.position = border_size
	if _mask_label.position != Vector2.ZERO:
		_mask_label.position = border_size

	if _trigger_update:
		_update_active_effects()


## Manually reset the time of all active effects to 0.0.
func reset_animation_times() -> void:
	for sig in _instance_state:
		_instance_state[sig].time = 0.0
		_instance_state[sig].started = false
		_instance_state[sig].hiding = false


## Manually trigger the hiding state for effects that use 'on-hide' trigger.
## This sets the 'hiding' flag to true and resets the time.
func trigger_hide_animation() -> void:
	for sig in _instance_state:
		var params = _instance_state[sig].params
		var trigger = params.get("anim-trigger", "on-appear")

		if trigger == "on-hide":
			_instance_state[sig].hiding = true
			_instance_state[sig].started = false
			_instance_state[sig].time = 0.0


func _get_regex() -> RegEx:
	if not _regex:
		_regex = RegEx.new()
		_regex.compile("\\[pas\\s+(?<content>[^\\]]+)\\]")
	return _regex


func _process_animations(delta: float) -> void:
	for sig in _instance_state:
		var state = _instance_state[sig]
		var params = state.params
		var node = state.node

		if not is_instance_valid(node):
			continue

		var duration = float(params.get("anim-duration", 1.0))
		var delay = float(params.get("anim-delay", 0.0))
		var trigger = params.get("anim-trigger", "on-appear")
		var inverse = params.get("anim-inverse", "false") == "true"
		var repeat = params.get("anim-repeat", "loop")

		if trigger == "on-appear" and not state.started:
			state.started = true
			state.time = 0.0
		elif trigger == "on-hide" and state.hiding and not state.started:
			state.started = true
			state.time = 0.0

		if state.started:
			state.time += delta

			var effective_time = max(0.0, state.time - delay)
			var t = effective_time / duration if duration > 0 else 1.0

			if repeat == "once":
				t = max(0.0, min(t, 1.0))
			elif repeat == "loop":
				t = fmod(t, 1.0)
			elif repeat == "ping-pong":
				t = fmod(t, 2.0)
				if t > 1.0:
					t = 2.0 - t

			if inverse:
				t = 1.0 - t

			if node.material is ShaderMaterial:
				if state.definition.normalize_time:
					node.material.set_shader_parameter("time", t)
				else:
					node.material.set_shader_parameter("time", -1.0)


func _check_tracked_properties() -> void:
	var changes = {}
	for p_name in _tracked_properties:
		if p_name in ["visible_characters", "visible_ratio"]:
			continue
		var current_val = get(p_name)
		var last_val = _tracked_properties[p_name]

		var changed = false
		if typeof(current_val) < TYPE_OBJECT:
			if current_val != last_val:
				changed = true
		elif not EffectUtils.is_equal(current_val, last_val):
			changed = true

		if changed:
			changes[p_name] = current_val
			_tracked_properties[p_name] = EffectUtils.deep_copy(current_val)
			_label.set(p_name, current_val)
			_mask_label.set(p_name, current_val)

	if _mask_label.get_theme_constant("outline_size") != 0:
		_mask_label.add_theme_constant_override("outline_size", 0)
	if _mask_label.get_theme_constant("shadow_outline_size") != 0:
		_mask_label.add_theme_constant_override("shadow_outline_size", 0)

	if "visible_characters" in _tracked_properties:
		_label.visible_characters = visible_characters
	if "visible_ratio" in _tracked_properties:
		_label.visible_ratio = visible_ratio

	if not changes.is_empty():
		_on_properties_changed(changes)
		if "text" in changes:
			for child in _margin_container.get_children():
				if child is PreprocessTexture:
					child.reprocess()


func _update_effect_definitions() -> void:
	if is_instance_valid(_mask_label):
		for e in _mask_label.custom_effects:
			if e is PixelRichTextEffectMask:
				e.effect_definitions = effect_definitions
				e.color_map = _instance_color_map
		for e in custom_effects:
			if e is PixelRichTextEffect:
				e.effect_definitions = effect_definitions
		for e in _label.custom_effects:
			if e is PixelRichTextEffect:
				e.effect_definitions = effect_definitions


func _add_pas() -> void:
	_ensure_custom_effect(
		self ,
		"pas",
		func(fx):
			fx.hide_effects = true
			fx.effect_definitions = effect_definitions
	)

	if is_instance_valid(_label):
		var label_effects = []
		if custom_effects:
			for e in custom_effects:
				if e is PixelRichTextEffect and e.bbcode == "pas":
					continue
				label_effects.append(e)

		var script = _TEXT_EFFECT_CLASS.get("pas", null)
		if script:
			var fx = script.new()
			fx.effect_definitions = effect_definitions
			label_effects.append(fx)
		_label.custom_effects = label_effects

	if is_instance_valid(_mask_label):
		_ensure_custom_effect(
			_mask_label,
			"pasm",
			func(fx):
				fx.effect_definitions = effect_definitions
				fx.color_map = _instance_color_map
		)


func _ensure_custom_effect(target: RichTextLabel, text_effect_type: String, setup_fn: Callable = Callable()) -> void:
	var script = _TEXT_EFFECT_CLASS.get(text_effect_type, null)
	if not script:
		return

	var fx = script.new()
	if setup_fn.is_valid():
		setup_fn.call(fx)

	var effects = target.custom_effects
	if effects == null:
		effects = []

	for e in effects:
		if e is PixelRichTextEffect and e.bbcode == fx.bbcode:
			return

	effects.append(fx)
	target.custom_effects = effects


func _initialize_tracking() -> void:
	var props = get_property_list()
	for p in props:
		var p_name = p.name
		if p.usage & (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_INTERNAL | PROPERTY_USAGE_READ_ONLY):
			continue

		if !(p.usage & PROPERTY_USAGE_EDITOR):
			continue

		if p_name in _IGNORE_PROPS:
			continue

		if p_name in _label:
			var val = get(p_name)
			_tracked_properties[p_name] = EffectUtils.deep_copy(val)
			_label.set(p_name, val)

		if p_name in _mask_label:
			var val = get(p_name)
			_tracked_properties[p_name] = EffectUtils.deep_copy(val)
			_mask_label.set(p_name, val)

	_mask_label.add_theme_constant_override("outline_size", 0)
	_mask_label.add_theme_constant_override("shadow_outline_size", 0)

	if is_instance_valid(_label_viewport):
		if size.x > 0 and size.y > 0:
			_label_viewport.size = size + border_size * 2.0
		_label.position = border_size

	if is_instance_valid(_mask_viewport):
		if size.x > 0 and size.y > 0:
			_mask_viewport.size = size + border_size * 2.0
		_mask_label.position = border_size

	_on_resized()


func _update_cursor_position(mouse_pos: Vector2) -> void:
	var rect = get_global_rect()
	if rect.size.x == 0 or rect.size.y == 0:
		return

	var rect_border_pos = rect.position - border_size * scale
	var rect_border_size = rect.size + scale * 2.0 * border_size
	var relative_pos = (mouse_pos - rect_border_pos) / rect_border_size
	_cursor_position = relative_pos

	for sig in _instance_state:
		var state = _instance_state[sig]
		var node = state.node

		if not is_instance_valid(node) or not ShaderRegistry.check_cursor_support(state.definition.effect_type):
			continue

		var mat: ShaderMaterial = null
		if node is FeedbackTextureMasked:
			mat = node.apply_material
		elif node.material is ShaderMaterial:
			mat = node.material

		if mat:
			mat.set_shader_parameter("cursor_position", _cursor_position)


func _on_properties_changed(_changes: Dictionary) -> void:
	if _changes.size() > 0:
		_trigger_update = true


func _on_effect_changed() -> void:
	_trigger_update = true


func _on_visibility_changed() -> void:
	if disable_visibility_time_reset:
		return

	reset_animation_times()


func _update_active_effects() -> void:
	var current_text = text
	var active_instances = {}

	var regex = _get_regex()

	for result in regex.search_all(current_text):
		var content = result.get_string("content")
		var params = _parse_bbcode_params(content)
		var id_str = params.get("id", "")

		if id_str == "":
			continue

		var definition: EffectSetting = null
		for e in effect_definitions:
			if e and (str(e.id) == id_str or e.name == id_str):
				definition = e
				break

		if definition:
			var signature = _generate_signature(str(definition.id), params)
			if not active_instances.has(signature):
				var color = _get_color_for_signature(signature)
				active_instances[signature] = {"definition": definition, "params": params, "color": color, "signature": signature, "alt_id": false}
				active_instances[_generate_signature(definition.name, params)] = {"definition": definition, "params": params, "color": color, "signature": signature, "alt_id": true}

	for e in effect_definitions:
		if e:
			e.active = false

	for sig in active_instances:
		active_instances[sig].definition.active = !disable_effects

	_instance_color_map.clear()
	for sig in active_instances:
		_instance_color_map[sig] = active_instances[sig].color

	var new_state = {}
	for sig in active_instances:
		if _instance_state.has(sig):
			new_state[sig] = _instance_state[sig]
			new_state[sig].definition = active_instances[sig].definition
			new_state[sig].params = active_instances[sig].params
		else:
			new_state[sig] = {"params": active_instances[sig].params, "time": 0.0, "started": false, "hiding": false, "node": null, "alt_id": active_instances[sig].alt_id}
			new_state[sig].definition = active_instances[sig].definition
	_instance_state = new_state

	_update_effect_definitions()
	_update_render_nodes(active_instances)
	_trigger_update = false


func _parse_bbcode_params(content: String) -> Dictionary:
	var params = {}
	var pairs = content.split(" ", false)
	for pair in pairs:
		var parts = pair.split("=")
		if parts.size() == 2:
			params[parts[0]] = parts[1]
	return params


func _generate_signature(def_id: String, params: Dictionary) -> String:
	var keys = params.keys()
	keys.sort()
	var sig = "id=" + def_id
	for k in keys:
		if k != "id":
			sig += ";" + k + "=" + str(params[k])
	return sig


func _get_color_for_signature(signature: String) -> Color:
	var hash_sig = signature.hash()
	var hue = float(hash_sig % 360) / 360.0
	var sat = 0.5 + (float((hash_sig >> 8) % 100) / 200.0)
	var val = 0.8 + (float((hash_sig >> 16) % 100) / 500.0)
	return Color.from_hsv(hue, sat, val)


func _on_resized() -> void:
	if is_instance_valid(_label_viewport) and is_instance_valid(_mask_viewport):
		_label_viewport.size = size + 2.0 * border_size
		_label.position = border_size
		_mask_viewport.size = size + 2.0 * border_size
		_mask_label.position = border_size


func _update_render_nodes(active_instances: Dictionary) -> void:
	if not is_instance_valid(_margin_container) or not is_instance_valid(_label_viewport) or not is_instance_valid(_mask_viewport):
		return

	var used_nodes = {}

	if optimize_updates:
		for sig in active_instances:
			if active_instances[sig].alt_id:
				continue

			if _instance_state.has(sig) and is_instance_valid(_instance_state[sig].node):
				var node = _instance_state[sig].node
				var effect = active_instances[sig].definition
				var type = ShaderRegistry.get_shader_effect_class(effect.effect_type)

				var matches_type = false
				if (type == ShaderRegistry.ShaderBaseClass.FEEDBACK_TEXTURE and node is FeedbackTextureMasked) or (type == ShaderRegistry.ShaderBaseClass.EXTEND_TEXTURE and node is ExtendTextureRect) or (type == ShaderRegistry.ShaderBaseClass.PREPROCESS_TEXTURE and node is PreprocessTexture):
					matches_type = true

				if matches_type:
					used_nodes[node] = true
					EffectUtils.update_effect_parameters(node, effect, active_instances[sig].color, sig, _palette_textures)
					node.visible = effect.active
					node.position = - border_size

	var pools = {ShaderRegistry.ShaderBaseClass.FEEDBACK_TEXTURE: [], ShaderRegistry.ShaderBaseClass.EXTEND_TEXTURE: [], ShaderRegistry.ShaderBaseClass.PREPROCESS_TEXTURE: []}
	for child in _margin_container.get_children():
		if used_nodes.has(child):
			continue

		child.position = - border_size
		child.visible = false
		if child is PreprocessTexture:
			pools[ShaderRegistry.ShaderBaseClass.PREPROCESS_TEXTURE].append(child)
		elif child is FeedbackTextureMasked:
			pools[ShaderRegistry.ShaderBaseClass.FEEDBACK_TEXTURE].append(child)
		elif child is ExtendTextureRect:
			pools[ShaderRegistry.ShaderBaseClass.EXTEND_TEXTURE].append(child)

	for sig in active_instances:
		var instance = active_instances[sig]
		if not instance.alt_id:
			var already_processed = false
			if optimize_updates and _instance_state.has(sig):
				if is_instance_valid(_instance_state[sig].node) and used_nodes.has(_instance_state[sig].node):
					already_processed = true

			if not already_processed:
				var effect = instance.definition
				var params = instance.params
				var color = instance.color

				var type = ShaderRegistry.get_shader_effect_class(effect.effect_type)
				var node = _get_pooled_node(pools, type)
				if node:
					EffectUtils.setup_effect_node(node, effect, _label_viewport.get_texture(), _mask_viewport.get_texture(), type, params, color, sig, _palette_textures, border_size)
					if _instance_state.has(sig):
						_instance_state[sig].node = node

	for type in pools:
		while pools[type].size() > 5:
			pools[type].pop_back().queue_free()


func _get_pooled_node(pools: Dictionary, type: ShaderRegistry.ShaderBaseClass) -> Node:
	if not pools.has(type):
		return null
	if not pools[type].is_empty():
		return pools[type].pop_front()

	var node = EffectUtils.create_effect_node(type)

	if node:
		_margin_container.add_child(node)
	return node


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if scroll_active:
		warnings.append("Scroll is not yet supported with effects.")
	for effect in effect_definitions:
		if effect and effect.effect_type in ["Fuzzy", "Edge Shape", "Outline", "Outline Wobble", "Outline Cursor"]:
			warnings.append("The effect %s is no yet optimized and can be heavy on the GPU." % effect.effect_type)
	return warnings
