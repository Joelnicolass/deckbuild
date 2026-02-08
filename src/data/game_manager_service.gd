extends Node

## GameManagerService — Gestiona el flujo de una partida de Truco Argentino.
##
## FLUJO POR TURNO:
##   turn_started(player) → jugador puede CANTAR o TIRAR CARTA
##     → Si canta: action_requested → oponente responde → must_play_card → tira carta
##     → Si tira carta: avanza turno → turn_started(otro jugador)
##     → Si ambos tiraron: evaluar ronda → ganador inicia siguiente ronda
##
## MÁQUINA DE ESTADOS:
##   WAITING_ACTION   → Jugador puede cantar o tirar carta
##   WAITING_RESPONSE → Esperando respuesta del oponente a un canto
##   PLAYING_CARD     → Jugador DEBE tirar carta (después de resolver un canto)
##   GAME_OVER        → Juego terminado
##
## REGLAS:
##   - Envido/Flor: solo ronda 1, antes de tirar la primera carta
##   - Truco: en cualquier momento, si no se ha cantado antes
##   - Responder truco con envido: solo ronda 1, si no se cantó envido antes
##   - Ningún canto se puede repetir una vez cantado (hasta reiniciar)

const DELAY_AI: float = 1.0


# ============================================================================
# SIGNALS (comunicación con la capa de UI)
# ============================================================================

## Inicio de partida
signal game_started(starting_player: Enums.Player)

## Comienza el turno de un jugador (puede cantar o tirar carta)
signal turn_started(player: Enums.Player)

## El jugador DEBE tirar carta (después de resolver un canto)
signal must_play_card(player: Enums.Player)

## Alguien cantó (envido, truco, etc.)
signal action_requested(action: Enums.Action, requester: Enums.Player)

## Se resolvió un canto (aceptado o rechazado)
signal action_resolved(action: Enums.Action, accepted: bool, requester: Enums.Player)

## Una carta fue jugada a un slot
signal card_played(card: Card, player: Enums.Player)

## Resultado de una ronda (ganador, perdedor, cartas)
signal round_result(result: Dictionary)


# ============================================================================
# STATE
# ============================================================================

var current_player: Enums.Player
var current_turn: Enums.Turn = Enums.Turn.ROUND_1
var game_state: Enums.GameState = Enums.GameState.WAITING_ACTION

var cards_player_1: CardHand
var cards_player_2: CardHand
var slots_player_1: Array[CardSlot] = []
var slots_player_2: Array[CardSlot] = []

# Cartas jugadas en la ronda actual
var _round_cards: Dictionary = {
	Enums.Player.PLAYER_1: null,
	Enums.Player.PLAYER_2: null,
}

# Registro de cantos: true = ya se cantó (no se puede repetir)
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

# Canto pendiente de respuesta
var _pending_action: Enums.Action = Enums.Action.NONE
var _action_requester: Enums.Player

# Indica si ya se tiró al menos una carta en la ronda 1
var _first_card_played: bool = false

# Previene llamadas concurrentes de la IA
var _ai_busy: bool = false


# ============================================================================
# PUBLIC API
# ============================================================================

func initialize(p1_cards: CardHand, p2_cards: CardHand, p1_slots: Array[CardSlot], p2_slots: Array[CardSlot]) -> void:
	cards_player_1 = p1_cards
	cards_player_2 = p2_cards
	slots_player_1 = p1_slots
	slots_player_2 = p2_slots


func start_game() -> void:
	randomize()
	current_player = Enums.Player.PLAYER_1 if randf() < 0.5 else Enums.Player.PLAYER_2
	current_turn = Enums.Turn.ROUND_1
	game_state = Enums.GameState.WAITING_ACTION
	_first_card_played = false
	_ai_busy = false
	_pending_action = Enums.Action.NONE
	_reset_round_cards()
	_reset_action_calls()
	
	game_started.emit(current_player)
	turn_started.emit(current_player)


