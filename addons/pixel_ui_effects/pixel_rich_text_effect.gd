@tool
class_name PixelRichTextEffect
extends RichTextEffect

## [b]Effect Definitions[/b]
## [color=gray]List of effect settings to apply based on character effect parameters.[/color]
## Used to determine the parameters for each effect applied to the text.
@export var effect_definitions: Array[EffectSetting] = []

## [b]Hide Effects[/b]
## [color=gray]If enabled, characters with matching effect definitions will be hidden,
## as they will be replaced by the effect render output.[/color]
@export var hide_effects: bool = false

var bbcode = "pas"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if hide_effects:
		var id = char_fx.env.get("id", "")
		for e in effect_definitions:
			if e and (str(e.id) == str(id) or e.name == str(id)) and e.active:
				if e.replace_character:
					char_fx.color = Color(0.0, 0.0, 0.0, 0.0)
	return true
