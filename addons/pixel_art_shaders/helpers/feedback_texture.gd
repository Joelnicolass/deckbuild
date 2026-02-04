#gdlint: disable=max-line-length
@tool
class_name FeedbackTexture
extends TextureRect

## [b]Border Size[/b]
## [color=gray]Transparent padding around the texture for feedback effects.[/color]
## Prevents edge artifacts by providing extra space for visual feedback to spread.
@export var border_size: Vector2 = Vector2(10, 10):
	set(value):
		border_size = value
		_update_texture()

## [b]Original Texture[/b]
## [color=gray]Source texture for the feedback effect.[/color]
## The feedback shader will continuously process this texture using previous frames.
@export var original_texture: Texture:
	set(value):
		original_texture = value
		_update_texture()

## [b]Update FPS[/b]
## [color=gray]Target frames per second for the feedback loop.[/color]
## Limits how often the feedback texture is updated.
@export var fps: float = 60.0

## [b]Applied Shader Material[/b]
## [color=gray]ShaderMaterial used to process the feedback effect.[/color]
## Automatically assigned to the internal TextureRect and wired with the previous frame buffer.
@export var apply_material: ShaderMaterial:
	set(value):
		apply_material = value
		_update_material_settings()

## [b]Show Original Layer[/b]
## [color=gray]Toggle visibility of the original texture behind the feedback output.[/color]
@export var show_original: bool = true:
	set(value):
		show_original = value
		if is_instance_valid(_original_rect):
			_original_rect.visible = show_original
			_original_rect.z_index = -1 if original_behind else 0

## [b]Original Behind[/b]
## [color=gray]Place the original texture behind the feedback output.[/color]
@export var original_behind: bool = true:
	set(value):
		original_behind = value
		if is_instance_valid(_original_rect):
			_original_rect.z_index = -1 if original_behind else 0

var _original_rect: TextureRect
var _viewport_texture: Array[Texture2D] = [null, null]
var _viewport: Array[SubViewport] = [null, null]
var _texture_rect: Array[TextureRect] = [null, null]
var _current_buffer_index: int = 0
var _iteration_count: int = 0
var _time_accumulator: float = 0.0
var _updating_texture: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_horizontal = 0
	size_flags_vertical = 0
	var viewport_count: int = 0
	_viewport = [null, null]
	_texture_rect = [null, null]
	for child in get_children():
		if child is SubViewport:
			_viewport[viewport_count] = child
			for subchild in child.get_children():
				if subchild is TextureRect:
					_texture_rect[viewport_count] = subchild
			viewport_count += 1
			if viewport_count >= 2:
				break
	for i in range(2):
		if _viewport[i] == null:
			_viewport[i] = SubViewport.new()
			_viewport[i].disable_3d = true
			_viewport[i].transparent_bg = true
			add_child(_viewport[i])
		if _texture_rect[i] == null:
			_texture_rect[i] = TextureRect.new()
			_texture_rect[i].material = apply_material
			_viewport[i].add_child(_texture_rect[i])

	_original_rect = TextureRect.new()
	add_child(_original_rect)
	_original_rect.z_index = -1 if original_behind else 0
	_original_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_original_rect.visible = show_original

	_update_material_settings()

	for i in range(2):
		_viewport[i].render_target_update_mode = SubViewport.UPDATE_ONCE
		_viewport[i].render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		_viewport_texture[i] = _viewport[i].get_texture()
	_setup_texture()


func _process(delta) -> void:
	if not _texture_rect[0].material or not _texture_rect[1].material:
		return

	if _updating_texture:
		_setup_texture()
		_updating_texture = false

	if fps > 0.0:
		_time_accumulator += delta
		if _time_accumulator < 1.0 / fps:
			_viewport[_current_buffer_index].render_target_update_mode = SubViewport.UPDATE_DISABLED
			return
		if _time_accumulator >= 1.0 / fps:
			_iteration_count += 1
			_viewport[_current_buffer_index].render_target_update_mode = SubViewport.UPDATE_ONCE
			_texture_rect[_current_buffer_index].material.set_shader_parameter("iteration_count", _iteration_count)
			_time_accumulator -= (1.0 / fps)
		if _time_accumulator > 1.0 / fps:
			_time_accumulator = 1.0 / fps
		_swap_viewport_texture.call_deferred(true)
	else:
		_viewport[_current_buffer_index].render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_iteration_count += 1
		_texture_rect[_current_buffer_index].material.set_shader_parameter("iteration_count", _iteration_count)
		_swap_viewport_texture.call_deferred(true)


func _swap_viewport_texture(wait: bool = false) -> void:
	if wait:
		await RenderingServer.frame_post_draw
	texture = _viewport_texture[_current_buffer_index]
	_current_buffer_index = 1 - _current_buffer_index


func _update_material_settings() -> void:
	if is_instance_valid(_texture_rect[0]) and is_instance_valid(_texture_rect[1]) and is_instance_valid(apply_material):
		for i in range(2):
			_texture_rect[i].material = apply_material
			_texture_rect[i].material.set_shader_parameter("original_texture", original_texture)
			_texture_rect[i].material.set_shader_parameter("border_pixels", border_size)


func _update_texture() -> void:
	_updating_texture = true


func _setup_texture() -> void:
	if not is_instance_valid(_viewport[0]) or not is_instance_valid(_viewport[1]) or not is_instance_valid(original_texture) or not is_instance_valid(apply_material):
		return

	if border_size == Vector2.ZERO:
		var size = original_texture.get_size()
		var width: int = size.x
		var height: int = size.y
		for i in range(2):
			_viewport[i].size = Vector2i(width, height)
			_viewport_texture[i] = _viewport[i].get_texture()

		texture = original_texture

		_texture_rect[0].texture = _viewport_texture[1]
		_texture_rect[1].texture = _viewport_texture[0]
		_update_material_settings()
		_original_rect.texture = original_texture
		_original_rect.position = Vector2(border_size.x, border_size.y)
		_original_rect.size = original_texture.get_size()

		size = Vector2i(width, height)
	else:
		var orig_img: Image = original_texture.get_image()
		if not is_instance_valid(orig_img):
			return

		var width: int = orig_img.get_width() + int(border_size.x) * 2
		var height: int = orig_img.get_height() + int(border_size.y) * 2
		for i in range(2):
			_viewport[i].size = Vector2i(width, height)
			_viewport_texture[i] = _viewport[i].get_texture()

		texture = _viewport_texture[_current_buffer_index]

		_texture_rect[0].texture = _viewport_texture[1]
		_texture_rect[1].texture = _viewport_texture[0]
		_update_material_settings()
		_original_rect.texture = original_texture
		_original_rect.position = Vector2(border_size.x, border_size.y)
		_original_rect.size = original_texture.get_size()

		size = Vector2i(width, height)
