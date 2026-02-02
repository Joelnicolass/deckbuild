# card_truco_vm.gd
extends CardLayout
class_name CardTrucoVM

var card_material: Material = null
var is_focused: bool = false

func _ready():
	if get_parent() is Card:
		var card = get_parent() as Card
		card.drag_started.connect(_on_drag_started)
		card.drag_ended.connect(_on_drag_ended)
		card.card_hovered.connect(_on_card_hovered)
		card.card_unhovered.connect(_on_card_unhovered)
		

func _on_drag_started(_card: Card) -> void:
	if is_focused: return
	is_focused = true

func _on_drag_ended(_card: Card) -> void:
	if not is_focused: return
	is_focused = false

func _on_card_hovered() -> void:
	if is_focused: return
	is_focused = true

func _on_card_unhovered() -> void:
	if not is_focused: return
	is_focused = false


func _update_display() -> void:
	var data = card_resource as CardData
	
	if data:
		$SubViewport/PanelContainer/Texture.texture = data.card_image
		card_material = $SubViewport/PanelContainer/Texture.material
		

func _process(_delta):
	if is_focused:
		card_material.set_shader_parameter("mouse_position", get_global_mouse_position())
		card_material.set_shader_parameter("sprite_position", global_position)
	else:
		card_material.set_shader_parameter("mouse_position", Vector2.ZERO)
		card_material.set_shader_parameter("sprite_position", Vector2.ZERO)
