#gdlint: disable=max-line-length
@tool
class_name EffectWrapper
extends MarginContainer

## [b]Border Size[/b]
## [color=gray]Transparent padding around the effect for proper rendering.[/color]
## Prevents edge artifacts by providing extra space for visual effects to spread.
@export var border_size: Vector2 = Vector2.ZERO:
	set(value):
		border_size = value
		add_theme_constant_override("margin_left", -int(border_size.x))
		add_theme_constant_override("margin_right", -int(border_size.x))
		add_theme_constant_override("margin_top", -int(border_size.y))
		add_theme_constant_override("margin_bottom", -int(border_size.y))
		if is_instance_valid(_effect_node) and "border_size" in _effect_node:
			_effect_node.border_size = border_size
		size = Vector2.ZERO
		_on_effect_changed()

## [b]Effect[/b]
## [color=gray]The effect configuration to apply to the wrapped content.[/color]
@export var effect: EffectSetting:
	set(value):
		var previous_effect = effect
		var previous_effect_type = effect.effect_type if effect else ""
		if effect != value:
			_effect_type_changed = previous_effect_type != (value.effect_type if value else "")
			if effect and effect.changed.is_connected(_on_effect_changed):
				effect.changed.disconnect(_on_effect_changed)

			effect = value
			if effect and not effect.changed.is_connected(_on_effect_changed):
				effect.changed.connect(_on_effect_changed)
			_on_effect_changed()
			if effect:
				effect.active = true
			if not previous_effect:
				_on_size_changed()

## [b]Optimize Updates[/b]
## [color=gray]If true, updating the effect will only apply parameter changes instead of recreating the effect node.
## Note: Some effects, particularly those using preprocessing, may require a full reset (node recreation) to apply changes correctly.[/color]
@export var optimize_updates: bool = false

## [b]Use Fixed Size[/b]
## [color=gray]If enabled, the viewport uses the specified fixed size instead of dynamically adjusting to content.[/color]
@export var use_fixed_size: bool = false:
	set(value):
		use_fixed_size = value
		_on_effect_changed()

## [b]Fixed Size[/b]
## [color=gray]The size of the viewport when Use Fixed Size is enabled.[/color]
@export var fixed_size: Vector2i = Vector2i(100, 100):
	set(value):
		fixed_size = value
		_on_effect_changed()

## [b]Use Global Mouse[/b]
## [color=gray]If enabled, the wrapper automatically tracks the global mouse position.
## If disabled, you must call [_update_cursor_position](#method-_update_cursor_position) manually to update the cursor position in the effect.[/color]
@export var use_global_mouse: bool = true

var _cursor_position: Vector2 = Vector2(0.5, 0.5)
var _trigger_update: bool = false
var _effect_type_changed: bool = false
var _effect_node: Node
var _viewport: SubViewport
var _palette_textures: Dictionary = {}
var _anim_state: Dictionary = {"started": false, "time": 0.0, "params": {}}
var _last_content_rect: Rect2 = Rect2()
var _updating_viewport: bool = false


func _ready() -> void:
	for child in get_children(true):
		if child is SubViewport:
			_viewport = child
			_viewport.transparent_bg = true
			_viewport.disable_3d = true
		if child is FeedbackTextureMasked or child is ExtendTextureRect or child is PreprocessTexture:
			_effect_node = child
	if _viewport:
		_setup_viewport()

	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	_update_effect_node()
	_update_viewport()


func _process(delta: float) -> void:
	if not is_instance_valid(_viewport):
		for child in get_children(true):
			if child is SubViewport:
				_viewport = child
				_viewport.transparent_bg = true
				_viewport.disable_3d = true
				_trigger_update = true
			if child is FeedbackTextureMasked or child is ExtendTextureRect or child is PreprocessTexture:
				_effect_node = child
		if not _viewport:
			return

	if is_instance_valid(_effect_node) and effect and ShaderRegistry.check_cursor_support(effect.effect_type):
		if use_global_mouse:
			update_cursor_position(get_global_mouse_position())

	_check_children_changes()

	_process_animations(delta)

	if _trigger_update and not _updating_viewport:
		_update_effect_node()
		_update_viewport(true)
		_effect_type_changed = false
		_trigger_update = false


func play_animation(params: Dictionary = {}) -> void:
	_anim_state.params = params
	_anim_state.started = true
	_anim_state.time = 0.0


