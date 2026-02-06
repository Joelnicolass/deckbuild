extends Node


func create_deck_data() -> Dictionary:
	var deck_data: Dictionary = {
		CardData.CardSuit.ESPADA: [],
		CardData.CardSuit.BASTO: [],
		CardData.CardSuit.ORO: [],
		CardData.CardSuit.COPA: [],
	}

	var prefixes: Array[String] = ["oro_", "basto_", "espada_", "copa_"]
	for prefix: String in prefixes:
		for value: CardData.CardValue in CardData.CardValue.values():
			var card_value: int
			match value:
				CardData.CardValue.DIEZ:
					card_value = 10
				CardData.CardValue.ONCE:
					card_value = 11
				CardData.CardValue.DOCE:
					card_value = 12
				_:
					card_value = value + 1
			
			var card_data: CardData = load("res://src/common/cards/%s%d.tres" % [prefix, card_value])
			var card_suit: CardData.CardSuit = card_data.card_suit
			var cards: Array = deck_data.get(card_suit, [])
			cards.append(card_data)

	return deck_data


func get_random_card(deck_data: Dictionary) -> CardData:
	var available_suits: Array[CardData.CardSuit] = []

	for suit: CardData.CardSuit in CardData.CardSuit.values():
		var suit_cards: Array = deck_data.get(suit, [])
		if not suit_cards.is_empty():
			available_suits.append(suit)
	
	if available_suits.is_empty(): return null
	
	var suit: CardData.CardSuit = available_suits.pick_random()
	var cards_in_suit: Array = deck_data.get(suit, [])
	
	cards_in_suit.shuffle()

	var card: CardData = cards_in_suit.pop_front()
	deck_data[suit] = cards_in_suit
	
	return card


func get_random_cards(count: int, deck_data: Dictionary) -> Array[CardData]:
	var cards: Array[CardData] = []
	for i: int in count:
		var card: CardData = get_random_card(deck_data)
		if card == null: break
		cards.append(card)
	return cards


func add_card_to_deck(deck_data: Dictionary, suit: CardData.CardSuit, value: CardData.CardValue) -> void:
	var prefix: String
	match suit:
		CardData.CardSuit.ESPADA:
			prefix = "espada_"
		CardData.CardSuit.BASTO:
			prefix = "basto_"
		CardData.CardSuit.ORO:
			prefix = "oro_"
		CardData.CardSuit.COPA:
			prefix = "copa_"
		_: return
	
	var card_value: int
	match value:
		CardData.CardValue.DIEZ:
			card_value = 10
		CardData.CardValue.ONCE:
			card_value = 11
		CardData.CardValue.DOCE:
			card_value = 12
		_:
			card_value = value + 1
	
	var card_path: String = "res://src/common/cards/%s%d.tres" % [prefix, card_value]
	var card_data: CardData = load(card_path)
	
	if not card_data: return
	
	var cards: Array = deck_data.get(suit, [])
	cards.append(card_data)
	deck_data[suit] = cards
