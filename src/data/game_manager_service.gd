extends Node

const DELAY_AI_REQUEST: float = 1.0


# ============================================================================
# SIGNALS
# ============================================================================

signal game_started(initial_player: Enums.Player)
signal card_played(card: Card, player: Enums.Player)
signal round_result(result: Dictionary)
signal turn_changed(new_player: Enums.Player)
signal action_requested(action: Enums.Action, requester: Enums.Player)
signal action_resolved(action: Enums.Action, accepted: bool, requester: Enums.Player)

# ============================================================================
# STATE VARIABLES
# ============================================================================

var initial_player: Enums.Player
var current_turn: Enums.Turn = Enums.Turn.ROUND_1
var current_player: Enums.Player
var game_state: Enums.GameState = Enums.GameState.WAITING_ACTION

var cards_player_1: CardHand
var cards_player_2: CardHand
var slots_player_1: Array[CardSlot] = []
var slots_player_2: Array[CardSlot] = []

var cards_played_p1: int = 0
var cards_played_p2: int = 0


# Ronda actual: guarda las cartas jugadas por cada jugador
var current_round_cards: Dictionary = {
	Enums.Player.PLAYER_1: null,
	Enums.Player.PLAYER_2: null
}

# Control para evitar múltiples llamadas a ai_request
var _ai_playing: bool = false

# Estado de acciones: qué acciones se han llamado en esta ronda
var _action_calls: Dictionary = {
	Enums.Action.FLOR: false,
	Enums.Action.ENVIDO: false,
	Enums.Action.REAL_ENVIDO: false,
	Enums.Action.FALTA_ENVIDO: false,
	Enums.Action.TRUCO: false,
	Enums.Action.RETRUCO: false,
	Enums.Action.VALE_4: false,
	Enums.Action.CONTRAFLOR: false,
	Enums.Action.CONTRAFLOR_AL_RESTO: false,
}

var _pending_action: Enums.Action = Enums.Action.NONE
var _action_requester: Enums.Player
var actions_requested: Dictionary = {
	Enums.Action.FLOR: false,
	Enums.Action.ENVIDO: false,
	Enums.Action.REAL_ENVIDO: false,
	Enums.Action.FALTA_ENVIDO: false,
	Enums.Action.TRUCO: false,
	Enums.Action.RETRUCO: false,
	Enums.Action.VALE_4: false,
}

# ============================================================================
# PUBLIC API
# ============================================================================

func initialize(cards_p1: CardHand, cards_p2: CardHand, slots_p1: Array[CardSlot], slots_p2: Array[CardSlot]) -> void:
	cards_player_1 = cards_p1
	cards_player_2 = cards_p2
	slots_player_1 = slots_p1
	slots_player_2 = slots_p2
	
	# Conectar señal interna para gestionar rondas
	card_played.connect(_on_card_played)
	

func start_game() -> void:
	randomize()
	initial_player = Enums.Player.PLAYER_1 if randf() < 0.5 else Enums.Player.PLAYER_2
	current_player = initial_player
	current_turn = Enums.Turn.ROUND_1
	_reset_round_cards()
	_reset_action_calls()

	game_started.emit(initial_player)
	

func play_card(card: Card, player: Enums.Player) -> void:
	var slot: CardSlot = _get_player_slot(player, current_turn)
	if not slot: return
	
	slot.unlock()
	slot.add_card(card)
	
	if slot.get_card() == card:
		var card_layout: CardTrucoVM = card.get_layout() as CardTrucoVM
		if card_layout and card_layout.is_flipped:
			card_layout.flip()
	
	slot.lock()
	
	card_played.emit(card, player)

	
func ai_request() -> void:
	if _ai_playing: return
	if current_player != Enums.Player.PLAYER_2: return
	if cards_player_2.cards.is_empty(): return
	if game_state == Enums.GameState.GAME_OVER: return

	_ai_playing = true
	
	await get_tree().create_timer(DELAY_AI_REQUEST).timeout
	
	if current_player != Enums.Player.PLAYER_2:
		_ai_playing = false
		return

	if cards_player_2.cards.is_empty():
		_ai_playing = false
		return

	if game_state == Enums.GameState.GAME_OVER:
		_ai_playing = false
		return

	# Intentar solicitar una acción si es válido
	var action: Enums.Action = _decide_ai_action()
	
	if action != Enums.Action.NONE:
		if request_action(action, Enums.Player.PLAYER_2):
			_ai_playing = false
			return
			
	var random_card: Card = cards_player_2.cards.pick_random()
	play_card(random_card, Enums.Player.PLAYER_2)
	
	_ai_playing = false


# ============================================================================
# ACTION MANAGEMENT (CANTOS)
# ============================================================================