func stop_animation() -> void:
	_anim_state.started = false
	var mat: ShaderMaterial = null
	if _effect_node is FeedbackTextureMasked:
		mat = _effect_node.apply_material
	elif _effect_node.material is ShaderMaterial:
		mat = _effect_node.material

	if mat:
		mat.set_shader_parameter("time", 0.0)


func _process_animations(delta: float) -> void:
	if not _anim_state.started or not is_instance_valid(_effect_node) or not effect:
		return

	var params = _anim_state.params
	var duration = float(params.get("anim-duration", 1.0))
	var delay = float(params.get("anim-delay", 0.0))
	var inverse_val = params.get("anim-inverse", false)
	var inverse = str(inverse_val) == "true" if typeof(inverse_val) == TYPE_STRING else bool(inverse_val)
	var repeat = params.get("anim-repeat", "loop")

	_anim_state.time += delta

	var effective_time = max(0.0, _anim_state.time - delay)
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

	var mat: ShaderMaterial = null
	if _effect_node is FeedbackTextureMasked:
		mat = _effect_node.apply_material
	elif _effect_node.material is ShaderMaterial:
		mat = _effect_node.material

	if mat:
		if effect.normalize_time:
			mat.set_shader_parameter("time", t)
		else:
			mat.set_shader_parameter("time", -1.0)


func _setup_viewport() -> void:
	if not _viewport.child_entered_tree.is_connected(_on_child_entered):
		_viewport.child_entered_tree.connect(_on_child_entered)
	if not _viewport.child_exiting_tree.is_connected(_on_child_exiting):
		_viewport.child_exiting_tree.connect(_on_child_exiting)
	for child in _viewport.get_children():
		_connect_child(child)


func _gui_input(event: InputEvent) -> void:
	if _viewport:
		var new_event = event
		if "position" in event:
			new_event = event.duplicate()
			new_event.position += border_size
		_viewport.push_input(new_event)


## [b]Update Cursor Position[/b]
## [color=gray]Updates the cursor position for shader effects that track the mouse.[/color]
## This calculates the relative position within the wrapper's rect (0-1 range).
## [br]
## [param mouse_pos]: The global position of the mouse or simulated cursor.
func update_cursor_position(mouse_pos: Vector2) -> void:
	var rect = get_global_rect()
	if rect.size.x == 0 or rect.size.y == 0:
		return

	var rect_border_pos = rect.position - border_size * scale
	var rect_border_size = rect.size + scale * 2.0 * border_size
	var relative_pos = (mouse_pos - rect_border_pos) / rect_border_size
	_cursor_position = relative_pos

	var mat: ShaderMaterial = null
	if _effect_node is FeedbackTextureMasked:
		mat = _effect_node.apply_material
	elif _effect_node.material is ShaderMaterial:
		mat = _effect_node.material

	if mat:
		mat.set_shader_parameter("cursor_position", _cursor_position)


func _update_effect_node() -> void:
	if not effect:
		if is_instance_valid(_effect_node):
			_effect_node.queue_free()
			_effect_node = null
		return

	var type: ShaderRegistry.ShaderBaseClass = ShaderRegistry.get_shader_effect_class(effect.effect_type)
	var node_recreated = false

	if is_instance_valid(_effect_node):
		var current_type = ShaderRegistry.ShaderBaseClass.FEEDBACK_TEXTURE
		if _effect_node is ExtendTextureRect:
			current_type = ShaderRegistry.ShaderBaseClass.EXTEND_TEXTURE
		elif _effect_node is PreprocessTexture:
			current_type = ShaderRegistry.ShaderBaseClass.PREPROCESS_TEXTURE

		if current_type != type:
			_effect_node.queue_free()
			_effect_node = null

	if not is_instance_valid(_effect_node):
		_effect_node = EffectUtils.create_effect_node(type)
		if _effect_node:
			_effect_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_effect_node)
		node_recreated = true

	if _effect_node and _viewport:
		if optimize_updates and not node_recreated and not _effect_type_changed:
			EffectUtils.update_effect_parameters(_effect_node, effect, Color.WHITE, str(effect.get_instance_id()), _palette_textures)
		else:
			var original_texture = _viewport.get_texture()
			EffectUtils.setup_effect_node(_effect_node, effect, original_texture, null, type, {}, Color.WHITE, str(effect.get_instance_id()), _palette_textures, border_size)
			effect.effect_parameters.apply_non_shader_variables(_effect_node)


