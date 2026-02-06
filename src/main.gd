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


enum Player {
	PLAYER_1,
	PLAYER_2
}

enum Turn {
	MANO_1,
	MANO_2,
	MANO_3
}

enum GameState {
	WAITING_ACTION, # Esperando que el jugador cante una acción o tire carta
	WAITING_RESPONSE, # Esperando respuesta del rival (aceptar/rechazar/variación)
	PLAYING_CARD, # Jugando carta
	EVALUATING_ROUND, # Evaluando quién ganó la ronda
	GAME_OVER, # Partida terminada
}

# Game Manager State
var initial_player: Player
var current_turn: Turn = Turn.MANO_1
var current_player: Player # Jugador que tiene el turno actual
var game_state: GameState = GameState.WAITING_ACTION
var pending_action: Enums.Action = Enums.Action.NONE # Acción que está esperando respuesta
var pending_action_player: Player # Jugador que cantó la acción pendiente
var current_truco_level: Enums.Action = Enums.Action.TRUCO # Nivel actual de truco (TRUCO, RETRUCO, VALE_4)

# Acciones cantadas en esta mano
var has_called_flor: bool = false
var has_called_envido: bool = false
var has_called_truco: bool = false

# Puntos de envido/flor
var envido_points_player_1: int = 0
var envido_points_player_2: int = 0
var flor_points_player_1: int = 0
var flor_points_player_2: int = 0

# Cartas jugadas en esta mano
var cards_played_mano_1: Dictionary = {} # {Player: Card}
var cards_played_mano_2: Dictionary = {}
var cards_played_mano_3: Dictionary = {}

# Ganadores de cada mano
var mano_winners: Array[Player] = [] # [winner_mano_1, winner_mano_2, winner_mano_3]

# signals game manager
signal action_played(action: Enums.Action, player: Player)
signal action_response(action: Enums.Action, player: Player)
signal game_state_changed(new_state: GameState)
signal mano_completed(winner: Player)
signal game_completed(winner: Player)


var deck_data: Dictionary = {}
var candidates: Array[Card] = []
var _last_held_card: Card = null

func _ready() -> void:
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

	# Conectar señales para detectar cuando se arrastra y suelta una carta
	CG.holding_card.connect(_on_holding_card)
	CG.dropped_card.connect(_on_card_dropped)

	initial_player = Player.values()[randi() % Player.values().size()]
	current_player = initial_player
	
	# Inicializar el juego
	_start_game()

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


func _on_holding_card(card: Card) -> void:
	# Guardar referencia a la carta que se está arrastrando
	_last_held_card = card


func _on_card_dropped() -> void:
	# Verificar si hay una carta que se soltó y si el cursor está sobre la zona de juego
	if not _last_held_card:
		return
	
	# Verificar si el cursor está sobre la zona de juego
	var cursor_pos: Vector2 = CG.get_cursor_position()
	var is_over: bool = _is_cursor_over_play_zone(cursor_pos)
	
	if is_over and _last_held_card.get_parent() == cards_player_1:
		_move_card_to_played(_last_held_card)
	
	# Resetear referencia
	_last_held_card = null


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
	# Solo permitir jugar carta si es el turno del jugador y el estado lo permite
	if current_player != Player.PLAYER_1:
		print("No es tu turno")
		return
	
	if game_state != GameState.WAITING_ACTION:
		print("No se puede jugar carta en este estado: ", game_state)
		return
	
	print("Moving card to played: ", card.name)
	# Remover la carta de los candidatos si está ahí
	if candidates.has(card):
		_remove_card_from_candidates(card)
	
	# Usar el nuevo sistema de gestión de turnos
	_play_card(card, Player.PLAYER_1)
	
	# Limpiar el offset de posición si tenía uno
	card.position_offset = Vector2.ZERO


func _get_winner(card_1: Card, card_2: Card) -> Player:
	var result: Dictionary = GameService.eval_truco(card_1.card_data, card_2.card_data)

	if result["winner"] == card_1.card_data:
		(card_2.get_layout() as CardTrucoVM).apply_burn_effect()
		(card_2.get_layout() as CardTrucoVM).burn_velocity = 0.3
		return Player.PLAYER_1
	else:
		(card_1.get_layout() as CardTrucoVM).apply_burn_effect()
		(card_1.get_layout() as CardTrucoVM).burn_velocity = 0.3
		return Player.PLAYER_2

		