## Solicita una acción (canto). Retorna true si la acción es válida y se puede solicitar
func request_action(action: Enums.Action, requester: Enums.Player) -> bool:
	# Verificar que es el turno del jugador que solicita
	if current_player != requester: return false
	
	# Verificar que no hay una acción pendiente
	if _pending_action != Enums.Action.NONE: return false
	
	# Verificar que el estado del juego permite solicitar acciones
	if game_state != Enums.GameState.WAITING_ACTION: return false
	
	# Verificar que la acción es válida para el estado actual
	if not _is_action_valid(action): return false
	
	# Marcar la acción como llamada
	_action_calls[action] = true
	
	# Establecer acción pendiente
	_pending_action = action
	_action_requester = requester
	
	# Cambiar estado a esperando respuesta
	game_state = Enums.GameState.WAITING_RESPONSE
	
	# Emitir señal
	print(IntlService.ACTION_WORDINGS[action])
	action_requested.emit(action, requester)
	
	return true


## Responde a una acción pendiente. Retorna true si la respuesta es válida
func respond_to_action(accepted: bool, responder: Enums.Player) -> bool:
	# Verificar que hay una acción pendiente
	if _pending_action == Enums.Action.NONE: return false
	
	# Verificar que no es el mismo jugador que solicitó
	if responder == _action_requester: return false
	
	# Verificar que el estado del juego permite responder
	if game_state != Enums.GameState.WAITING_RESPONSE: return false
	
	# Procesar la respuesta según el tipo de acción
	var action: Enums.Action = _pending_action
	var requester: Enums.Player = _action_requester
	
	# Limpiar acción pendiente
	_pending_action = Enums.Action.NONE
	_action_requester = Enums.Player.PLAYER_1
	
	# Procesar respuesta según el tipo de acción
	_process_action_response(action, accepted, requester, responder)
	
	# Emitir señal de resolución
	action_resolved.emit(action, accepted, requester)
	
	# Si se rechaza, el juego termina o cambia de estado según la acción
	if not accepted:
		_handle_action_rejected(action, requester)
		return true
	
	# Si se acepta, continuar con el flujo normal
	game_state = Enums.GameState.WAITING_ACTION
	
	return true


## Verifica si una acción es válida para el estado actual
func _is_action_valid(action: Enums.Action) -> bool:
	if actions_requested[action]: return false

	match action:
		Enums.Action.FLOR:
			# Solo válida en la primera ronda y si no se ha llamado
			return current_turn == Enums.Turn.ROUND_1 and not _action_calls[action]
		
		Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			# Solo válidas en la primera ronda y si no se han llamado
			return current_turn == Enums.Turn.ROUND_1 and not _action_calls[action]
		
		Enums.Action.CONTRAFLOR:
			# Válido solo si FLOR fue aceptada
			return _action_calls[Enums.Action.FLOR] and not _action_calls[action]
		
		Enums.Action.CONTRAFLOR_AL_RESTO:
			# Válido solo si CONTRAFLOR fue aceptada
			return _action_calls[Enums.Action.CONTRAFLOR] and not _action_calls[action]
		
		Enums.Action.TRUCO:
			# Válido si no se ha llamado
			return not _action_calls[action]
		
		Enums.Action.RETRUCO:
			# Válido solo si TRUCO fue aceptado
			return _action_calls[Enums.Action.TRUCO] and not _action_calls[action]
		
		Enums.Action.VALE_4:
			# Válido solo si RETRUCO fue aceptado
			return _action_calls[Enums.Action.RETRUCO] and not _action_calls[action]
		
		Enums.Action.ACEPTAR, Enums.Action.RECHAZAR:
			# Estas son respuestas, no se solicitan directamente
			return false
		
		_:
			return false


## Procesa la respuesta a una acción
func _process_action_response(action: Enums.Action, accepted: bool, requester: Enums.Player, responder: Enums.Player) -> void:
	if not accepted: return
	
	match action:
		Enums.Action.FLOR:
			actions_requested[Enums.Action.FLOR] = true
			_handle_flor_accepted(requester, responder)
		
		Enums.Action.ENVIDO:
			actions_requested[Enums.Action.ENVIDO] = true
			_handle_envido_accepted(requester, responder)
		
		Enums.Action.REAL_ENVIDO:
			actions_requested[Enums.Action.REAL_ENVIDO] = true
			_handle_envido_accepted(requester, responder)
		
		Enums.Action.FALTA_ENVIDO:
			actions_requested[Enums.Action.FALTA_ENVIDO] = true
			_handle_envido_accepted(requester, responder)
		
		Enums.Action.CONTRAFLOR:
			actions_requested[Enums.Action.CONTRAFLOR] = true
			_handle_contraflor_accepted(requester, responder)
		
		Enums.Action.CONTRAFLOR_AL_RESTO:
			actions_requested[Enums.Action.CONTRAFLOR_AL_RESTO] = true
			_handle_contraflor_al_resto_accepted(requester, responder)
		
		Enums.Action.TRUCO:
			actions_requested[Enums.Action.TRUCO] = true
			_handle_truco_accepted(requester, responder)
		
		Enums.Action.RETRUCO:
			actions_requested[Enums.Action.RETRUCO] = true
			_handle_retruco_accepted(requester, responder)
		
		Enums.Action.VALE_4:
			actions_requested[Enums.Action.VALE_4] = true
			_handle_vale4_accepted(requester, responder)


