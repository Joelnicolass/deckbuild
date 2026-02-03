extends Node2D


@onready var cards_player_1: CardHand = $CanvasLayer/Control/CardHand
@onready var cards_player_2: CardHand = $CanvasLayer/Control/CardHand2
@onready var available_plays: Label = $CanvasLayer2/Control/MarginContainer/Label


var candidates: Array[Card] = []

func _ready() -> void:
	var deck_data: Dictionary = DeckService.create_deck_data()
	var player_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)

	for card_data: CardData in player_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = cards_player_1.add_card(card)
		card.card_clicked.connect(_on_card_clicked)

	var player_2_cards: Array[CardData] = DeckService.get_random_cards(3, deck_data)
	for card_data: CardData in player_2_cards:
		var card: Card = Card.new(card_data)
		card.set_layout("card_truco")
		var _result: bool = cards_player_2.add_card(card)
	

	var results: Dictionary = eval_possbile_results(player_cards, player_2_cards)
	var stats: Dictionary = calculate_win_probabilities(results)
	
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║     ESTADÍSTICAS DE PROBABILIDADES - TRUCO ARGENTINO     ║")
	print("╚════════════════════════════════════════════════════════════╝\n")
	
	# Mostrar cartas de cada jugador
	print("📋 CARTAS DEL JUGADOR 1:")
	for i: int in range(player_cards.size()):
		var card: CardData = player_cards[i]
		print("   ", i + 1, ". ", IntlService.format_card_info(card))
	
	print("\n📋 CARTAS DEL JUGADOR 2:")
	for i: int in range(player_2_cards.size()):
		var card: CardData = player_2_cards[i]
		print("   ", i + 1, ". ", IntlService.format_card_info(card))
	
	print("\n" + "────────────────────────────────────────────────────────────")
	var envido_action: String = IntlService.WORDINGS_ACTION[Enums.Action.ENVIDO] as String
	print("🎯 " + envido_action.to_upper())
	var envido_1_points: Variant = stats["envido"]["player_1_points"]
	var envido_2_points: Variant = stats["envido"]["player_2_points"]
	var envido_winner: String = stats["envido"]["winner"]
	
	if envido_1_points != null:
		var tantos_text: String = IntlService.WORDINGS_TRUCO_TERMS["tantos"]
		print("   Jugador 1: ", envido_1_points, " ", tantos_text)
		if envido_1_points == 27:
			print("   ⭐ ", IntlService.WORDINGS_TRUCO_TERMS["viejas"], "!")
	else:
		print("   Jugador 1: Sin envido")
	
	if envido_2_points != null:
		var tantos_text: String = IntlService.WORDINGS_TRUCO_TERMS["tantos"]
		print("   Jugador 2: ", envido_2_points, " ", tantos_text)
		if envido_2_points == 27:
			print("   ⭐ ", IntlService.WORDINGS_TRUCO_TERMS["viejas"], "!")
	else:
		print("   Jugador 2: Sin envido")
	
	if envido_winner == "player_1":
		print("   🏆 Ganador: Jugador 1")
	elif envido_winner == "player_2":
		print("   🏆 Ganador: Jugador 2")
	elif envido_winner == "tie":
		print("   🤝 Empate")
	else:
		print("   ❌ Sin ganador")
	
	print("\n" + "────────────────────────────────────────────────────────────")
	var truco_action: String = IntlService.WORDINGS_ACTION[Enums.Action.TRUCO] as String
	print("⚔️  " + truco_action.to_upper())
	var truco_total: int = stats["truco"]["total_combinations"]
	var truco_wins_1: int = stats["truco"]["player_1_wins"]
	var truco_wins_2: int = stats["truco"]["player_2_wins"]
	var truco_ties: int = stats["truco"]["ties"]
	var truco_prob_1: float = stats["truco"]["player_1_probability"]
	var truco_prob_2: float = stats["truco"]["player_2_probability"]
	var truco_prob_tie: float = stats["truco"]["tie_probability"]
	
	print("   Total de combinaciones: ", truco_total)
	print("   Jugador 1 gana: ", truco_wins_1, " (", "%.1f" % truco_prob_1, "%)")
	print("   Jugador 2 gana: ", truco_wins_2, " (", "%.1f" % truco_prob_2, "%)")
	print("   ", IntlService.WORDINGS_TRUCO_TERMS["parda"], ": ", truco_ties, " (", "%.1f" % truco_prob_tie, "%)")
	
	if truco_prob_1 > truco_prob_2:
		print("   🏆 Ventaja: Jugador 1")
	elif truco_prob_2 > truco_prob_1:
		print("   🏆 Ventaja: Jugador 2")
	else:
		print("   🤝 Empate técnico")
	
	print("\n" + "────────────────────────────────────────────────────────────")
	var flor_action: String = IntlService.WORDINGS_ACTION[Enums.Action.FLOR] as String
	print("🌸 " + flor_action.to_upper())
	var flor_1_has: bool = stats["flor"]["player_1_has_flor"]
	var flor_2_has: bool = stats["flor"]["player_2_has_flor"]
	var flor_1_value: Variant = stats["flor"]["player_1_value"]
	var flor_2_value: Variant = stats["flor"]["player_2_value"]
	var flor_winner: String = stats["flor"]["winner"]
	var flor_points: int = stats["flor"]["points"]
	
	if flor_1_has:
		print("   Jugador 1: ✅ Tiene flor (", flor_1_value, " ", IntlService.WORDINGS_TRUCO_TERMS["tantos"], ")")
	else:
		print("   Jugador 1: ❌ Sin flor")
	
	if flor_2_has:
		print("   Jugador 2: ✅ Tiene flor (", flor_2_value, " ", IntlService.WORDINGS_TRUCO_TERMS["tantos"], ")")
	else:
		print("   Jugador 2: ❌ Sin flor")
	
	if flor_winner == "player_1":
		print("   🏆 Ganador: Jugador 1")
		if flor_points == 6:
			print("   ⚠️  ", IntlService.WORDINGS_ACTION[Enums.Action.RETRUCO], " (6 puntos)")
		else:
			print("   📊 Puntos: ", flor_points)
	elif flor_winner == "player_2":
		print("   🏆 Ganador: Jugador 2")
		if flor_points == 6:
			print("   ⚠️  ", IntlService.WORDINGS_ACTION[Enums.Action.RETRUCO], " (6 puntos)")
		else:
			print("   📊 Puntos: ", flor_points)
	elif flor_winner == "tie":
		print("   🤝 Ambos tienen flor - ", IntlService.WORDINGS_ACTION[Enums.Action.RETRUCO])
		print("   📊 Puntos: ", flor_points)
	else:
		print("   ❌ Ningún jugador tiene flor")
	
	print("\n" + "────────────────────────────────────────────────────────────")
	print("📊 PROBABILIDAD GENERAL DE VICTORIA")
	var overall_prob_1: float = stats["overall"]["player_1_probability"]
	var overall_prob_2: float = stats["overall"]["player_2_probability"]
	var favorite: String = stats["overall"]["favorite"]
	
	print("   Jugador 1: ", "%.1f" % overall_prob_1, "%")
	print("   Jugador 2: ", "%.1f" % overall_prob_2, "%")
	
	if favorite == "player_1":
		print("   🏆 FAVORITO: Jugador 1")
	elif favorite == "player_2":
		print("   🏆 FAVORITO: Jugador 2")
	else:
		print("   🤝 Empate técnico")
	
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║                    FIN DEL ANÁLISIS                      ║")
	print("╚════════════════════════════════════════════════════════════╝\n")
	

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
	var available_play: Enums.Action = get_available_plays(candidates_data)
	available_plays.text = IntlService.WORDINGS_ACTION[available_play]