func _on_drag_started(_card: Card) -> void:
	var play_zone_color_rect: ColorRect = $CanvasLayer/Control/Area2D/PlayZoneColorRect
	play_zone_color_rect.visible = true
	play_zone_color_rect.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(play_zone_color_rect, "modulate:a", 0.5, 0.5)
	tween.tween_property(play_zone_color_rect, "modulate:a", 0.2, 0.5)
	tween.set_loops()


func _on_drag_ended(_card: Card) -> void:
	var play_zone_color_rect: ColorRect = $CanvasLayer/Control/Area2D/PlayZoneColorRect
	play_zone_color_rect.visible = false


# ============================================================================
# GAME MANAGER - Sistema de gestión de turnos y acciones
# ============================================================================

func _start_game() -> void:
	game_state = GameState.WAITING_ACTION
	current_turn = Turn.MANO_1
	_reset_mano_state()
	
	# En MANO_1, el jugador inicial siempre tira primero
	current_player = initial_player
	game_state_changed.emit(game_state)
	
	if current_player == Player.PLAYER_2:
		_play_ai_turn()


func _reset_mano_state() -> void:
	has_called_flor = false
	has_called_envido = false
	has_called_truco = false
	pending_action = Enums.Action.NONE
	current_truco_level = Enums.Action.TRUCO


func get_available_actions(player: Player) -> Array[Enums.Action]:
	var available: Array[Enums.Action] = []
	
	# En MANO_1 se pueden cantar todas las acciones
	if current_turn == Turn.MANO_1:
		# Flor solo se puede cantar una vez por mano
		if not has_called_flor:
			var player_cards: Array[CardData] = _get_player_cards(player)
			var flor_result: Dictionary = GameService.eval_flor(player_cards)
			if flor_result["valid"]:
				available.append(Enums.Action.FLOR)
		
		# Envido solo se puede cantar una vez por mano
		if not has_called_envido:
			var player_cards: Array[CardData] = _get_player_cards(player)
			var envido_result: Dictionary = GameService.eval_envido(player_cards)
			if envido_result["valid"]:
				available.append(Enums.Action.ENVIDO)
	
	# Truco se puede cantar en cualquier mano (con variaciones)
	if not has_called_truco:
		available.append(current_truco_level)
	elif current_truco_level == Enums.Action.TRUCO:
		available.append(Enums.Action.RETRUCO)
	elif current_truco_level == Enums.Action.RETRUCO:
		available.append(Enums.Action.VALE_4)
	
	# Si hay una acción pendiente, se pueden responder
	if pending_action != Enums.Action.NONE and player != pending_action_player:
		available.append(Enums.Action.ACEPTAR)
		available.append(Enums.Action.RECHAZAR)
		
		# Variaciones según la acción pendiente
		if pending_action == Enums.Action.ENVIDO:
			available.append(Enums.Action.REAL_ENVIDO)
			available.append(Enums.Action.FALTA_ENVIDO)
		elif pending_action == Enums.Action.FLOR:
			available.append(Enums.Action.CONTRAFLOR)
			available.append(Enums.Action.CONTRAFLOR_AL_RESTO)
	
	return available


func _get_player_cards(player: Player) -> Array[CardData]:
	var cards: Array[CardData] = []
	var hand: CardHand = cards_player_1 if player == Player.PLAYER_1 else cards_player_2
	
	for i in range(hand.get_card_count()):
		var card: Card = hand.get_card(i)
		if card:
			cards.append(card.card_data)
	
	return cards