## Maneja cuando una acción es rechazada
func _handle_action_rejected(action: Enums.Action, _requester: Enums.Player) -> void:
	match action:
		Enums.Action.FLOR, Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			# Si se rechaza envido/flor, el juego continúa normalmente
			game_state = Enums.GameState.WAITING_ACTION
		
		Enums.Action.CONTRAFLOR, Enums.Action.CONTRAFLOR_AL_RESTO:
			# Si se rechaza contraflor, el juego continúa normalmente
			game_state = Enums.GameState.WAITING_ACTION
		
		Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4:
			# Si se rechaza truco, el que rechaza pierde
			game_state = Enums.GameState.GAME_OVER
			# TODO: Determinar ganador por rechazo


## Handlers específicos para cada acción aceptada
func _handle_flor_accepted(_requester: Enums.Player, _responder: Enums.Player) -> void:
	# Evaluar flor de ambos jugadores y determinar ganador
	var cards_p1: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_1)
	var cards_p2: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_2)
	
	var flor_p1: Dictionary = GameService.eval_flor(cards_p1)
	var flor_p2: Dictionary = GameService.eval_flor(cards_p2)
	
	# TODO: Comparar y otorgar puntos
	print("FLOR aceptada - P1: ", flor_p1, " P2: ", flor_p2)


func _handle_contraflor_accepted(_requester: Enums.Player, _responder: Enums.Player) -> void:
	# Evaluar flor de ambos jugadores y determinar ganador (contraflor)
	var cards_p1: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_1)
	var cards_p2: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_2)
	
	var flor_p1: Dictionary = GameService.eval_flor(cards_p1)
	var flor_p2: Dictionary = GameService.eval_flor(cards_p2)
	
	# TODO: Comparar y otorgar puntos (valor aumentado)
	print("CONTRAFLOR aceptada - P1: ", flor_p1, " P2: ", flor_p2)


func _handle_contraflor_al_resto_accepted(_requester: Enums.Player, _responder: Enums.Player) -> void:
	# Evaluar flor de ambos jugadores y determinar ganador (contraflor al resto)
	var cards_p1: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_1)
	var cards_p2: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_2)
	
	var flor_p1: Dictionary = GameService.eval_flor(cards_p1)
	var flor_p2: Dictionary = GameService.eval_flor(cards_p2)
	
	# TODO: Comparar y otorgar puntos (valor máximo)
	print("CONTRAFLOR AL RESTO aceptada - P1: ", flor_p1, " P2: ", flor_p2)


func _handle_envido_accepted(_requester: Enums.Player, _responder: Enums.Player) -> void:
	# Evaluar envido de ambos jugadores y determinar ganador
	var cards_p1: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_1)
	var cards_p2: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_2)
	
	var envido_p1: Dictionary = GameService.eval_envido(cards_p1)
	var envido_p2: Dictionary = GameService.eval_envido(cards_p2)
	
	# TODO: Comparar y otorgar puntos
	print("ENVIDO aceptado - P1: ", envido_p1, " P2: ", envido_p2)


func _handle_truco_accepted(_requester: Enums.Player, _responder: Enums.Player) -> void:
	var random_card: Card = cards_player_2.cards.pick_random()
	play_card(random_card, Enums.Player.PLAYER_2)
	_ai_playing = false
	
	
func _handle_retruco_accepted(_requester: Enums.Player, _responder: Enums.Player) -> void:
	# Retruco aceptado, el juego continúa con valor aumentado
	print("RETRUCO aceptado")


func _handle_vale4_accepted(_requester: Enums.Player, _responder: Enums.Player) -> void:
	# Vale 4 aceptado, el juego continúa con valor máximo
	print("VALE 4 aceptado")


## Resetea las llamadas de acciones al inicio de una nueva ronda
func _reset_action_calls() -> void:
	for action: Enums.Action in _action_calls.keys():
		_action_calls[action] = false


