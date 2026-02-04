#gdlint: disable=max-line-length
class_name ShaderRegistry
extends Object

enum ShaderBaseClass { FEEDBACK_TEXTURE, PREPROCESS_TEXTURE, EXTEND_TEXTURE }

const SHADER_PATH_BASE: String = "res://addons/pixel_art_shaders/shaders/"
const SHADER_CONFIGS = [
	{"name": "Iterative Fire", "sub-pixels": false, "render-mode": "always", "second-palette": true, "object-type": "feedback", "base-name": "iterative_fire", "suffix": "_ext", "supports_cursor": false, "tooltip": "Animated fire effect using iterative pixel updates."},
	{"name": "Outline Wobble", "sub-pixels": false, "render-mode": "always", "second-palette": false, "object-type": "default", "base-name": "outline", "sub-name": "_wobble", "supports_cursor": false, "tooltip": "Animated outline using tiled noise to produce a subtle wobble."},
	{"name": "Dissolve", "sub-pixels": false, "render-mode": "always", "second-palette": false, "object-type": "default", "base-name": "dissolve", "supports_cursor": false, "tooltip": "Noise-driven palette dissolve with optional palette shifting."},
	{"name": "Afterimage", "sub-pixels": true, "render-mode": "always", "second-palette": false, "object-type": "default", "base-name": "afterimage", "suffix": "_ext", "supports_cursor": false, "tooltip": "Rotating afterimage effect behind the sprite"},
	{"name": "Outline Cursor", "sub-pixels": false, "render-mode": "always", "second-palette": false, "object-type": "default", "base-name": "outline", "sub-name": "_cursor", "supports_cursor": true, "tooltip": "Outline effect that can be focused around the cursor position."},
	{"name": "Fuzzy", "sub-pixels": false, "render-mode": "always", "second-palette": false, "object-type": "default", "base-name": "fuzzy", "supports_cursor": false, "tooltip": "Adds randomized fuzziness to pixels for a soft, noisy look."},
	{"name": "Outline", "sub-pixels": true, "render-mode": "once", "second-palette": false, "object-type": "default", "base-name": "outline", "supports_cursor": false, "tooltip": "Simple palette-based outline effect."},
	{"name": "Edge Shape", "sub-pixels": true, "render-mode": "once", "second-palette": false, "object-type": "default", "base-name": "edge_shape", "supports_cursor": false, "tooltip": "Edge-aware pixel shapes with corner controls."},
	{"name": "Basic Shape", "sub-pixels": true, "render-mode": "once", "second-palette": false, "object-type": "default", "base-name": "basic_shape", "supports_cursor": false, "tooltip": "Render pixels as shapes (circle, diamond, hexagon, etc.)."},
	{"name": "Smooth Borders", "sub-pixels": false, "render-mode": "once", "second-palette": false, "object-type": "default", "base-name": "smooth_borders", "supports_cursor": false, "tooltip": "Smooth color transitions by evaluating palette neighborhood majority."},
]

static var _shader_cache: Dictionary = {}


## [b]Get Shader Type[/b]
## [color=gray]Returns the type identifier for a given shader name.[/color]
## @param shader_name The name of the shader.
## @return The type identifier as a string.
static func get_shader_type(shader_name: String) -> String:
	match shader_name:
		"Outline":
			return "outline"
		"Outline Wobble":
			return "outline_wobble"
		"Outline Cursor":
			return "outline_cursor"
		"Fuzzy":
			return "fuzzy"
		"Basic Shape":
			return "basic_shape"
		"Edge Shape":
			return "edge_shape"
		"Smooth Borders":
			return "smooth_borders"
		"Dissolve":
			return "dissolve"
		"Afterimage":
			return "afterimage"
		"Iterative Fire":
			return "iterative_fire"
	return ""