func call_action(action: Enums.Action, player: Player) -> void:
	if game_state != GameState.WAITING_ACTION:
		print("No se puede cantar acción en este estado: ", game_state)
		return
	
	var available: Array[Enums.Action] = get_available_actions(player)
	if not available.has(action):
		print("Acción no disponible: ", action)
		return
	
	action_played.emit(action, player)
	
	# Manejar acciones de respuesta
	if action == Enums.Action.ACEPTAR:
		_handle_accept_action(player)
		return
	elif action == Enums.Action.RECHAZAR:
		_handle_reject_action(player)
		return
	
	# Manejar variaciones de acciones
	match action:
		Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			_handle_envido_action(action, player)
		Enums.Action.FLOR, Enums.Action.CONTRAFLOR, Enums.Action.CONTRAFLOR_AL_RESTO:
			_handle_flor_action(action, player)
		Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4:
			_handle_truco_action(action, player)


func _handle_envido_action(action: Enums.Action, player: Player) -> void:
	var player_cards: Array[CardData] = _get_player_cards(player)
	var envido_result: Dictionary = GameService.eval_envido(player_cards)
	
	if not envido_result["valid"]:
		print("No se puede cantar envido con estas cartas")
		return
	
	has_called_envido = true
	
	# Si es una variación, se resuelve inmediatamente
	if action == Enums.Action.REAL_ENVIDO:
		_resolve_envido(player, 2) # Real envido vale 2 puntos
		return
	elif action == Enums.Action.FALTA_ENVIDO:
		_resolve_envido(player, 30) # Falta envido vale 30 puntos
		return
	
	# Si es envido normal, espera respuesta
	pending_action = action
	pending_action_player = player
	game_state = GameState.WAITING_RESPONSE
	game_state_changed.emit(game_state)
	
	# Si es el rival, responder automáticamente
	if player == Player.PLAYER_2:
		await get_tree().create_timer(1.0).timeout
		_ai_respond_to_action()


func _handle_flor_action(action: Enums.Action, player: Player) -> void:
	var player_cards: Array[CardData] = _get_player_cards(player)
	var flor_result: Dictionary = GameService.eval_flor(player_cards)
	
	if not flor_result["valid"]:
		print("No se puede cantar flor con estas cartas")
		return
	
	has_called_flor = true
	
	# Si es una variación, se resuelve inmediatamente
	if action == Enums.Action.CONTRAFLOR:
		_resolve_flor(player, 3) # Contraflor vale 3 puntos
		return
	elif action == Enums.Action.CONTRAFLOR_AL_RESTO:
		_resolve_flor(player, 6) # Contraflor al resto vale 6 puntos
		return
	
	# Si es flor normal, espera respuesta
	pending_action = action
	pending_action_player = player
	game_state = GameState.WAITING_RESPONSE
	game_state_changed.emit(game_state)
	
	# Si es el rival, responder automáticamente
	if player == Player.PLAYER_2:
		await get_tree().create_timer(1.0).timeout
		_ai_respond_to_action()


func _handle_truco_action(action: Enums.Action, player: Player) -> void:
	has_called_truco = true
	current_truco_level = action
	
	# Truco siempre espera respuesta
	pending_action = action
	pending_action_player = player
	game_state = GameState.WAITING_RESPONSE
	game_state_changed.emit(game_state)
	
	# Si es el rival, responder automáticamente
	if player == Player.PLAYER_2:
		await get_tree().create_timer(1.0).timeout
		_ai_respond_to_action()


func _handle_accept_action(player: Player) -> void:
	if pending_action == Enums.Action.NONE:
		return
	
	action_response.emit(Enums.Action.ACEPTAR, player)
	
	# Si acepta envido o flor, se resuelve
	if pending_action in [Enums.Action.ENVIDO, Enums.Action.FLOR]:
		if pending_action == Enums.Action.ENVIDO:
			_resolve_envido(pending_action_player, 2) # Envido vale 2 puntos
		elif pending_action == Enums.Action.FLOR:
			_resolve_flor(pending_action_player, 3) # Flor vale 3 puntos
	
	# Limpiar acción pendiente y continuar
	pending_action = Enums.Action.NONE
	game_state = GameState.WAITING_ACTION
	game_state_changed.emit(game_state)
	
	# Continuar con el turno
	if current_player == Player.PLAYER_2:
		_play_ai_turn()