## Tira una carta al slot correspondiente. Valida estado.
func play_card(card: Card, player: Enums.Player) -> void:
	if player != current_player: return
	if game_state != Enums.GameState.WAITING_ACTION and game_state != Enums.GameState.PLAYING_CARD:
		return
	
	var slot: CardSlot = _get_slot(player, current_turn)
	if not slot: return
	
	# Colocar carta en slot
	slot.unlock()
	slot.add_card(card)
	if slot.get_card() == card:
		var layout: CardTrucoVM = card.get_layout() as CardTrucoVM
		if layout and layout.is_flipped:
			layout.flip()
	slot.lock()
	
	# Registrar primera carta jugada en ronda 1
	if current_turn == Enums.Turn.ROUND_1 and not _first_card_played:
		_first_card_played = true
	
	_round_cards[player] = card
	card_played.emit(card, player)
	
	# Avanzar juego
	if _is_round_complete():
		_evaluate_round()
	else:
		_advance_turn()


## Solicita un canto. Retorna true si fue válido.
func request_action(action: Enums.Action, requester: Enums.Player) -> bool:
	if requester != current_player: return false
	if game_state != Enums.GameState.WAITING_ACTION: return false
	if not _is_action_valid(action): return false
	
	_action_calls[action] = true
	_pending_action = action
	_action_requester = requester
	game_state = Enums.GameState.WAITING_RESPONSE
	
	print(IntlService.ACTION_WORDINGS[action])
	action_requested.emit(action, requester)
	return true


## Responde a un canto pendiente. Puede responder truco con envido (regla especial).
func respond_to_action(accepted: bool, responder: Enums.Player, alternative: Enums.Action = Enums.Action.NONE) -> bool:
	if _pending_action == Enums.Action.NONE: return false
	if responder == _action_requester: return false
	if game_state != Enums.GameState.WAITING_RESPONSE: return false
	
	var action: Enums.Action = _pending_action
	var requester: Enums.Player = _action_requester
	
	# Regla especial: responder truco con envido en ronda 1
	if action == Enums.Action.TRUCO and alternative != Enums.Action.NONE:
		if _try_respond_truco_with_envido(alternative, responder):
			return true
	
	# Limpiar canto pendiente
	_pending_action = Enums.Action.NONE
	
	# Procesar si fue aceptado
	if accepted:
		_handle_accepted(action, requester, responder)
	
	action_resolved.emit(action, accepted, requester)
	
	# Rechazar truco/retruco/vale4 = game over
	if not accepted and action in [Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4]:
		game_state = Enums.GameState.GAME_OVER
		return true
	
	# Después de cualquier resolución: jugador actual DEBE tirar carta
	game_state = Enums.GameState.PLAYING_CARD
	must_play_card.emit(current_player)
	return true


# ============================================================================
# AI
# ============================================================================

## IA toma su turno: decide si cantar o tirar carta.
## Se llama cuando turn_started se emite para PLAYER_2.
func ai_turn() -> void:
	if _ai_busy: return
	if current_player != Enums.Player.PLAYER_2: return
	if cards_player_2.cards.is_empty(): return
	if game_state != Enums.GameState.WAITING_ACTION: return
	
	_ai_busy = true
	await get_tree().create_timer(DELAY_AI).timeout
	
	if not _ai_can_act():
		_ai_busy = false
		return
	
	# Intentar cantar
	var action: Enums.Action = _decide_ai_action()
	if action != Enums.Action.NONE and request_action(action, Enums.Player.PLAYER_2):
		_ai_busy = false
		return
	
	# Si no canta, tirar carta
	_do_ai_play_card()


## IA tira carta obligatoriamente (después de resolver un canto).
## Se llama cuando must_play_card se emite para PLAYER_2.
func ai_play_card() -> void:
	if _ai_busy: return
	if current_player != Enums.Player.PLAYER_2: return
	if cards_player_2.cards.is_empty(): return
	if game_state != Enums.GameState.PLAYING_CARD: return
	
	_ai_busy = true
	await get_tree().create_timer(DELAY_AI).timeout
	
	if not _ai_can_act():
		_ai_busy = false
		return
	
	_do_ai_play_card()


## IA responde a un canto pendiente.
## Se llama cuando action_requested se emite por PLAYER_1.
func ai_respond_to_action() -> void:
	if _ai_busy: return
	if _pending_action == Enums.Action.NONE: return
	if game_state != Enums.GameState.WAITING_RESPONSE: return
	
	_ai_busy = true
	await get_tree().create_timer(DELAY_AI).timeout
	
	if _pending_action == Enums.Action.NONE or game_state != Enums.GameState.WAITING_RESPONSE:
		_ai_busy = false
		return
	
	var accepted: bool = _decide_ai_response(_pending_action)
	print("AI ", IntlService.ACTION_WORDINGS[_pending_action], " ", accepted)
	respond_to_action(accepted, Enums.Player.PLAYER_2)
	_ai_busy = false