func _connect_child(node: Node) -> void:
	if node.is_queued_for_deletion():
		return

	if not node.child_entered_tree.is_connected(_on_child_entered):
		node.child_entered_tree.connect(_on_child_entered)
	if not node.child_exiting_tree.is_connected(_on_child_exiting):
		node.child_exiting_tree.connect(_on_child_exiting)

	for child in node.get_children():
		_connect_child(child)


func _disconnect_child(node: Node) -> void:
	if node.child_entered_tree.is_connected(_on_child_entered):
		node.child_entered_tree.disconnect(_on_child_entered)
	if node.child_exiting_tree.is_connected(_on_child_exiting):
		node.child_exiting_tree.disconnect(_on_child_exiting)

	for child in node.get_children():
		_disconnect_child(child)


func _check_children_changes() -> void:
	if use_fixed_size or _updating_viewport:
		return

	var rect = _get_content_rect()

	if _last_content_rect == null or not rect.is_equal_approx(_last_content_rect):
		_trigger_update = true


func _get_content_rect() -> Rect2:
	var all_canvas_items = _viewport.find_children("*", "CanvasItem", true, false)
	var rect: Rect2 = Rect2()
	var has_content = false

	for item in all_canvas_items:
		if not item.visible:
			continue

		var item_rect: Rect2 = Rect2(0, 0, 0, 0)
		if item is Node2D:
			item_rect = item.get_global_transform() * item.get_item_rect()
		elif item is Control:
			item_rect = item.get_global_rect()
		else:
			continue

		if item_rect.has_area():
			if not has_content:
				rect = item_rect
				has_content = true
			else:
				rect = rect.merge(item_rect)
	return rect


func _update_viewport(in_process: bool = false) -> void:
	if not _viewport:
		return

	if use_fixed_size:
		if _viewport.size != fixed_size:
			_viewport.size = fixed_size
		if is_instance_valid(_effect_node) and _effect_node.size != Vector2(fixed_size):
			_effect_node.size = Vector2(fixed_size)
			if "original_texture" in _effect_node:
				_effect_node.original_texture = _viewport.get_texture()
		if in_process:
			await get_tree().process_frame
		size = Vector2.ZERO
		return

	_updating_viewport = true
	var rect = _get_content_rect()
	var has_content = rect.has_area()

	if has_content:
		if in_process:
			await get_tree().process_frame
		var offset = border_size - rect.position
		if offset != Vector2.ZERO and offset.length_squared() > 0.001:
			for child in _viewport.get_children():
				if child is Node2D or child is Control:
					child.position += offset
			rect.position = border_size

		var new_size = (rect.size + border_size * 2.0).max(Vector2(1, 1))
		if _viewport.size != Vector2i(new_size):
			_viewport.size = Vector2i(new_size)
		if _effect_node and _effect_node.size != new_size:
			_effect_node.size = new_size
			if "original_texture" in _effect_node:
				_effect_node.original_texture = _viewport.get_texture()
			_last_content_rect = Rect2(border_size, rect.size)

	if in_process:
		await get_tree().process_frame
	size = Vector2.ZERO
	_updating_viewport = false


func _on_size_changed() -> void:
	if !use_fixed_size:
		_trigger_update = true


func _on_effect_changed() -> void:
	_trigger_update = true


func _on_child_entered(node: Node) -> void:
	_connect_child(node)
	_on_effect_changed()


func _on_child_exiting(node: Node) -> void:
	_disconnect_child(node)
	_on_effect_changed()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not _has_subviewport():
		warnings.append("This node requires a SubViewport child.")
	if effect == null:
		warnings.append("No effect is assigned. The content will not be visible.")
	if effect and effect.effect_type in ["Fuzzy", "Edge Shape", "Outline", "Outline Wobble", "Outline Cursor"]:
		warnings.append("The selected effect is no yet optimized and can be heavy on the GPU.")
	return warnings


func _has_subviewport() -> bool:
	if _viewport:
		return true
	for child in get_children():
		if child is SubViewport:
			return true
	return false


func _on_mouse_exited() -> void:
	if _viewport:
		var event = InputEventMouseMotion.new()
		event.position = Vector2(-10000, -10000)
		event.global_position = Vector2(-10000, -10000)
		_viewport.push_input(event)