func _remove_card_from_candidates(card: Card) -> void:
	card.position_offset = Vector2.ZERO
	candidates.erase(card)
	cards_player_1.arrange_cards()

	var candidates_data: Array[CardData] = []
	for candidate: Card in candidates:
		candidates_data.append(candidate.card_data)
	var available_play: Enums.Action = get_available_plays(candidates_data)
	available_plays.text = IntlService.WORDINGS_ACTION[available_play]


func eval_possbile_results(player_1_cards: Array[CardData], player_2_cards: Array[CardData]) -> Dictionary:
	var results: Dictionary = {
		Enums.Action.FLOR: {},
		Enums.Action.ENVIDO: {},
		Enums.Action.TRUCO: {},
	}

	var result_envido_1: Dictionary = GameService.eval_envido(player_1_cards)
	if result_envido_1["valid"]:
		results[Enums.Action.ENVIDO]["player_1"] = result_envido_1["points"]
	else:
		results[Enums.Action.ENVIDO]["player_1"] = null

	var result_envido_2: Dictionary = GameService.eval_envido(player_2_cards)
	if result_envido_2["valid"]:
		results[Enums.Action.ENVIDO]["player_2"] = result_envido_2["points"]
	else:
		results[Enums.Action.ENVIDO]["player_2"] = null

	# Inicializar estructura para truco
	var truco_combinations: Array[Dictionary] = []
	results[Enums.Action.TRUCO]["combinations"] = truco_combinations
	results[Enums.Action.TRUCO]["player_1_wins"] = 0
	results[Enums.Action.TRUCO]["player_2_wins"] = 0
	results[Enums.Action.TRUCO]["ties"] = 0

	# Verificar todas las combinaciones de cartas entre player 1 y player 2
	for card_1: CardData in player_1_cards:
		for card_2: CardData in player_2_cards:
			var result_truco: Dictionary = GameService.eval_truco(card_1, card_2)
			var winner: Variant = result_truco.get("winner", null)
			
			var combination_result: Dictionary = {
				"card_1": card_1,
				"card_2": card_2,
				"winner": null,
				"loser": null,
				"is_tie": false
			}
			
			if winner != null and winner is CardData:
				var winner_card: CardData = winner
				# Comparar por valores en lugar de por referencia de objeto
				var winner_is_card_1: bool = winner_card.card_suit == card_1.card_suit and winner_card.card_value == card_1.card_value
				var winner_is_card_2: bool = winner_card.card_suit == card_2.card_suit and winner_card.card_value == card_2.card_value
				
				if winner_is_card_1:
					combination_result["winner"] = "player_1"
					combination_result["loser"] = "player_2"
					results[Enums.Action.TRUCO]["player_1_wins"] += 1
				elif winner_is_card_2:
					combination_result["winner"] = "player_2"
					combination_result["loser"] = "player_1"
					results[Enums.Action.TRUCO]["player_2_wins"] += 1
			else:
				combination_result["is_tie"] = true
				results[Enums.Action.TRUCO]["ties"] += 1
			
			truco_combinations.append(combination_result)

		
	var result_flor_1: Dictionary = GameService.eval_flor(player_1_cards)
	if result_flor_1["valid"]:
		results[Enums.Action.FLOR]["player_1"] = result_flor_1["points"]
	else:
		results[Enums.Action.FLOR]["player_1"] = null

	var result_flor_2: Dictionary = GameService.eval_flor(player_2_cards)
	if result_flor_2["valid"]:
		results[Enums.Action.FLOR]["player_2"] = result_flor_2["points"]
	else:
		results[Enums.Action.FLOR]["player_2"] = null

	return results


