extends Node2D


@onready var camera: Camera2D = $Camera2D
@onready var cards_player_1: CardHand = $CanvasLayer/Control/CardHand
@onready var cards_player_2: CardHand = $CanvasLayer/Control/CardHand2
@onready var play_zone: Area2D = $CanvasLayer/Control/Area2D
@onready var slot_1_player_1: CardSlot = $CanvasLayer/Control/CardSlot1Player1
@onready var slot_2_player_1: CardSlot = $CanvasLayer/Control/CardSlot2Player1
@onready var slot_3_player_1: CardSlot = $CanvasLayer/Control/CardSlot3Player1
@onready var slot_1_player_2: CardSlot = $CanvasLayer/Control/CardSlot1Player2
@onready var slot_2_player_2: CardSlot = $CanvasLayer/Control/CardSlot2Player2
@onready var slot_3_player_2: CardSlot = $CanvasLayer/Control/CardSlot3Player2
@onready var action_label: TypeWriterLabel = $CanvasLayer2/Control/Action
@onready var action_label_background: ColorRect = $CanvasLayer2/Control/ActionBg
@onready var accept_button: Button = $CanvasLayer3/Control/MarginContainer2/GridContainer/Accept
@onready var reject_button: Button = $CanvasLayer3/Control/MarginContainer2/GridContainer/Reject

# ── CONFIGURACIÓN DE LAYOUT ──────────────────────────────────────────
# Zona de juego (play zone)
@export_group("Play Zone")
@export var zone_center_ratio: float = 0.42 ## Centro vertical de la zona (0.0 = arriba, 1.0 = abajo)
@export var zone_height: float = 250.0 ## Alto total de la zona en px (subir = zona más grande)

# Slots (las 3 posiciones de cartas jugadas por cada jugador)
@export_group("Slots")
@export var slot_size: Vector2 = Vector2(40, 40) ## Tamaño de cada slot
@export var slot_gap_h: float = 80.0 ## Espacio horizontal entre slots
@export var slot_spacing_v: float = 60.0 ## Distancia vertical entre fila P2 y fila P1 (subir = más separados)

# Manos de cartas
@export_group("Hands")
@export var hand_margin: float = 70.0 ## Distancia de cada mano al borde de la zona (subir = más lejos)

var deck_data: Dictionary = {}
var _last_held_card: Card = null

func _ready() -> void:
	_initialize_camera()
	_initialize_deck()
	_initialize_signals()
	_initialize_game_manager()
	_initialize_ui()
	_print_cards_size()


func _initialize_ui() -> void:
	action_label.visible = false
	action_label_background.visible = false
	accept_button.visible = false
	reject_button.visible = false
	_layout_ui()


func _layout_ui() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# ┌─────────────────────────────┐
	# │      cards player 2 (IA)    │  ← hand_margin arriba de la zona
	# │                             │
	# │  ┌────── PLAY ZONE ──────┐  │
	# │  │  [S1]  [S2]  [S3]  P2│  │  ← fila superior (slot_spacing_v / 2 arriba del centro)
	# │  │                       │  │
	# │  │  [S1]  [S2]  [S3]  P1│  │  ← fila inferior (slot_spacing_v / 2 abajo del centro)
	# │  └───────────────────────┘  │
	# │                             │
	# │      cards player 1 (Vos)   │  ← hand_margin abajo de la zona
	# │      [ Buttons ]            │
	# └─────────────────────────────┘

	# --- Zona central ---
	var zone_cy: float = vp.y * zone_center_ratio
	var zone_top: float = zone_cy - zone_height / 2.0
	var zone_bot: float = zone_cy + zone_height / 2.0

	# --- Slots: 2 filas centradas en la zona ---
	var slots_p2_y: float = zone_cy - slot_spacing_v / 2.0 - slot_size.y / 2.0
	var slots_p1_y: float = zone_cy + slot_spacing_v / 2.0 - slot_size.y / 2.0

	var total_slots_w: float = slot_size.x * 3.0 + slot_gap_h * 2.0
	var start_x: float = (vp.x - total_slots_w) / 2.0

	var arr_p2: Array[CardSlot] = [slot_1_player_2, slot_2_player_2, slot_3_player_2]
	var arr_p1: Array[CardSlot] = [slot_1_player_1, slot_2_player_1, slot_3_player_1]

	for i: int in range(3):
		var sx: float = start_x + i * (slot_size.x + slot_gap_h)
		arr_p2[i].position = Vector2(sx, slots_p2_y)
		arr_p2[i].size = slot_size
		arr_p1[i].position = Vector2(sx, slots_p1_y)
		arr_p1[i].size = slot_size

	# --- Manos: misma distancia al borde de la zona ---
	var cards_p2_y: float = zone_top - hand_margin
	var cards_p1_y: float = zone_bot + hand_margin

	cards_player_2.offset_top = cards_p2_y
	cards_player_2.offset_bottom = cards_p2_y
	cards_player_1.offset_top = cards_p1_y - vp.y
	cards_player_1.offset_bottom = cards_player_1.offset_top

	# --- Play zone (collision + visual) – ancho completo ---
	var z_size: Vector2 = Vector2(vp.x, zone_height)

	var collision: CollisionShape2D = play_zone.get_node("CollisionShape2D")
	collision.position = Vector2(vp.x / 2.0, zone_cy)
	if collision.shape is RectangleShape2D:
		(collision.shape as RectangleShape2D).size = z_size

	var play_rect: ColorRect = play_zone.get_node("PlayZoneColorRect")
	play_rect.position = Vector2(0.0, zone_top)
	play_rect.size = z_size
	play_rect.scale = Vector2.ONE


