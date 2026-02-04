extends Node2D


@onready var cards_player_1: CardHand = $CanvasLayer/Control/CardHand
@onready var cards_player_2: CardHand = $CanvasLayer/Control/CardHand2
@onready var cards_played: CardHand = $CanvasLayer/Control/CardsPlayed
@onready var play_zone: Area2D = $CanvasLayer/Control/Area2D
@onready var available_plays: Label = $CanvasLayer2/Control/MarginContainer/Label


enum Player {
	PLAYER_1,
	PLAYER_2
}

enum Turn {
	MANO_1,
	MANO_2,
	MANO_3
}

var initial_player: Player = Player.PLAYER_1
var current_turn: Turn = Turn.MANO_1
var has_called_flor: bool = false
var has_called_envido: bool = false
var has_called_truco: bool = false

# signals game manager
signal action_played(action: Enums.Action, player: Player)


var deck_data: Dictionary = {}
var candidates: Array[Card] = []
var _card_over_play_zone: bool = false
var _card_currently_over: Card = null

func _ready() -> void:
	deck_data = DeckService.create_deck_data()

	var player_1_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)
	for card_data: CardData in player_1_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = cards_player_1.add_card(card)
		card.card_clicked.connect(_on_card_clicked)

	var player_2_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)
	for card_data: CardData in player_2_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = cards_player_2.add_card(card)
		(card.get_layout() as CardTrucoVM).flip()

	# Conectar señales para detectar cuando se arrastra y suelta una carta
	CG.holding_card.connect(_on_holding_card)
	CG.dropped_card.connect(_on_card_dropped)
	
	set_process(false)

	_print_cards_size()

	
func _on_card_clicked(card: Card) -> void:
	if candidates.has(card): _remove_card_from_candidates(card)
	else: _add_card_to_candidates(card)

	
func _add_card_to_candidates(card: Card) -> void:
	card.position_offset = Vector2(0, -20)
	candidates.append(card)
	cards_player_1.arrange_cards()

	var candidates_data: Array[CardData] = []
	for candidate: Card in candidates:
		candidates_data.append(candidate.card_data)
	var available_play: Enums.Action = Utils.get_available_plays(candidates_data)
	available_plays.text = IntlService.WORDINGS_ACTION[available_play]


func _remove_card_from_candidates(card: Card) -> void:
	card.position_offset = Vector2.ZERO
	candidates.erase(card)
	cards_player_1.arrange_cards()

	var candidates_data: Array[CardData] = []
	for candidate: Card in candidates:
		candidates_data.append(candidate.card_data)
	var available_play: Enums.Action = Utils.get_available_plays(candidates_data)
	available_plays.text = IntlService.WORDINGS_ACTION[available_play]


func _print_cards_size() -> void:
	var total_cards: int = 0
	for suit: CardData.CardSuit in CardData.CardSuit.values():
		var cards: Array = deck_data.get(suit, [])
		total_cards += cards.size()
	print("Total cards: ", total_cards)


func _process(_delta: float) -> void:
	var cursor_pos: Vector2 = CG.get_cursor_position()
	var is_over: bool = _is_cursor_over_play_zone(cursor_pos)
	var current_card: Card = CG.current_held_item
	
	if is_over and not _card_over_play_zone:
		_card_over_play_zone = true
		_card_currently_over = current_card
	elif not is_over and _card_over_play_zone:
		_card_over_play_zone = false
		_card_currently_over = null


func _on_holding_card(_card: Card) -> void:
	set_process(true)


func _on_card_dropped() -> void:
	if _card_over_play_zone and _card_currently_over and _card_currently_over.get_parent() == cards_player_1:
		_move_card_to_played(_card_currently_over)
	
	# Resetear estado
	_card_over_play_zone = false
	_card_currently_over = null
	set_process(false)


func _is_cursor_over_play_zone(cursor_pos: Vector2) -> bool:
	var collision_shape: CollisionShape2D = play_zone.get_node("CollisionShape2D")
	
	if not collision_shape or not collision_shape.shape:
		return false
	
	# Convertir la posición del cursor a coordenadas locales del Area2D
	var local_pos: Vector2 = play_zone.to_local(cursor_pos)
	
	# Verificar si el punto está dentro del CollisionShape2D
	if collision_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
		var shape_pos: Vector2 = collision_shape.position
		var rect: Rect2 = Rect2(
			shape_pos - rect_shape.size / 2,
			rect_shape.size
		)
		
		return rect.has_point(local_pos)
	
	return false


func _move_card_to_played(card: Card) -> void:
	# Remover la carta de los candidatos si está ahí
	if candidates.has(card):
		_remove_card_from_candidates(card)
	
	# Mover la carta a cards_played
	var _result: bool = cards_played.add_card(card)
	
	# Limpiar el offset de posición si tenía uno
	card.position_offset = Vector2.ZERO
