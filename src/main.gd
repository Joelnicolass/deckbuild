extends Node2D


@onready var card_hand: CardHand = $CanvasLayer/Control/CardHand
@onready var card_selected: CardHand = $CanvasLayer/Control/CardHand2


func _ready() -> void:
	var deck_data: Dictionary = DeckService.create_deck_data()
	var player_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)

	for card_data: CardData in player_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = card_hand.add_card(card)
