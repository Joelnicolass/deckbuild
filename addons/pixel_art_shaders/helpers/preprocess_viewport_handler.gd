#gdlint: disable=max-line-length
@tool
class_name PreprocessViewportHandler
extends Node

## [b]Update Texture[/b]
## [color=gray]Manually reprocess the texture using the current preprocessing settings.[/color]
@export_tool_button("Update Texture") var generate_button := Callable(self, "preprocess")

### [b]Applied Material[/b]
### [color=gray]Material used for preprocessing the texture.[/color]
@export var apply_material: Material:
	set(value):
		apply_material = value
		_update_material()

## [b]Preprocess Scale[/b]
## [color=gray]Scale factor applied during preprocessing.[/color]
@export var preprocess_scale: float = 1.0:
	set(value):
		preprocess_scale = value
		_update_material()

## [b]Target TextureRect[/b]
## [color=gray]The ExtendTextureRect node whose texture will be preprocessed.[/color]
@export var target: ExtendTextureRect:
	set(value):
		target = value
		_update_material()

var _preprocessed_texture: Texture2D
var _sub_viewport: SubViewport
var _extend_texture_rect: ExtendTextureRect


func _ready() -> void:
	_sub_viewport = SubViewport.new()
	_sub_viewport.transparent_bg = true
	_sub_viewport.disable_3d = true
	_sub_viewport.oversampling = false
	_sub_viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
	_sub_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_extend_texture_rect = ExtendTextureRect.new()
	_sub_viewport.add_child(_extend_texture_rect)
	add_child(_sub_viewport)

	_update_material()


func _process(_delta: float) -> void:
	if _sub_viewport.size != Vector2i(_extend_texture_rect.size):
		_sub_viewport.size = _extend_texture_rect.size
		preprocess()


## [b]Preprocess Texture[/b]
## [color=gray]Preprocess the texture using the current settings.[/color]
func preprocess() -> void:
	_update_material()


## [b]Save to PNG[/b]
## [color=gray]Save the preprocessed texture to a PNG file at the specified path.[/color]
## @param path The file path where the PNG will be saved.
func save_to_png(path: String) -> void:
	if not _preprocessed_texture:
		push_error("Preprocessed texture is not available.")
		return

	var image := _preprocessed_texture.get_image()
	if not image:
		push_error("Could not retrieve image from texture.")
		return

	if OS.get_name() == "Web":
		var buffer = image.save_png_to_buffer()
		var filename = path.get_file()
		if filename.is_empty():
			filename = "preprocess_texture.png"
		JavaScriptBridge.download_buffer(buffer, filename, "image/png")
	else:
		var error := image.save_png(path)
		if error != OK:
			push_error("Failed to save texture to %s: %s" % [path, error_string(error)])
		else:
			print("Texture saved to %s" % path)


func _update_material() -> void:
	if is_instance_valid(_extend_texture_rect) and is_instance_valid(target):
		_extend_texture_rect.scale = Vector2(preprocess_scale, preprocess_scale)
		_extend_texture_rect.border_size = target.border_size
		_extend_texture_rect.original_texture = target.original_texture
		_extend_texture_rect.mask_texture = target.mask_texture
		_extend_texture_rect.mask_color = target.mask_color
		_extend_texture_rect.use_mask_color = target.use_mask_color
		_extend_texture_rect.material = apply_material
		_sub_viewport.size = _extend_texture_rect.size * _extend_texture_rect.scale
		_preprocessed_texture = _sub_viewport.get_texture()

		var sm: ShaderMaterial = target.material
		if is_instance_valid(sm):
			sm.set_shader_parameter("preprocess_data_texture", _preprocessed_texture)
			apply_material.set_shader_parameter("keep_border_colors", sm.get_shader_parameter("keep_border_colors"))
			apply_material.set_shader_parameter("input_palette_texture", sm.get_shader_parameter("input_palette_texture"))
			apply_material.set_shader_parameter("palette_diff_threshold", sm.get_shader_parameter("palette_diff_threshold"))
			apply_material.set_shader_parameter("offset_scale", sm.get_shader_parameter("offset_scale"))
			apply_material.set_shader_parameter("ignore_palette", sm.get_shader_parameter("ignore_palette"))
			apply_material.set_shader_parameter("use_input_texture", sm.get_shader_parameter("use_input_texture"))

		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
