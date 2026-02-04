#gdlint: disable=max-line-length
@tool
class_name PreprocessTexture
extends ExtendTextureRect

static var _shader_cache: Dictionary = {}

## [b]Suffix[/b]
## [color=gray]Suffix to determine the type of preprocessing shader to use.[/color]
@export var suffix: String = "":
	set(value):
		if suffix != value:
			suffix = value
			_update_material_settings()

var _preprocessing: PreprocessViewportHandler


func _ready() -> void:
	super()
	_preprocessing = PreprocessViewportHandler.new()
	var shader_path = "res://addons/pixel_art_shaders/shaders/neighbor_preprocess/neighbor_preprocess" + suffix.replace("_pre", "") + ".gdshader"
	var shader: Shader
	if _shader_cache.has(shader_path):
		shader = _shader_cache[shader_path]
	else:
		shader = load(shader_path)
		if shader:
			_shader_cache[shader_path] = shader

	_preprocessing.apply_material = ShaderMaterial.new()
	_preprocessing.apply_material.shader = shader
	_preprocessing.target = self
	add_child(_preprocessing)


## [b]Reprocess Texture[/b]
## [color=gray]Manually reprocess the texture using the current preprocessing settings.[/color]
func reprocess() -> void:
	_preprocessing.preprocess()


func _update_material_settings() -> void:
	super()
	if is_instance_valid(_preprocessing) and is_instance_valid(_preprocessing.apply_material) and is_instance_valid(material):
		var shader_path = "res://addons/pixel_art_shaders/shaders/neighbor_preprocess/neighbor_preprocess" + suffix.replace("_pre", "") + ".gdshader"
		var shader: Shader
		if _shader_cache.has(shader_path):
			shader = _shader_cache[shader_path]
		else:
			shader = load(shader_path)
			if shader:
				_shader_cache[shader_path] = shader

		_preprocessing.apply_material.shader = shader
		material.set_shader_parameter("original_texture", original_texture)
		_preprocessing.preprocess()
