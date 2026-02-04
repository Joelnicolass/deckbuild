#gdlint: disable=max-line-length
class_name EffectUtils
extends Object

static var _texture_cache: Dictionary = {}


## [b]Setup Effect Node[/b]
## Configures a given node with the provided effect settings, textures, and parameters.
## [param node]: The node to configure (must be one of the supported types from [code]create_effect_node[/code]).
## [param effect]: The [EffectSetting] resource containing shader and parameter definitions.
## [param original_texture]: The source texture to apply the effect to.
## [param mask_texture]: An optional mask texture for the effect.
## [param type]: The shader base class type (Feedback, Extend, or Preprocess).
## [param params]: A dictionary of runtime shader parameters (e.g., "time").
## [param color]: The base color to use for masking or extending.
## [param signature]: A unique identifier string for palette caching.
## [param palette_cache]: A dictionary used to cache generated palette textures.
## [param border_size]: The size of the border padding around the effect in pixels.
static func setup_effect_node(node: Node, effect: EffectSetting, original_texture: Texture, mask_texture: Texture, type: ShaderRegistry.ShaderBaseClass, params: Dictionary, color: Color, signature: String, palette_cache: Dictionary, border_size: Vector2) -> void:
	var shader = ShaderRegistry.load_shader(effect.effect_type, effect.suffix)
	if not is_instance_valid(shader):
		return

	var mat = ShaderMaterial.new()
	mat.shader = shader

	var input_colors_set = false
	var effect_colors_set = false
	for param in effect.effect_parameters.get_parameters():
		var val = effect.effect_parameters.get_value(param)
		if typeof(val) == TYPE_STRING and param.ends_with("_texture") and val != "":
			var loaded_tex
			if _texture_cache.has(val):
				loaded_tex = _texture_cache[val]
			else:
				loaded_tex = load(val)
				if loaded_tex is Texture:
					_texture_cache[val] = loaded_tex

			if loaded_tex is Texture:
				mat.set_shader_parameter(param, loaded_tex)
			if param == "input_palette_texture":
				input_colors_set = true
				palette_cache[signature + "_input"] = loaded_tex
			elif param == "effect_palette_texture":
				effect_colors_set = true
				palette_cache[signature + "_effect"] = loaded_tex
		else:
			mat.set_shader_parameter(param, val)
	effect.effect_parameters.apply_non_shader_variables(node)

	for param in params:
		if param == "time":
			mat.set_shader_parameter("time", float(params[param]))
	mat.set_shader_parameter("use_input_texture", true)

	var fallback_palette: Array[Color] = [color]
	if not input_colors_set:
		var input_colors: Array[Color] = effect.input_palette if effect.input_palette.size() > 0 else fallback_palette
		var tex = create_palette_texture(input_colors)
		palette_cache[signature + "_input"] = tex
		mat.set_shader_parameter("input_palette_texture", tex)

	if not effect_colors_set:
		var effect_colors: Array[Color] = effect.effect_palette if effect.effect_palette.size() > 0 else fallback_palette
		var tex = create_palette_texture(effect_colors)
		palette_cache[signature + "_effect"] = tex
		mat.set_shader_parameter("effect_palette_texture", tex)

	node.visible = effect.active
	node.z_index = -1

	match type:
		ShaderRegistry.ShaderBaseClass.EXTEND_TEXTURE:
			var extend_node = node as ExtendTextureRect
			extend_node.material = mat
			extend_node.border_size = Vector2.ZERO
			if original_texture != null:
				extend_node.original_texture = original_texture
			if mask_texture != null:
				extend_node.mask_texture = mask_texture
			extend_node.mask_color = color
		ShaderRegistry.ShaderBaseClass.FEEDBACK_TEXTURE:
			var feedback_node = node as FeedbackTextureMasked
			feedback_node.apply_material = mat
			feedback_node.show_original = false
			feedback_node.border_size = Vector2.ZERO
			if original_texture != null:
				feedback_node.original_texture = original_texture
			if mask_texture != null:
				feedback_node.mask_texture = mask_texture
			feedback_node.mask_color = color
		ShaderRegistry.ShaderBaseClass.PREPROCESS_TEXTURE:
			var preprocess_node = node as PreprocessTexture
			preprocess_node.suffix = effect.suffix
			preprocess_node.material = mat
			preprocess_node.border_size = Vector2.ZERO
			if original_texture != null:
				preprocess_node.original_texture = original_texture
			if mask_texture != null:
				preprocess_node.mask_texture = mask_texture
			preprocess_node.mask_color = color
			preprocess_node.reprocess()