func _do_ai_play_card() -> void:
	if cards_player_2.cards.is_empty():
		_ai_busy = false
		return
	var random_card: Card = cards_player_2.cards.pick_random()
	play_card(random_card, Enums.Player.PLAYER_2)
	_ai_busy = false


func _ai_can_act() -> bool:
	return current_player == Enums.Player.PLAYER_2 \
		and not cards_player_2.cards.is_empty() \
		and game_state != Enums.GameState.GAME_OVER


func _decide_ai_action() -> Enums.Action:
	# Prioridad 1: Envido/Flor en ronda 1
	if _can_call_envido_flor():
		var cards: Array[CardData] = _get_hand_data(Enums.Player.PLAYER_2)
		
		if GameService.eval_flor(cards)["valid"] and _is_action_valid(Enums.Action.FLOR):
			return Enums.Action.FLOR
		
		if GameService.eval_envido(cards)["valid"] and _is_action_valid(Enums.Action.ENVIDO):
			return Enums.Action.ENVIDO
	
	# Prioridad 2: Truco
	if _is_action_valid(Enums.Action.TRUCO):
		return Enums.Action.TRUCO
	
	return Enums.Action.NONE


func _decide_ai_response(_action: Enums.Action) -> bool:
	return true # TODO: estrategia real según cartas


# ============================================================================
# BUSINESS RULES
# ============================================================================

## Valida si un canto es válido según las reglas de negocio
func _is_action_valid(action: Enums.Action) -> bool:
	# Si ya se cantó, no se puede repetir
	if _action_calls.has(action) and _action_calls[action]:
		return false
	
	match action:
		Enums.Action.FLOR, Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			return _can_call_envido_flor()
		
		Enums.Action.CONTRAFLOR:
			return _action_calls[Enums.Action.FLOR]
		
		Enums.Action.CONTRAFLOR_AL_RESTO:
			return _action_calls[Enums.Action.CONTRAFLOR]
		
		Enums.Action.TRUCO:
			return true
		
		Enums.Action.RETRUCO:
			return _action_calls[Enums.Action.TRUCO]
		
		Enums.Action.VALE_4:
			return _action_calls[Enums.Action.RETRUCO]
		
		_:
			return false


## Envido/Flor solo se puede cantar en ronda 1, antes de la primera carta
func _can_call_envido_flor() -> bool:
	return current_turn == Enums.Turn.ROUND_1 and not _first_card_played


## Se puede responder truco con envido solo en ronda 1, si no se cantó envido antes
func _can_respond_truco_with_envido() -> bool:
	if current_turn != Enums.Turn.ROUND_1: return false
	if _first_card_played: return false
	if _action_calls[Enums.Action.ENVIDO]: return false
	if _action_calls[Enums.Action.REAL_ENVIDO]: return false
	if _action_calls[Enums.Action.FALTA_ENVIDO]: return false
	return true


## Regla especial: al recibir truco, se puede responder con envido (anula el truco).
## Esto inicia un nuevo canto de envido sin cambiar el turno.
func _try_respond_truco_with_envido(alternative: Enums.Action, responder: Enums.Player) -> bool:
	if not alternative in [Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO]:
		return false
	if not _can_respond_truco_with_envido(): return false
	if _action_calls[alternative]: return false
	
	# Anular truco
	_action_calls[Enums.Action.TRUCO] = false
	_pending_action = Enums.Action.NONE
	
	# Iniciar envido como nuevo canto (del responder)
	_action_calls[alternative] = true
	_pending_action = alternative
	_action_requester = responder
	# game_state sigue en WAITING_RESPONSE
	
	print(IntlService.ACTION_WORDINGS[alternative])
	action_requested.emit(alternative, responder)
	return true


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func _handle_accepted(action: Enums.Action, _requester: Enums.Player, _responder: Enums.Player) -> void:
	match action:
		Enums.Action.FLOR, Enums.Action.CONTRAFLOR, Enums.Action.CONTRAFLOR_AL_RESTO:
			_eval_flor(action)
		Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			_eval_envido(action)
		Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4:
			print(IntlService.ACTION_WORDINGS[action], " aceptado")


