@tool
class_name PixelRichTextEffectMask
extends RichTextEffect

## [b]Effect Definitions[/b]
## [color=gray]List of effect settings to apply based on character effect parameters.[/color]
## Used to determine the parameters for each effect applied to the text.
@export var effect_definitions: Array[EffectSetting] = []

## [b]Color Map[/b]
## [color=gray]Mapping of effect signatures to colors.[/color]
## Used for quick lookup of colors based on effect parameters.
@export var color_map: Dictionary = {}

var bbcode = "pas"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var id = char_fx.env.get("id", "")

	var keys = char_fx.env.keys()
	keys.sort()
	var sig = "id=" + str(id)
	for k in keys:
		if k != "id":
			sig += ";" + k + "=" + str(char_fx.env[k])

	if color_map.has(sig):
		char_fx.color = color_map[sig]
		return true

	char_fx.color = Color(0, 0, 0, 0)
	return true
