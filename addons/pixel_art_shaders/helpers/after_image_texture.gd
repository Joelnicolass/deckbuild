#gdlint: disable=max-line-length
@tool
class_name AfterImageTextureRect
extends ExtendTextureRect

## [b]Palette Texture[/b]
## [color=gray]1×N pixel texture where each pixel represents a palette color for afterimages.[/color]
@export var palette_texture: Texture:
	set(value):
		palette_texture = value
		_setup_texture()

## [b]Inverse Palette[/b]
## [color=gray]Reverses the order of palette colors applied to afterimages.[/color]
## When [code]true[/code], the first afterimage uses the last palette color.
@export var inverse_palette: bool = false:
	set(value):
		inverse_palette = value
		_setup_texture()

## [b]Palette Offset[/b]
## [color=gray]Starting index in the palette texture (0-based).[/color]
## Use this to skip the first N colors in the palette.
@export var palette_offset: int = 0:
	set(value):
		palette_offset = max(0, value)
		_setup_texture()

## [b]Palette Range[/b]
## [color=gray]Number of palette colors to use for afterimages.[/color]
## Set to [code]-1[/code] to use all remaining colors from offset.
@export var palette_range: int = -1:
	set(value):
		palette_range = value
		_setup_texture()

## [b]Delay Between Images[/b]
## [color=gray]Time in seconds between spawning new afterimage instances.[/color]
## Lower values create denser trails, higher values create more spaced trails.
@export var delay_between_images: float = 0.05

## [b]Interpolate Positions[/b]
## [color=gray]Smoothly interpolate afterimage positions between updates.[/color]
## When [code]true[/code], creates fluid motion; when [code]false[/code], afterimages snap instantly.
@export var interpolate_positions: bool = true

## [b]Pixel Perfect[/b]
## [color=gray]Snap positions to pixel grid based on scale.[/color]
## Prevents sub-pixel rendering for crisp pixel art appearance.
@export var pixel_perfect: bool = true

## [b]Follow Position[/b]
## [color=gray]The global position that afterimages will follow.[/color]
var follow_position: Vector2 = Vector2.ZERO

var _afterimage_nodes: Array[TextureRect] = []
var _position_history: Array[Vector2] = []
var _last_positions: Array[Vector2] = []
var _time_accumulator: float = 0.0
var _palette_size: int = 0


func _ready() -> void:
	follow_position = global_position + get_rect().size / 2.0
	_setup_texture()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	global_position = _get_next_position()

	_time_accumulator += delta

	if _time_accumulator >= delay_between_images:
		_time_accumulator = 0.0

		for i in range(_afterimage_nodes.size()):
			if is_instance_valid(_afterimage_nodes[i]):
				_last_positions[i] = _afterimage_nodes[i].global_position

		_position_history.push_front(global_position)

		if _position_history.size() > _palette_size:
			_position_history.resize(_palette_size)

	_update_afterimage_positions()


## [b]Track Position[/b]
## [color=gray]Set the position to follow for afterimages.[/color]
## @param pos The global position to track.
func set_track_position(pos: Vector2) -> void:
	follow_position = pos


func _setup_texture() -> void:
	super()
	for node in _afterimage_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_afterimage_nodes.clear()
	_position_history.clear()

	if not original_texture or not palette_texture or not material:
		return

	material.set_shader_parameter("effect_palette_texture", palette_texture)

	var palette_img: Image = palette_texture.get_image()
	_palette_size = palette_img.get_width()

	var palette_start = min(max(palette_offset, 0), _palette_size - 1)
	var effective_palette_range = palette_range if palette_range >= 0 else _palette_size
	var palette_end = min(palette_offset + effective_palette_range, _palette_size)
	_position_history.resize(palette_end - palette_start)
	_last_positions.resize(palette_end - palette_start)
	for i in range(palette_end - palette_start):
		var afterimage := TextureRect.new()
		afterimage.texture = texture
		afterimage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		afterimage.z_index = -i - 1

		var copy_material := material.duplicate()
		var palette_id = palette_start + i
		if inverse_palette:
			palette_id = _palette_size - (i + palette_start)
		copy_material.set_shader_parameter("palette_id", palette_id)
		afterimage.material = copy_material

		add_child(afterimage)
		_afterimage_nodes.append(afterimage)
		_position_history[i] = global_position
		_last_positions[i] = global_position


func _get_next_position() -> Vector2:
	if pixel_perfect:
		return scale * floor((follow_position - get_rect().size / 2.0) / scale)
	return follow_position - get_rect().size / 2.0


func _update_afterimage_positions() -> void:
	var t = _time_accumulator / delay_between_images if interpolate_positions else 0.0

	for i in range(_afterimage_nodes.size()):
		if is_instance_valid(_afterimage_nodes[i]):
			if interpolate_positions and i < _position_history.size():
				var target_pos = _position_history[i]
				var start_pos = _last_positions[i]

				_afterimage_nodes[i].global_position = start_pos.lerp(target_pos, t)
			else:
				_afterimage_nodes[i].global_position = _position_history[i]
