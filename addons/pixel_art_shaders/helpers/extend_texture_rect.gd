#gdlint: disable=max-line-length
@tool
class_name ExtendTextureRect
extends TextureRect

## [b]Border Size[/b]
## [color=gray]Transparent padding added around the original texture in pixels.[/color]
## [code]x[/code] = horizontal padding, [code]y[/code] = vertical padding
@export var border_size: Vector2 = Vector2(10, 10):
	set(value):
		border_size = value
		_update_texture()

## [b]Original Texture[/b]
## [color=gray]Source texture to extend with transparent borders.[/color]
## The extended texture is automatically generated and assigned.
@export var original_texture: Texture:
	set(value):
		original_texture = value
		_update_texture()

## [b]Mask Texture[/b]
## [color=gray]Optional texture to use as a mask for the extended area.[/color]
@export var mask_texture: Texture:
	set(value):
		mask_texture = value
		_update_material_settings()

## [b]Use Mask Color[/b]
## [color=gray]If enabled, the specified mask color will be applied to the extended area.[/color]
@export var use_mask_color: bool = false:
	set(value):
		use_mask_color = value
		_update_material_settings()

## [b]Mask Color[/b]
## [color=gray]Color to apply to the extended area if 'Use Mask Color' is enabled.[/color]
@export var mask_color: Color = Color.WHITE:
	set(value):
		mask_color = value
		_update_material_settings()

var _trigger_update: bool = false
var _texture_image: Image


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_horizontal = 0
	size_flags_vertical = 0
	_setup_texture()


func _process(_delta: float) -> void:
	if _trigger_update:
		_setup_texture()
		_trigger_update = false


func _update_texture() -> void:
	_trigger_update = true


func _update_material_settings() -> void:
	if is_instance_valid(material):
		material.set_shader_parameter("original_texture", original_texture)
		material.set_shader_parameter("border_pixels", border_size)
		if use_mask_color:
			material.set_shader_parameter("use_mask_color", true)
			material.set_shader_parameter("mask_color", mask_color)
		else:
			material.set_shader_parameter("use_mask_color", false)
			material.set_shader_parameter("mask_color", mask_color)
		if is_instance_valid(mask_texture):
			material.set_shader_parameter("use_mask_texture", true)
			material.set_shader_parameter("mask_texture", mask_texture)
		else:
			material.set_shader_parameter("use_mask_texture", false)


func _setup_texture() -> void:
	if not is_instance_valid(original_texture) or not is_instance_valid(material):
		return

	if border_size == Vector2.ZERO:
		var size = original_texture.get_size()
		texture = original_texture
		size = Vector2i(size.x, size.y)
	else:
		var orig_img: Image = original_texture.get_image()
		var orig_width: int = orig_img.get_width()
		var orig_height: int = orig_img.get_height()
		var width: int = orig_width + int(border_size.x) * 2
		var height: int = orig_height + int(border_size.y) * 2

		if _texture_image == null:
			_texture_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
		elif _texture_image.get_width() != width or _texture_image.get_height() != height:
			_texture_image.resize(width, height)
		var offset_x: int = int(border_size.x)
		var offset_y: int = int(border_size.y)
		_texture_image.blit_rect(orig_img, Rect2i(0, 0, orig_width, orig_height), Vector2i(offset_x, offset_y))
		texture = ImageTexture.create_from_image(_texture_image)

		size = Vector2i(width, height)
	_update_material_settings()
