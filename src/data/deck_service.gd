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


func get_random_cards(count: int, deck_data: Dictionary) -> Array[CardData]:
	var cards: Array[CardData] = []

	var suit: CardData.CardSuit = CardData.CardSuit.values().pick_random()
	var cards_in_suit: Array = deck_data.get(suit, [])
	
	cards_in_suit.shuffle()

	for card: CardData in cards_in_suit:
		cards.append(card)
		if cards.size() >= count:
			break
	return cards