func calculate_win_probabilities(results: Dictionary) -> Dictionary:
	var stats: Dictionary = {
		"envido": {},
		"truco": {},
		"flor": {},
		"overall": {}
	}
	
	# ========== ANÁLISIS DE ENVIDO ==========
	var envido_data: Dictionary = results[Enums.Action.ENVIDO]
	var envido_1: Variant = envido_data.get("player_1", null) if envido_data.has("player_1") else null
	var envido_2: Variant = envido_data.get("player_2", null) if envido_data.has("player_2") else null
	
	var envido_winner: String = "none"
	if envido_1 != null and envido_2 != null:
		if envido_1 > envido_2:
			envido_winner = "player_1"
		elif envido_2 > envido_1:
			envido_winner = "player_2"
		else:
			envido_winner = "tie"
	elif envido_1 != null:
		envido_winner = "player_1"
	elif envido_2 != null:
		envido_winner = "player_2"
	
	stats["envido"] = {
		"player_1_points": envido_1,
		"player_2_points": envido_2,
		"winner": envido_winner,
		"advantage": "player_1" if envido_winner == "player_1" else ("player_2" if envido_winner == "player_2" else "none")
	}
	
	# ========== ANÁLISIS DE TRUCO ==========
	var truco_data: Dictionary = results[Enums.Action.TRUCO]
	var truco_wins_1: int = truco_data.get("player_1_wins", 0) if truco_data.has("player_1_wins") else 0
	var truco_wins_2: int = truco_data.get("player_2_wins", 0) if truco_data.has("player_2_wins") else 0
	var truco_ties: int = truco_data.get("ties", 0) if truco_data.has("ties") else 0
	var total_combinations: int = truco_wins_1 + truco_wins_2 + truco_ties
	
	var truco_prob_1: float = 0.0
	var truco_prob_2: float = 0.0
	var truco_prob_tie: float = 0.0
	
	if total_combinations > 0:
		truco_prob_1 = float(truco_wins_1) / float(total_combinations) * 100.0
		truco_prob_2 = float(truco_wins_2) / float(total_combinations) * 100.0
		truco_prob_tie = float(truco_ties) / float(total_combinations) * 100.0
	
	stats["truco"] = {
		"player_1_wins": truco_wins_1,
		"player_2_wins": truco_wins_2,
		"ties": truco_ties,
		"total_combinations": total_combinations,
		"player_1_probability": truco_prob_1,
		"player_2_probability": truco_prob_2,
		"tie_probability": truco_prob_tie,
		"advantage": "player_1" if truco_prob_1 > truco_prob_2 else ("player_2" if truco_prob_2 > truco_prob_1 else "tie")
	}
	
	# ========== ANÁLISIS DE FLOR ==========
	var flor_data: Dictionary = results[Enums.Action.FLOR]
	var flor_1: Variant = flor_data.get("player_1", null) if flor_data.has("player_1") else null
	var flor_2: Variant = flor_data.get("player_2", null) if flor_data.has("player_2") else null
	
	var flor_winner: String = "none"
	var flor_points: int = 0
	
	if flor_1 != null and flor_2 != null:
		# Ambos tienen flor, comparar valores
		if flor_1 > flor_2:
			flor_winner = "player_1"
			flor_points = 6 # Contraflor
		elif flor_2 > flor_1:
			flor_winner = "player_2"
			flor_points = 6 # Contraflor
		else:
			flor_winner = "tie"
			flor_points = 6 # Contraflor (empate)
	elif flor_1 != null:
		flor_winner = "player_1"
		flor_points = 3 # Flor sola
	elif flor_2 != null:
		flor_winner = "player_2"
		flor_points = 3 # Flor sola
	
	stats["flor"] = {
		"player_1_has_flor": flor_1 != null,
		"player_2_has_flor": flor_2 != null,
		"player_1_value": flor_1,
		"player_2_value": flor_2,
		"winner": flor_winner,
		"points": flor_points,
		"advantage": "player_1" if flor_winner == "player_1" else ("player_2" if flor_winner == "player_2" else "none")
	}
	
	# ========== ANÁLISIS GENERAL ==========
	var advantages: Dictionary = {
		"player_1": 0,
		"player_2": 0,
		"tie": 0
	}
	
	# Contar ventajas
	if stats["envido"]["advantage"] != "none":
		advantages[stats["envido"]["advantage"]] += 1
	if stats["truco"]["advantage"] != "none":
		advantages[stats["truco"]["advantage"]] += 1
	if stats["flor"]["advantage"] != "none":
		advantages[stats["flor"]["advantage"]] += 1
	
	# Calcular probabilidad general (peso: truco 50%, envido 30%, flor 20%)
	var overall_score_1: float = 0.0
	var overall_score_2: float = 0.0
	
	# Peso del truco (50%)
	overall_score_1 += truco_prob_1 * 0.5
	overall_score_2 += truco_prob_2 * 0.5
	
	# Peso del envido (30%)
	if envido_1 != null and envido_2 != null:
		if envido_1 > envido_2:
			overall_score_1 += 30.0
		elif envido_2 > envido_1:
			overall_score_2 += 30.0
		else:
			overall_score_1 += 15.0
			overall_score_2 += 15.0
	elif envido_1 != null:
		overall_score_1 += 30.0
	elif envido_2 != null:
		overall_score_2 += 30.0
	
	# Peso de la flor (20%)
	if flor_winner == "player_1":
		overall_score_1 += 20.0
	elif flor_winner == "player_2":
		overall_score_2 += 20.0
	elif flor_winner == "tie":
		overall_score_1 += 10.0
		overall_score_2 += 10.0
	
	var total_score: float = overall_score_1 + overall_score_2
	var overall_prob_1: float = 0.0
	var overall_prob_2: float = 0.0
	
	if total_score > 0:
		overall_prob_1 = (overall_score_1 / total_score) * 100.0
		overall_prob_2 = (overall_score_2 / total_score) * 100.0
	else:
		overall_prob_1 = 50.0
		overall_prob_2 = 50.0
	
	stats["overall"] = {
		"player_1_probability": overall_prob_1,
		"player_2_probability": overall_prob_2,
		"player_1_score": overall_score_1,
		"player_2_score": overall_score_2,
		"favorite": "player_1" if overall_prob_1 > overall_prob_2 else ("player_2" if overall_prob_2 > overall_prob_1 else "tie"),
		"advantages": advantages
	}
	
	return stats


func get_available_plays(selected_cards: Array[CardData]) -> Enums.Action:
	if selected_cards.is_empty():
		return Enums.Action.NONE
	
	match selected_cards.size():
		1:
			return Enums.Action.TRUCO
		2:
			var envido_result: Dictionary = GameService.eval_envido(selected_cards)
			if envido_result["valid"]:
				return Enums.Action.ENVIDO
			return Enums.Action.NONE
		3:
			var flor_result: Dictionary = GameService.eval_flor(selected_cards)
			if flor_result["valid"]:
				return Enums.Action.FLOR
			return Enums.Action.NONE
		_:
			return Enums.Action.NONE
