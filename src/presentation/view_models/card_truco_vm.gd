# card_truco_vm.gd
extends CardLayout
class_name CardTrucoVM

# --- Shader Material ---
var card_material: ShaderMaterial = null

# --- Card Effects ---
var is_hovered: bool = false

@export var burn_velocity: float = 0.1
var is_burning: bool = false
var burn_radius: float = 0.0

var is_marked: bool = false
var mark_radius: float = 0.2
var mark_position: Vector2 = Vector2(0, 0)


func create_noise_texture() -> Texture2D:
	var noise_texture: NoiseTexture2D = NoiseTexture2D.new()
	noise_texture.width = 512
	noise_texture.height = 512
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.01
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_texture.noise = noise

	return noise_texture


# --- Lifecycle --- #

func _ready() -> void:
	if get_parent() is Card:
		var card: Card = get_parent()
		card.drag_started.connect(_on_drag_started)
		card.drag_ended.connect(_on_drag_ended)
		card.card_hovered.connect(_on_card_hovered)
		card.card_unhovered.connect(_on_card_unhovered)


func _process(delta: float) -> void:
	_update_hover_effect()
	_update_burn_effect(delta)
	_update_mark_effect()


# --- Signal --- # 

func _on_drag_started(_card: Card) -> void:
	if is_hovered: return
	is_hovered = true

func _on_drag_ended(_card: Card) -> void:
	if not is_hovered: return
	is_hovered = false

func _on_card_hovered() -> void:
	if is_hovered: return
	is_hovered = true

func _on_card_unhovered() -> void:
	if not is_hovered: return
	is_hovered = false

# --- Private Methods --- #

func _update_display() -> void:
	var data: CardData = card_resource
	
	if data:
		var texture: Texture2D = data.card_image
		var node_texture: TextureRect = $SubViewport/PanelContainer/Texture
		card_material = node_texture.material
		node_texture.texture = texture

		_setup_burn_effect()


# --- Private Utils --- #

func _setup_burn_effect() -> void:
	if not card_material: return
	card_material.set_shader_parameter('dissolve_noiseTexture', create_noise_texture())
	card_material.set_shader_parameter('dissolve_position', Vector2(randf(), randf()))


func _update_burn_effect(delta: float) -> void:
	if not is_burning: return
	card_material.set_shader_parameter('enable_dissolve', true)
	card_material.set_shader_parameter('dissolve_radius', burn_radius)
	burn_radius += delta * burn_velocity


func _update_hover_effect() -> void:
	if is_hovered:
		card_material.set_shader_parameter("mouse_position", get_global_mouse_position())
		card_material.set_shader_parameter("sprite_position", global_position + size / 2)
	else:
		card_material.set_shader_parameter("mouse_position", Vector2.ZERO)
		card_material.set_shader_parameter("sprite_position", Vector2.ZERO)


func _update_mark_effect() -> void:
	if is_marked:
		card_material.set_shader_parameter('enable_dissolve', true)
		card_material.set_shader_parameter('dissolve_radius', mark_radius)
		card_material.set_shader_parameter('dissolve_position', mark_position)
	else:
		card_material.set_shader_parameter('enable_dissolve', false)
		card_material.set_shader_parameter('dissolve_radius', 0)
		card_material.set_shader_parameter('dissolve_position', Vector2.ZERO)


# --- PUBLIC API --- # 

func apply_mark_effect() -> void:
	is_marked = true

func remove_mark_effect() -> void:
	is_marked = false

func apply_burn_effect() -> void:
	is_burning = true

func remove_burn_effect() -> void:
	is_burning = false