## [b]Get Shader Effect Class[/b]
## [color=gray]Returns the effect class name associated with a given shader name.[/color]
## @param shader_name The name of the shader.
## @return The effect class as a ShaderBaseClass enum value.
static func get_shader_effect_class(shader_name: String) -> ShaderBaseClass:
	match shader_name:
		"Iterative Fire":
			return ShaderBaseClass.FEEDBACK_TEXTURE
		"Dissolve", "Afterimage", "Fuzzy", "Edge Shape":
			return ShaderBaseClass.EXTEND_TEXTURE
		"Outline", "Outline Wobble", "Outline Cursor":
			# Disabling preprocessing until it works on all platforms and works properly in Godot 4.6
			#if OS.get_name() == "Web":
			#	return ShaderBaseClass.EXTEND_TEXTURE
			#return ShaderBaseClass.PREPROCESS_TEXTURE
			return ShaderBaseClass.EXTEND_TEXTURE
	return ShaderBaseClass.EXTEND_TEXTURE


## [b]Load Shader[/b]
## [color=gray]Loads a shader resource based on the shader name and optional suffix.[/color]
## @param shader The name of the shader to load.
## @param suffix An optional suffix to append to the shader file name.
## @return The loaded Shader resource, or null if not found.
static func load_shader(shader: String, suffix: String = "") -> Shader:
	var cache_key = shader + "::" + suffix
	if _shader_cache.has(cache_key):
		return _shader_cache[cache_key]

	for config in SHADER_CONFIGS:
		if config.name == shader:
			var shader_folder = config.get("base-name", "")
			var shader_name = shader_folder + config.get("sub-name", "")
			var shader_path = SHADER_PATH_BASE + shader_folder + "/" + shader_name + suffix + ".gdshader"
			if config.name in ["Smooth Borders"]:
				shader_path = SHADER_PATH_BASE + shader_name + suffix + ".gdshader"

			if not ResourceLoader.exists(shader_path):
				push_error("Shader file not found: " + shader_path)
				return null

			var loaded_shader = load(shader_path)
			_shader_cache[cache_key] = loaded_shader
			return loaded_shader

	push_error("Shader not found in registry: " + shader)
	return null


## [b]Get Available Shaders[/b]
## [color=gray]Returns an array of dictionaries containing information about all available shaders.[/color]
## @return An array of dictionaries with shader details.
static func get_available_shaders() -> Array[Dictionary]:
	var available_shaders: Array[Dictionary] = []
	for config in SHADER_CONFIGS:
		var suffix = config.get("suffix", "")
		var shader_folder = config.get("base-name", "")
		var shader_name = shader_folder + config.get("sub-name", "")
		var shader_path = SHADER_PATH_BASE + shader_folder + "/" + shader_name + suffix + ".gdshader"
		if config.name in ["Smooth Borders"]:
			shader_path = SHADER_PATH_BASE + shader_name + suffix + ".gdshader"

		var cache_key = config.name + "::" + suffix
		var shader_resource
		if _shader_cache.has(cache_key):
			shader_resource = _shader_cache[cache_key]
		else:
			shader_resource = load(shader_path)
			if shader_resource:
				_shader_cache[cache_key] = shader_resource

		if shader_resource != null:
			var shader_info = {"name": config.name, "shader": shader_resource, "supports_cursor": config.supports_cursor, "tooltip": config.get("tooltip", ""), "sub-pixels": config.get("sub-pixels"), "render-mode": config.get("render-mode"), "second_palette": config.get("second-palette"), "object-type": config.get("object-type"), "type": get_shader_type(config.name)}
			available_shaders.append(shader_info)
		else:
			print("Warning: Could not load shader: " + shader_path)
	return available_shaders


## [b]Check Cursor Support[/b]
## [color=gray]Checks if a given shader supports cursor-based effects.[/color]
## @param shader_name The name of the shader to check.
## @return True if the shader supports cursor effects, false otherwise.
static func check_cursor_support(shader_name: String) -> bool:
	for config in SHADER_CONFIGS:
		if config.name == shader_name:
			return config.supports_cursor
	return false