func _handle_reject_action(player: Player) -> void:
	if pending_action == Enums.Action.NONE:
		return
	
	action_response.emit(Enums.Action.RECHAZAR, player)
	
	# Si rechaza, el que cantó gana la partida
	_end_game(pending_action_player)


func _resolve_envido(calling_player: Player, points: int) -> void:
	var player_1_cards: Array[CardData] = _get_player_cards(Player.PLAYER_1)
	var player_2_cards: Array[CardData] = _get_player_cards(Player.PLAYER_2)
	
	var envido_1: Dictionary = GameService.eval_envido(player_1_cards)
	var envido_2: Dictionary = GameService.eval_envido(player_2_cards)
	
	var points_1: int = envido_1.get("points", 0) if envido_1.get("valid", false) else 0
	var points_2: int = envido_2.get("points", 0) if envido_2.get("valid", false) else 0
	
	var winner: Player
	if points_1 > points_2:
		winner = Player.PLAYER_1
	elif points_2 > points_1:
		winner = Player.PLAYER_2
	else:
		# Empate, gana el que no cantó
		winner = Player.PLAYER_2 if calling_player == Player.PLAYER_1 else Player.PLAYER_1
	
	print("Envido resuelto - Ganador: ", winner, " Puntos: ", points)
	
	# Aquí se asignarían los puntos al ganador
	# Por ahora solo imprimimos


func _resolve_flor(calling_player: Player, points: int) -> void:
	var player_1_cards: Array[CardData] = _get_player_cards(Player.PLAYER_1)
	var player_2_cards: Array[CardData] = _get_player_cards(Player.PLAYER_2)
	
	var flor_1: Dictionary = GameService.eval_flor(player_1_cards)
	var flor_2: Dictionary = GameService.eval_flor(player_2_cards)
	
	var points_1: int = flor_1.get("points", 0) if flor_1.get("valid", false) else 0
	var points_2: int = flor_2.get("points", 0) if flor_2.get("valid", false) else 0
	
	var winner: Player
	if points_1 > points_2:
		winner = Player.PLAYER_1
	elif points_2 > points_1:
		winner = Player.PLAYER_2
	else:
		# Empate, gana el que no cantó
		winner = Player.PLAYER_2 if calling_player == Player.PLAYER_1 else Player.PLAYER_1
	
	print("Flor resuelta - Ganador: ", winner, " Puntos: ", points)
	
	# Aquí se asignarían los puntos al ganador
	# Por ahora solo imprimimos


func _end_game(winner: Player) -> void:
	game_state = GameState.GAME_OVER
	game_state_changed.emit(game_state)
	game_completed.emit(winner)
	print("Partida terminada - Ganador: ", winner)


func _ai_respond_to_action() -> void:
	# IA simple: acepta todo por ahora
	# TODO: Implementar lógica de IA más inteligente
	call_action(Enums.Action.ACEPTAR, Player.PLAYER_2)


func _play_ai_turn() -> void:
	if game_state != GameState.WAITING_ACTION:
		return
	
	await get_tree().create_timer(0.5).timeout
	
	# Por ahora, la IA solo tira una carta al azar
	# TODO: Implementar lógica de IA más inteligente
	var ai_hand: CardHand = cards_player_2
	if ai_hand.get_card_count() > 0:
		var random_card: Card = ai_hand.get_card(randi() % ai_hand.get_card_count())
		if random_card:
			# Simular jugar carta
			_play_card(random_card, Player.PLAYER_2)


func _play_card(card: Card, player: Player) -> void:
	if game_state != GameState.WAITING_ACTION:
		return
	
	game_state = GameState.PLAYING_CARD
	game_state_changed.emit(game_state)
	
	# Mover carta al slot correspondiente
	var slot_index: int = _get_next_slot_index(current_turn)
	var slot: CardSlot = _get_player_slot(player, slot_index)
	
	slot.unlock()
	slot.add_card(card)
	slot.lock()
	
	# Guardar carta jugada
	match current_turn:
		Turn.MANO_1:
			cards_played_mano_1[player] = card
		Turn.MANO_2:
			cards_played_mano_2[player] = card
		Turn.MANO_3:
			cards_played_mano_3[player] = card
	
	# Si ambos jugadores han jugado, evaluar la mano
	if _both_players_played():
		_evaluate_mano()
	else:
		# Cambiar turno al otro jugador
		current_player = Player.PLAYER_2 if current_player == Player.PLAYER_1 else Player.PLAYER_1
		game_state = GameState.WAITING_ACTION
		game_state_changed.emit(game_state)
		
		if current_player == Player.PLAYER_2:
			_play_ai_turn()


