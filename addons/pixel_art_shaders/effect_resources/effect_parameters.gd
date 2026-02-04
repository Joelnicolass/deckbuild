#gdlint: disable=max-line-length
@tool
## [b]Effect Parameters[/b]
## A base resource class for defining customizable parameters for pixel art shader effects.
## Inherit from this class to define specific sets of shader uniform mappings.
class_name EffectParameters extends Resource


## [b]Get Parameters[/b]
## Retrieves a list of all export variables defined in this resource script.
## [return]: An array of parameter names (strings).
func get_parameters() -> Array[String]:
	var params: Array[String] = []
	for param in get_property_list():
		if param.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			params.append(param.name)
	return params


## [b]Get Value[/b]
## Gets the value of a specific parameter by name.
## [param param_name]: The name of the parameter to retrieve.
## [return]: The value of the parameter.
func get_value(param_name: String) -> Variant:
	return get(param_name)


## [b]Get Non-Shader Variables[/b]
## Returns a list of variable names that should be applied to the target Node instead of the shader.
## Override this method in child classes to specify node properties (e.g., [code]visible[/code], [code]modulate[/code]).
## [return]: An empty array by default.
func get_non_shader_vars() -> Array[String]:
	return []


## [b]Apply Non-Shader Variables[/b]
## Applies the values of variables listed in [method get_non_shader_vars] to the target node.
## [param node]: The object (usually a Control or Node2D) to apply properties to.
func apply_non_shader_variables(node: Node) -> void:
	for ns in get_non_shader_vars():
		if ns in node:
			node.set(ns, get_value(ns))