func _eval_envido(action: Enums.Action) -> void:
	var p1: Dictionary = GameService.eval_envido(_get_hand_data(Enums.Player.PLAYER_1))
	var p2: Dictionary = GameService.eval_envido(_get_hand_data(Enums.Player.PLAYER_2))
	print(IntlService.ACTION_WORDINGS[action], " - P1: ", p1, " P2: ", p2)


func _eval_flor(action: Enums.Action) -> void:
	var p1: Dictionary = GameService.eval_flor(_get_hand_data(Enums.Player.PLAYER_1))
	var p2: Dictionary = GameService.eval_flor(_get_hand_data(Enums.Player.PLAYER_2))
	print(IntlService.ACTION_WORDINGS[action], " - P1: ", p1, " P2: ", p2)


# ============================================================================
# ROUND MANAGEMENT
# ============================================================================

## Avanza al siguiente turno (sin evaluar ronda)
func _advance_turn() -> void:
	current_player = Enums.Player.PLAYER_2 if current_player == Enums.Player.PLAYER_1 else Enums.Player.PLAYER_1
	game_state = Enums.GameState.WAITING_ACTION
	_ai_busy = false
	turn_started.emit(current_player)


func _is_round_complete() -> bool:
	return _round_cards[Enums.Player.PLAYER_1] != null and _round_cards[Enums.Player.PLAYER_2] != null


func _evaluate_round() -> void:
	var slot_p1: CardSlot = _get_slot(Enums.Player.PLAYER_1, current_turn)
	var slot_p2: CardSlot = _get_slot(Enums.Player.PLAYER_2, current_turn)
	if not slot_p1 or not slot_p2: return
	
	var card_p1: Card = slot_p1.get_card()
	var card_p2: Card = slot_p2.get_card()
	if not card_p1 or not card_p2: return
	
	var evaluation: Dictionary = GameService.eval_power_cards(card_p1.card_data as CardData, card_p2.card_data as CardData)
	var winner_data: CardData = evaluation["winner"]
	var winner: Enums.Player = Enums.Player.PLAYER_1 if winner_data == card_p1.card_data else Enums.Player.PLAYER_2
	
	# Avanzar ronda o terminar juego
	if current_turn < Enums.Turn.ROUND_3:
		_start_next_round(winner)
	else:
		game_state = Enums.GameState.GAME_OVER
	
	round_result.emit({
		"winner": {
			"player": winner,
			"card": card_p1 if winner == Enums.Player.PLAYER_1 else card_p2,
		},
		"loser": {
			"player": Enums.Player.PLAYER_2 if winner == Enums.Player.PLAYER_1 else Enums.Player.PLAYER_1,
			"card": card_p2 if winner == Enums.Player.PLAYER_1 else card_p1,
		},
	})


func _start_next_round(winner: Enums.Player) -> void:
	match current_turn:
		Enums.Turn.ROUND_1: current_turn = Enums.Turn.ROUND_2
		Enums.Turn.ROUND_2: current_turn = Enums.Turn.ROUND_3
		_: current_turn = Enums.Turn.ROUND_3
	
	current_player = winner
	game_state = Enums.GameState.WAITING_ACTION
	_ai_busy = false
	_reset_round_cards()
	
	turn_started.emit(winner)


# ============================================================================
# HELPERS
# ============================================================================

func _get_slot(player: Enums.Player, turn: Enums.Turn) -> CardSlot:
	var slots: Array[CardSlot] = slots_player_1 if player == Enums.Player.PLAYER_1 else slots_player_2
	var idx: int = 0
	match turn:
		Enums.Turn.ROUND_1: idx = 0
		Enums.Turn.ROUND_2: idx = 1
		Enums.Turn.ROUND_3: idx = 2
	if slots.is_empty(): return null
	return slots[idx] if idx < slots.size() else slots[0]


func _get_hand_data(player: Enums.Player) -> Array[CardData]:
	var data: Array[CardData] = []
	var hand: CardHand = cards_player_1 if player == Enums.Player.PLAYER_1 else cards_player_2
	if not hand: return data
	for card: Card in hand.cards:
		if card and card.card_data:
			data.append(card.card_data as CardData)
	return data


func _reset_round_cards() -> void:
	_round_cards[Enums.Player.PLAYER_1] = null
	_round_cards[Enums.Player.PLAYER_2] = null


func _reset_action_calls() -> void:
	for action: Enums.Action in _action_calls.keys():
		_action_calls[action] = false