func _initialize_camera() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

	
func _on_viewport_size_changed() -> void:
	camera.position = get_viewport_rect().size / 2
	_layout_ui()

func _initialize_game_manager() -> void:
	var slots_p1: Array[CardSlot] = [slot_1_player_1, slot_2_player_1, slot_3_player_1]
	var slots_p2: Array[CardSlot] = [slot_1_player_2, slot_2_player_2, slot_3_player_2]
	GameManagerService.initialize(cards_player_1, cards_player_2, slots_p1, slots_p2)
	GameManagerService.start_game()


func _initialize_signals() -> void:
	_connect_drag_and_drop_signals()
	GameManagerService.turn_started.connect(_on_turn_started)
	GameManagerService.must_play_card.connect(_on_must_play_card)
	GameManagerService.round_result.connect(_on_round_result)
	GameManagerService.action_requested.connect(_on_action_requested)


# ============================================================================
# GAME MANAGER SIGNALS
# ============================================================================

## Comienza el turno de un jugador (puede cantar o tirar carta)
func _on_turn_started(player: Enums.Player) -> void:
	if player == Enums.Player.PLAYER_1:
		_set_enable_drag_cards(cards_player_1.cards, true)
	else:
		_set_enable_drag_cards(cards_player_1.cards, false)
		GameManagerService.ai_turn()


## El jugador DEBE tirar carta (después de resolver un canto)
func _on_must_play_card(player: Enums.Player) -> void:
	if player == Enums.Player.PLAYER_1:
		_set_enable_drag_cards(cards_player_1.cards, true)
	else:
		GameManagerService.ai_play_card()


func _on_round_result(result: Dictionary) -> void:
	var loser_card_ref: Card = result["loser"]["card"]
	var winner_card_ref: Card = result["winner"]["card"]
	
	if not loser_card_ref or not winner_card_ref: return

	var loser_card: CardTrucoVM = loser_card_ref.get_layout()
	var winner_card: CardTrucoVM = winner_card_ref.get_layout()
	
	if loser_card and winner_card:
		await get_tree().create_timer(0.1).timeout
		
		var winner_offset: Vector2 = Vector2.DOWN * 100 if result["winner"]["player"] == Enums.Player.PLAYER_1 else Vector2.UP * 100

		var loser_pos: Vector2 = loser_card_ref.global_position
		var winner_pos: Vector2 = winner_card_ref.global_position + winner_offset
		var center_pos: Vector2 = (loser_pos + winner_pos) / 2.0
		
		loser_card_ref.z_index = winner_card_ref.z_index - 1
		
		var t: Tween = create_tween()
		t.set_parallel(true)
		t.set_ease(Tween.EASE_IN_OUT)
		t.set_trans(Tween.TRANS_SPRING)
		
		t.tween_property(loser_card, "modulate", Color.GRAY, 0.4)
		t.tween_property(loser_card_ref, "global_position", center_pos, 0.2)
		t.tween_property(loser_card_ref, "rotation_degrees", randf_range(-10, 10), 0.2).as_relative()
		
		t.tween_property(winner_card, "rotation_degrees", randf_range(-10, 10), 0.2).as_relative()
		t.tween_property(winner_card_ref, "global_position", center_pos, 0.2)
		

func _on_action_requested(action: Enums.Action, requester: Enums.Player) -> void:
	# Si el jugador 1 cantó, la IA debe responder
	if requester == Enums.Player.PLAYER_1:
		GameManagerService.ai_respond_to_action()
	else:
		_show_action_label(action)
		_show_response_buttons()
		

# ============================================================================
# PRIVATE METHODS
# ============================================================================


func _set_enable_drag_cards(cards: Array[Card], enable: bool) -> void:
	cards.map(func(c: Card) -> void: c.disabled = !enable)

func _on_card_clicked(card: Card) -> void:
	print("Card clicked: ", (card.card_data as CardData).card_suit, " ", (card.card_data as CardData).card_value)


func _move_card_to_played(card: Card) -> void:
	GameManagerService.play_card(card, Enums.Player.PLAYER_1)
	card.position_offset = Vector2.ZERO


