extends Node2D


@onready var cards_player_1: CardHand = $CanvasLayer/Control/CardHand
@onready var cards_player_2: CardHand = $CanvasLayer/Control/CardHand2
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


var candidates: Array[Card] = []

func _ready() -> void:
	var deck_data: Dictionary = DeckService.create_deck_data()

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