## Decide qué acción debe hacer la IA
func _decide_ai_action() -> Enums.Action:
	match current_turn:
		Enums.Turn.ROUND_1:
			var cards_data_p2: Array[CardData] = _get_player_cards_data(Enums.Player.PLAYER_2)
			
			var flower_result: Dictionary = GameService.eval_flor(cards_data_p2)
			if flower_result["valid"] and _is_action_valid(Enums.Action.FLOR):
				return Enums.Action.FLOR
			
			var envido_result: Dictionary = GameService.eval_envido(cards_data_p2)
			if envido_result["valid"] and _is_action_valid(Enums.Action.ENVIDO):
				return Enums.Action.ENVIDO
		
		_:
			# En rondas 2 y 3, puede cantar truco
			if _is_action_valid(Enums.Action.TRUCO):
				return Enums.Action.TRUCO
	
	return Enums.Action.NONE

# ============================================================================
# ROUND MANAGEMENT
# ============================================================================

func _on_card_played(card: Card, player: Enums.Player) -> void:
	current_round_cards[player] = card
	
	_switch_to_next_player()
	if _is_round_complete(): _evaluate_and_end_round()


func _switch_to_next_player() -> void:
	current_player = Enums.Player.PLAYER_2 if current_player == Enums.Player.PLAYER_1 else Enums.Player.PLAYER_1
	_ai_playing = false # Resetear flag cuando cambia el turno
	turn_changed.emit(current_player)


func _is_round_complete() -> bool:
	return current_round_cards[Enums.Player.PLAYER_1] != null and current_round_cards[Enums.Player.PLAYER_2] != null


func _evaluate_and_end_round() -> void:
	# Obtener las cartas directamente de los slots para asegurar que son las jugadas
	var slot_p1: CardSlot = _get_player_slot(Enums.Player.PLAYER_1, current_turn)
	var slot_p2: CardSlot = _get_player_slot(Enums.Player.PLAYER_2, current_turn)
	
	if not slot_p1 or not slot_p2: return
	
	var card_p1: Card = slot_p1.get_card()
	var card_p2: Card = slot_p2.get_card()
	
	if not card_p1 or not card_p2: return
	
	var evaluation: Dictionary = GameService.eval_power_cards(card_p1.card_data as CardData, card_p2.card_data as CardData)
	
	var winner: Enums.Player = Enums.Player.PLAYER_1 # TODO -> mano gana
	var winner_card: CardData = evaluation["winner"]

	if winner_card == card_p1.card_data: winner = Enums.Player.PLAYER_1
	else: winner = Enums.Player.PLAYER_2

	if current_turn < Enums.Turn.ROUND_3: _start_next_round(winner)
	else: game_state = Enums.GameState.GAME_OVER
	
	round_result.emit({
		"winner": {
			"player": winner,
			"card": card_p1 if winner == Enums.Player.PLAYER_1 else card_p2,
		},
		"loser": {
			"player": Enums.Player.PLAYER_1 if winner == Enums.Player.PLAYER_2 else Enums.Player.PLAYER_2,
			"card": card_p1 if winner == Enums.Player.PLAYER_2 else card_p2,
		},
	})


func _start_next_round(round_winner: Enums.Player) -> void:
	var next_round: Enums.Turn
	match current_turn:
		Enums.Turn.ROUND_1:
			next_round = Enums.Turn.ROUND_2
		Enums.Turn.ROUND_2:
			next_round = Enums.Turn.ROUND_3
		_:
			next_round = Enums.Turn.ROUND_3
	
	current_turn = next_round
	current_player = round_winner
	_ai_playing = false
	
	_reset_round_cards()
	_reset_action_calls() # Resetear acciones en nueva ronda
	game_state = Enums.GameState.WAITING_ACTION

	turn_changed.emit(round_winner)


func _reset_round_cards() -> void:
	current_round_cards[Enums.Player.PLAYER_1] = null
	current_round_cards[Enums.Player.PLAYER_2] = null


# ============================================================================
# PRIVATE METHODS
# ============================================================================


func _get_player_slot(player: Enums.Player, turn: Enums.Turn) -> CardSlot:
	var slots: Array[CardSlot]

	if player == Enums.Player.PLAYER_1: slots = slots_player_1
	else: slots = slots_player_2
		
	var index: int = 0
	
	match turn:
		Enums.Turn.ROUND_1: index = 0
		Enums.Turn.ROUND_2: index = 1
		Enums.Turn.ROUND_3: index = 2
	
	if slots.is_empty(): return null
	if index < slots.size(): return slots[index]
	return slots[0]


func _get_player_cards_data(player: Enums.Player) -> Array[CardData]:
	var cards_data: Array[CardData] = []
	var hand: CardHand = cards_player_1 if player == Enums.Player.PLAYER_1 else cards_player_2
	
	if not hand: return cards_data
	
	for card: Card in hand.cards:
		if card and card.card_data:
			cards_data.append(card.card_data as CardData)
	
	return cards_data