func _on_accept_pressed() -> void:
	GameManagerService.respond_to_action(true, Enums.Player.PLAYER_1)
	_hide_action_label()
	_hide_response_buttons()

func _on_reject_pressed() -> void:
	GameManagerService.respond_to_action(false, Enums.Player.PLAYER_1)
	_hide_action_label()
	_hide_response_buttons()


func _on_truco_pressed() -> void:
	# Verificar que es el turno del jugador 1
	if GameManagerService.current_player != Enums.Player.PLAYER_1:
		return
	
	# Solicitar acción TRUCO
	GameManagerService.request_action(Enums.Action.TRUCO, Enums.Player.PLAYER_1)
	

func _on_flor_pressed() -> void:
	pass # Replace with function body.


func _on_envido_pressed() -> void:
	pass # Replace with function body.


func _on_mazo_pressed() -> void:
	pass # Replace with function body.

# ============================================================================
# DECK INITIALIZATION
# ============================================================================


func _initialize_deck() -> void:
	deck_data = DeckService.create_deck_data()

	var player_1_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)
	for card_data: CardData in player_1_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = cards_player_1.add_card(card)
		card.card_clicked.connect(_on_card_clicked)
		card.drag_started.connect(_on_drag_started)
		card.drag_ended.connect(_on_drag_ended)

	var player_2_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)
	for card_data: CardData in player_2_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = cards_player_2.add_card(card)
		(card.get_layout() as CardTrucoVM).flip()
		card.disabled = true


# ============================================================================
# DRAG AND DROP HANDLERS
# ============================================================================

func _connect_drag_and_drop_signals() -> void:
	CG.holding_card.connect(_on_holding_card)
	CG.dropped_card.connect(_on_card_dropped)


func _on_drag_ended(_card: Card) -> void:
	var play_zone_color_rect: ColorRect = $CanvasLayer/Control/Area2D/PlayZoneColorRect
	play_zone_color_rect.visible = false


func _on_drag_started(_card: Card) -> void:
	var play_zone_color_rect: ColorRect = $CanvasLayer/Control/Area2D/PlayZoneColorRect
	play_zone_color_rect.visible = true
	play_zone_color_rect.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(play_zone_color_rect, "modulate:a", 0.5, 0.5)
	tween.tween_property(play_zone_color_rect, "modulate:a", 0.2, 0.5)
	tween.set_loops()


func _is_cursor_over_play_zone(cursor_pos: Vector2) -> bool:
	var collision_shape: CollisionShape2D = play_zone.get_node("CollisionShape2D")
	
	if not collision_shape or not collision_shape.shape: return false
	
	var local_pos: Vector2 = play_zone.to_local(cursor_pos)
	
	if collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		var shape_pos: Vector2 = collision_shape.position
		var rect: Rect2 = Rect2(
			shape_pos - rect_shape.size / 2,
			rect_shape.size
		)
		
		return rect.has_point(local_pos)
	
	return false


func _on_holding_card(card: Card) -> void:
	_last_held_card = card


func _on_card_dropped() -> void:
	if not _last_held_card: return

	var cursor_pos: Vector2 = CG.get_cursor_position()
	var is_over: bool = _is_cursor_over_play_zone(cursor_pos)
	
	if is_over and _last_held_card.get_parent() == cards_player_1:
		_move_card_to_played(_last_held_card)
	
	_last_held_card = null


# ============================================================================
# UTILS
# ============================================================================

func _print_cards_size() -> void:
	var total_cards: int = 0
	for suit: CardData.CardSuit in CardData.CardSuit.values():
		var cards: Array = deck_data.get(suit, [])
		total_cards += cards.size()
	print("Total cards: ", total_cards)


func _show_action_label(action: Enums.Action) -> void:
	action_label.visible = true
	action_label_background.visible = true
	action_label_background.scale = Vector2.ZERO
	var action_text: String = IntlService.ACTION_WORDINGS[action]
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(action_label_background, "scale", Vector2.ONE, 0.2)

	action_label.typewrite("[rainbow][wave][b]¡ %s ![/b][/wave][/rainbow]" % action_text.to_upper())


func _hide_action_label() -> void:
	action_label.visible = false
	action_label_background.visible = false


func _show_response_buttons() -> void:
	var t: Tween = create_tween()
	accept_button.modulate.a = 0.0
	reject_button.modulate.a = 0.0
	t.set_parallel(true)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(accept_button, "modulate:a", 1.0, 0.4)
	t.tween_property(reject_button, "modulate:a", 1.0, 0.4)

	accept_button.visible = true
	reject_button.visible = true


func _hide_response_buttons() -> void:
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(accept_button, "modulate:a", 0.0, 0.4)
	t.tween_property(reject_button, "modulate:a", 0.0, 0.4)

	accept_button.visible = false
	reject_button.visible = false
