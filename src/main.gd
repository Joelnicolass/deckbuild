extends Node2D


@onready var card_hand: CardHand = $CanvasLayer/Control/CardHand
@onready var card_selected: CardHand = $CanvasLayer/Control/CardHand2


enum Action {
	FLOR,
	ENVIDO,
	TRUCO,
	RETRUCO,
	VALE_4,
}


func get_card_power(card: CardData) -> int:
	# Ancho de espada (1 espadas) - la más fuerte
	if card.card_value == CardData.CardValue.UNO and card.card_suit == CardData.CardSuit.ESPADA:
		return 1
	
	# Ancho de basto (1 bastos)
	if card.card_value == CardData.CardValue.UNO and card.card_suit == CardData.CardSuit.BASTO:
		return 2
	
	# 7 de espada
	if card.card_value == CardData.CardValue.SIETE and card.card_suit == CardData.CardSuit.ESPADA:
		return 3
	
	# 7 de oro
	if card.card_value == CardData.CardValue.SIETE and card.card_suit == CardData.CardSuit.ORO:
		return 4
	
	# Todos los 3
	if card.card_value == CardData.CardValue.TRES:
		return 5
	
	# Todos los 2
	if card.card_value == CardData.CardValue.DOS:
		return 6
	
	# Ases falsos (1 copas/oro)
	if card.card_value == CardData.CardValue.UNO:
		return 7
	
	# Reyes (12)
	if card.card_value == CardData.CardValue.DOCE:
		return 8
	
	# Caballos (11)
	if card.card_value == CardData.CardValue.ONCE:
		return 9
	
	# Sotas (10)
	if card.card_value == CardData.CardValue.DIEZ:
		return 10
	
	# 7 falsos (7 copas/bastos)
	if card.card_value == CardData.CardValue.SIETE:
		return 11
	
	# 6
	if card.card_value == CardData.CardValue.SEIS:
		return 12
	
	# 5
	if card.card_value == CardData.CardValue.CINCO:
		return 13
	
	# 4
	if card.card_value == CardData.CardValue.CUATRO:
		return 14
	
	# Por defecto, si no coincide con nada (no debería pasar)
	return 999


func eval_truco(card_1: CardData, card_2: CardData) -> Dictionary:
	var power_1: int = get_card_power(card_1)
	var power_2: int = get_card_power(card_2)
	
	var result: Dictionary = {
		"action": Action.TRUCO,
		"winner": null,
		"loser": null,
		"cards": [card_1, card_2],
	}
	
	# El rank menor gana (carta más fuerte)
	if power_1 < power_2:
		result["winner"] = card_1
		result["loser"] = card_2
	elif power_2 < power_1:
		result["winner"] = card_2
		result["loser"] = card_1
	
	return result
	

var candidates: Array[Card] = []

func _ready() -> void:
	var deck_data: Dictionary = DeckService.create_deck_data()
	var player_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)

	for card_data: CardData in player_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = card_hand.add_card(card)
		card.card_clicked.connect(_on_card_clicked)

	var player_2_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)
	for card_data: CardData in player_2_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = card_selected.add_card(card)


func _on_card_clicked(card: Card) -> void:
	if candidates.has(card): _remove_card_from_candidates(card)
	else: _add_card_to_candidates(card)

	
func _add_card_to_candidates(card: Card) -> void:
	var new_position: Vector2 = card.global_position + Vector2(0, -20)
	var tween: Tween = create_tween()
	tween.tween_property(card, "global_position", new_position, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	card.position_offset = Vector2(0, -20)
	candidates.append(card)


func _remove_card_from_candidates(card: Card) -> void:
	var new_position: Vector2 = card.global_position + Vector2(0, 20)
	var tween: Tween = create_tween()
	tween.tween_property(card, "global_position", new_position, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	card.position_offset = Vector2(0, 20)
	candidates.erase(card)
