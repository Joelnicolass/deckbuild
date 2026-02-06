extends Node


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


func eval_power_cards(card_1: CardData, card_2: CardData) -> Dictionary:
	var power_1: int = get_card_power(card_1)
	var power_2: int = get_card_power(card_2)
	
	var result: Dictionary = {
		"action": Enums.Action.TRUCO,
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


func get_envido_value(card: CardData) -> int:
	# En el envido, las figuras (10, 11, 12) valen 0
	# Los números (1-7) valen su valor numérico
	match card.card_value:
		CardData.CardValue.UNO:
			return 1
		CardData.CardValue.DOS:
			return 2
		CardData.CardValue.TRES:
			return 3
		CardData.CardValue.CUATRO:
			return 4
		CardData.CardValue.CINCO:
			return 5
		CardData.CardValue.SEIS:
			return 6
		CardData.CardValue.SIETE:
			return 7
		CardData.CardValue.DIEZ, CardData.CardValue.ONCE, CardData.CardValue.DOCE:
			return 0
		_:
			return 0


func eval_envido(cards: Array[CardData]) -> Dictionary:
	var result: Dictionary = {
		"action": Enums.Action.ENVIDO,
		"valid": false,
		"points": 0,
		"suit": null,
		"cards": cards,
	}
	
	if cards.is_empty():
		return result
	
	# Agrupar cartas por palo
	var cards_by_suit: Dictionary = {}
	for card: CardData in cards:
		if not cards_by_suit.has(card.card_suit):
			var new_array: Array[CardData] = []
			cards_by_suit[card.card_suit] = new_array
		var suit_array: Array[CardData] = cards_by_suit[card.card_suit]
		suit_array.append(card)
	
	# Buscar el palo con más cartas y calcular su suma
	var best_suit: Variant = null
	var best_points: int = 0
	
	for suit: CardData.CardSuit in cards_by_suit.keys():
		var suit_cards: Array[CardData] = cards_by_suit[suit]
		
		# Si hay 2 o más cartas del mismo palo, calcular puntos
		if suit_cards.size() >= 2:
			var values: Array[int] = []
			for card: CardData in suit_cards:
				values.append(get_envido_value(card))
			
			# Ordenar de mayor a menor
			values.sort()
			values.reverse()
			
			# Si hay 3 cartas, tomar las 2 más altas
			# Si hay 2 cartas, tomar ambas
			var points: int = 0
			if values.size() >= 2:
				points = values[0] + values[1]
			else:
				points = values[0]
			
			# Si este palo tiene más puntos, es el mejor
			if points > best_points:
				best_points = points
				best_suit = suit
	
	# Si encontramos un palo válido, el envido es válido
	if best_suit != null:
		result["valid"] = true
		result["points"] = best_points + 20 # Se suman 20 puntos base por el envido
		result["suit"] = best_suit
	
	return result


func eval_flor(cards: Array[CardData]) -> Dictionary:
	var result: Dictionary = {
		"action": Enums.Action.FLOR,
		"valid": false,
		"points": 0,
		"suit": null,
		"cards": cards,
	}
	
	# La flor requiere exactamente 3 cartas
	if cards.size() != 3:
		return result
	
	# Verificar que las 3 cartas sean del mismo palo
	var first_suit: CardData.CardSuit = cards[0].card_suit
	var all_same_suit: bool = true
	
	for card: CardData in cards:
		if card.card_suit != first_suit:
			all_same_suit = false
			break
	
	# Si no son todas del mismo palo, no hay flor
	if not all_same_suit:
		return result
	
	# Calcular puntos de la flor (suma de las 3 cartas + 20 base)
	var values: Array[int] = []
	for card: CardData in cards:
		values.append(get_envido_value(card))
	
	var total_points: int = 0
	for value: int in values:
		total_points += value
	
	# La flor es válida y tiene puntos
	result["valid"] = true
	result["points"] = total_points + 20 # Se suman 20 puntos base por la flor
	result["suit"] = first_suit
	
	return result