## [b]Create Palette Texture[/b]
## Generates a 1xN [ImageTexture] from an array of colors.
## [param colors]: The array of colors to include in the palette.
## [return]: A new [ImageTexture] containing the palette colors.
static func create_palette_texture(colors: Array[Color]) -> ImageTexture:
	var image = Image.create(colors.size(), 1, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		image.set_pixel(i, 0, colors[i])
	var tex = ImageTexture.create_from_image(image)
	return tex


## [b]Create Effect Node[/b]
## Instantiates a new effect node based on the requested shader base class type.
## [param type]: The [enum ShaderRegistry.ShaderBaseClass] identifying the type of node to create.
## [return]: A new instance of [FeedbackTextureMasked], [ExtendTextureRect], or [PreprocessTexture], or [code]null[/code] if the type is unknown.
static func create_effect_node(type: ShaderRegistry.ShaderBaseClass) -> Node:
	match type:
		ShaderRegistry.ShaderBaseClass.FEEDBACK_TEXTURE:
			return FeedbackTextureMasked.new()
		ShaderRegistry.ShaderBaseClass.EXTEND_TEXTURE:
			return ExtendTextureRect.new()
		ShaderRegistry.ShaderBaseClass.PREPROCESS_TEXTURE:
			return PreprocessTexture.new()
	return null


## [b]Deep Copy[/b]
## Creates a deep copy of a Variant (Array or Dictionary), or returns the value if it's a primitive.
## [param val]: The value to copy.
## [return]: A duplicate of the value.
static func deep_copy(val) -> Variant:
	if val is Array:
		return val.duplicate(true)
	if val is Dictionary:
		return val.duplicate(true)
	return val


## [b]Is Equal[/b]
## Compares two Variants for equality, supporting deep comparison for Arrays and Dictionaries.
## [param a]: The first value.
## [param b]: The second value.
## [return]: [code]true[/code] if the values are equal, [code]false[/code] otherwise.
static func is_equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		return a.hash() == b.hash()
	if a is Dictionary:
		return a.hash() == b.hash()
	return a == b


## [b]Update Effect Parameters[/b]
## Updates the shader parameters and non-shader variables of an existing effect node without resetting it.
## [param node]: The effect node to update.
## [param effect]: The [EffectSetting] resource containing new values.
## [param color]: The base color for palette generation fallback.
## [param signature]: A unique identifier string for palette caching.
## [param palette_cache]: A dictionary used to cache generated palette textures.
static func update_effect_parameters(node: Node, effect: EffectSetting, color: Color, signature: String, palette_cache: Dictionary) -> void:
	var mat: ShaderMaterial = null
	if node is ExtendTextureRect:
		mat = (node as ExtendTextureRect).material as ShaderMaterial
	elif node is FeedbackTextureMasked:
		mat = (node as FeedbackTextureMasked).apply_material as ShaderMaterial
	elif node is PreprocessTexture:
		mat = (node as PreprocessTexture).material as ShaderMaterial

	if not mat:
		return

	var input_colors_set = false
	var effect_colors_set = false
	for param in effect.effect_parameters.get_parameters():
		var val = effect.effect_parameters.get_value(param)
		if typeof(val) == TYPE_STRING and param.ends_with("_texture") and val != "":
			var loaded_tex
			if _texture_cache.has(val):
				loaded_tex = _texture_cache[val]
			else:
				loaded_tex = load(val)
				if loaded_tex is Texture:
					_texture_cache[val] = loaded_tex

			if loaded_tex is Texture:
				mat.set_shader_parameter(param, loaded_tex)
			if param == "input_palette_texture":
				input_colors_set = true
				palette_cache[signature + "_input"] = loaded_tex
			elif param == "effect_palette_texture":
				effect_colors_set = true
				palette_cache[signature + "_effect"] = loaded_tex
		else:
			mat.set_shader_parameter(param, val)
	effect.effect_parameters.apply_non_shader_variables(node)

	var fallback_palette: Array[Color] = [color]
	if not input_colors_set:
		var input_colors: Array[Color] = effect.input_palette if effect.input_palette.size() > 0 else fallback_palette
		var tex = create_palette_texture(input_colors)
		palette_cache[signature + "_input"] = tex
		mat.set_shader_parameter("input_palette_texture", tex)

	if not effect_colors_set:
		var effect_colors: Array[Color] = effect.effect_palette if effect.effect_palette.size() > 0 else fallback_palette
		var tex = create_palette_texture(effect_colors)
		palette_cache[signature + "_effect"] = tex
		mat.set_shader_parameter("effect_palette_texture", tex)

	node.visible = effect.active