func _both_players_played() -> bool:
	match current_turn:
		Turn.MANO_1:
			return cards_played_mano_1.has(Player.PLAYER_1) and cards_played_mano_1.has(Player.PLAYER_2)
		Turn.MANO_2:
			return cards_played_mano_2.has(Player.PLAYER_1) and cards_played_mano_2.has(Player.PLAYER_2)
		Turn.MANO_3:
			return cards_played_mano_3.has(Player.PLAYER_1) and cards_played_mano_3.has(Player.PLAYER_2)
	return false


func _evaluate_mano() -> void:
	game_state = GameState.EVALUATING_ROUND
	game_state_changed.emit(game_state)
	
	var card_1: Card = _get_played_card(Player.PLAYER_1)
	var card_2: Card = _get_played_card(Player.PLAYER_2)
	
	if not card_1 or not card_2:
		return
	
	var winner: Player = _get_winner(card_1, card_2)
	mano_winners.append(winner)
	mano_completed.emit(winner)
	
	print("Mano ", current_turn, " - Ganador: ", winner)
	
	# Verificar si alguien ganó 2 manos (gana la partida)
	var player_1_wins: int = mano_winners.count(Player.PLAYER_1)
	var player_2_wins: int = mano_winners.count(Player.PLAYER_2)
	
	if player_1_wins >= 2:
		_end_game(Player.PLAYER_1)
		return
	elif player_2_wins >= 2:
		_end_game(Player.PLAYER_2)
		return
	
	# Si llegamos a la mano 3 y hay empate, el que ganó la primera mano gana
	if current_turn == Turn.MANO_3:
		if player_1_wins == player_2_wins:
			_end_game(mano_winners[0])
		return
	
	# Avanzar a la siguiente mano
	_advance_to_next_mano()


func _get_played_card(player: Player) -> Card:
	match current_turn:
		Turn.MANO_1:
			return cards_played_mano_1.get(player)
		Turn.MANO_2:
			return cards_played_mano_2.get(player)
		Turn.MANO_3:
			return cards_played_mano_3.get(player)
	return null


func _advance_to_next_mano() -> void:
	match current_turn:
		Turn.MANO_1:
			current_turn = Turn.MANO_2
		Turn.MANO_2:
			current_turn = Turn.MANO_3
		Turn.MANO_3:
			# No debería llegar aquí
			return
	
	_reset_mano_state()
	
	# Patrón fijo de turnos:
	# MANO_1: Jugador inicial tira → Jugador 2 responde
	# MANO_2: Jugador 2 tira → Jugador 1 responde
	# MANO_3: Jugador 1 tira → Jugador 2 responde
	match current_turn:
		Turn.MANO_2:
			# En MANO_2, el que NO empezó tira primero (el que respondió en MANO_1)
			current_player = Player.PLAYER_2 if initial_player == Player.PLAYER_1 else Player.PLAYER_1
		Turn.MANO_3:
			# En MANO_3, el que empezó tira primero
			current_player = initial_player
	
	game_state = GameState.WAITING_ACTION
	game_state_changed.emit(game_state)
	
	if current_player == Player.PLAYER_2:
		_play_ai_turn()


func _get_next_slot_index(mano: Turn) -> int:
	match mano:
		Turn.MANO_1:
			return 0
		Turn.MANO_2:
			return 1
		Turn.MANO_3:
			return 2
	return 0


func _get_player_slot(player: Player, index: int) -> CardSlot:
	if player == Player.PLAYER_1:
		match index:
			0: return slot_1_player_1
			1: return slot_2_player_1
			2: return slot_3_player_1
	else:
		match index:
			0: return slot_1_player_2
			1: return slot_2_player_2
			2: return slot_3_player_2
	return slot_1_player_1
