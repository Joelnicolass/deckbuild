extends Node2D


@onready var cards_player_1: CardHand = $CanvasLayer/Control/CardHand
@onready var cards_player_2: CardHand = $CanvasLayer/Control/CardHand2
@onready var available_plays: Label = $CanvasLayer2/Control/MarginContainer/Label
@onready var play_zone: Area2D = $CanvasLayer/Control/Area2D
@onready var slot_1_player_1: CardSlot = $CanvasLayer/Control/CardSlot1Player1
@onready var slot_2_player_1: CardSlot = $CanvasLayer/Control/CardSlot2Player1
@onready var slot_3_player_1: CardSlot = $CanvasLayer/Control/CardSlot3Player1
@onready var slot_1_player_2: CardSlot = $CanvasLayer/Control/CardSlot1Player2
@onready var slot_2_player_2: CardSlot = $CanvasLayer/Control/CardSlot2Player2
@onready var slot_3_player_2: CardSlot = $CanvasLayer/Control/CardSlot3Player2
@onready var accept_button: Button = $CanvasLayer3/Control/MarginContainer2/GridContainer/Accept
@onready var reject_button: Button = $CanvasLayer3/Control/MarginContainer2/GridContainer/Reject


var deck_data: Dictionary = {}
var _last_held_card: Card = null

func _ready() -> void:
	_initialize_deck()
	_initialize_signals()
	_initialize_game_manager()

	_print_cards_size()


func _initialize_game_manager() -> void:
	var slots_p1: Array[CardSlot] = [slot_1_player_1, slot_2_player_1, slot_3_player_1]
	var slots_p2: Array[CardSlot] = [slot_1_player_2, slot_2_player_2, slot_3_player_2]
	GameManagerService.initialize(cards_player_1, cards_player_2, slots_p1, slots_p2)
	GameManagerService.start_game()


func _initialize_signals() -> void:
	_connect_drag_and_drop_signals()
	GameManagerService.game_started.connect(_on_game_started)
	GameManagerService.turn_changed.connect(_on_turn_changed)
	GameManagerService.round_result.connect(_on_round_result)


# ============================================================================
# GAME MANAGER SIGNALS
# ============================================================================

func _on_game_started(initial_player: Enums.Player) -> void:
	_on_turn_changed(initial_player)


func _on_turn_changed(new_player: Enums.Player) -> void:
	if new_player == Enums.Player.PLAYER_1:
		_set_enable_drag_cards(cards_player_1.cards, true)
	else:
		_set_enable_drag_cards(cards_player_1.cards, false)
		GameManagerService.ai_request()


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


func _on_accept_pressed() -> void:
	GameManagerService.respond_to_action(true, Enums.Player.PLAYER_1)

func _on_reject_pressed() -> void:
	GameManagerService.respond_to_action(false, Enums.Player.PLAYER_1)
