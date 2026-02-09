extends Node

## GameManagerService — Gestiona el flujo de una partida de Truco Argentino.
##
## ARQUITECTURA:
##   Este servicio es el ORQUESTADOR del juego. No conoce la UI.
##   Se comunica con la capa de presentación (main.gd) exclusivamente por señales.
##   Llama a GameService para evaluaciones puras (poder de cartas, envido, flor).
##
## FLUJO POR TURNO:
##   turn_started(player) → jugador puede CANTAR o TIRAR CARTA
##     → Si canta: action_requested → oponente responde → must_play_card → tira carta
##     → Si tira carta: avanza turno → turn_started(otro jugador)
##     → Si ambos tiraron: evaluar ronda → ganador inicia siguiente ronda
##
## RESPUESTAS A UN CANTO:
##   Aceptar  → el canto se resuelve, jugador actual tira carta
##   Rechazar → el canto se rechaza (truco rechazado = game over, envido rechazado = continúa)
##   Subir    → acepta implícitamente y sube la apuesta (envido→real envido, truco→retruco)
##   Anular   → solo truco→envido en ronda 1: cancela el truco y abre envido
##
## CADENAS VÁLIDAS DE SUBIDA:
##   Envido → Real Envido → Falta Envido (salto directo Envido→Falta Envido válido)
##   Truco → Retruco → Vale 4
##   Flor → Contraflor → Contraflor al Resto
##
## MÁQUINA DE ESTADOS:
##   WAITING_ACTION   → Jugador puede cantar o tirar carta
##   WAITING_RESPONSE → Esperando respuesta del oponente a un canto
##   PLAYING_CARD     → Jugador DEBE tirar carta (después de resolver un canto)
##   GAME_OVER        → Juego terminado
##
## REGLAS:
##   - Envido/Flor: solo ronda 1, antes de que el jugador que canta tire su primera carta
##   - Truco: en cualquier momento, si no se ha cantado antes
##   - Responder truco con envido: solo ronda 1, si el responder no tiró carta y no se cantó envido
##   - Ningún canto se puede repetir una vez cantado (hasta reiniciar partida)

const DELAY_AI: float = 1.0
const AGGRESSIVITY: float = 0.7


# ============================================================================
# SEÑALES — Comunicación con la capa de UI (main.gd)
# ============================================================================
# main.gd escucha estas señales y reacciona:
#   - Habilitar/deshabilitar drag & drop
#   - Mostrar/ocultar botones de aceptar/rechazar
#   - Disparar funciones de IA (ai_turn, ai_play_card, ai_respond_to_action)
#   - Ejecutar animaciones
# ============================================================================

## Inicio de partida
signal game_started(starting_player: Enums.Player)

## Comienza el turno de un jugador (puede cantar o tirar carta)
## → main.gd: P1 → habilitar drag + botones de canto | P2 → llamar ai_turn()
signal turn_started(player: Enums.Player)

## El jugador DEBE tirar carta (después de resolver un canto, no puede cantar)
## → main.gd: P1 → habilitar drag (sin botones) | P2 → llamar ai_play_card()
signal must_play_card(player: Enums.Player)

## Alguien cantó (envido, truco, etc.) — el oponente debe responder
## → main.gd: P1 cantó → llamar ai_respond_to_action() | P2 cantó → mostrar aceptar/rechazar
signal action_requested(action: Enums.Action, requester: Enums.Player)

## Se resolvió un canto (aceptado o rechazado)
## → main.gd: feedback visual (texto "Quiero" / "No quiero", animación)
signal action_resolved(action: Enums.Action, accepted: bool, requester: Enums.Player)

## Una carta fue jugada a un slot
## → main.gd: animación de carta jugada (futuro)
signal card_played(card: Card, player: Enums.Player)

## Resultado de una ronda (ganador, perdedor, cartas)
## → main.gd: animación de carta ganadora/perdedora (ya implementada)
signal round_result(result: Dictionary)


# ============================================================================
# ESTADO DEL JUEGO
# ============================================================================

var current_player: Enums.Player
var current_turn: Enums.Turn = Enums.Turn.ROUND_1
var game_state: Enums.GameState = Enums.GameState.WAITING_ACTION

## Referencias a las manos y slots (inyectados desde main.gd vía initialize())
var cards_player_1: CardHand
var cards_player_2: CardHand
var slots_player_1: Array[CardSlot] = []
var slots_player_2: Array[CardSlot] = []

## Cartas jugadas en la ronda actual (se resetean cada ronda)
var _round_cards: Dictionary = {
	Enums.Player.PLAYER_1: null,
	Enums.Player.PLAYER_2: null,
}

## Registro de cantos: true = ya se cantó (no se puede repetir hasta reiniciar)
## Se resetea SOLO al iniciar una nueva partida (start_game)
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

## Canto pendiente de respuesta
var _pending_action: Enums.Action = Enums.Action.NONE
var _action_requester: Enums.Player

## Indica si cada jugador ya tiró su primera carta en la ronda 1.
## Envido/Flor se puede cantar siempre que el jugador que canta NO haya tirado carta aún.
## Es por jugador: si P1 ya tiró pero P2 no, P2 todavía puede cantar envido.
var _has_played_first_card: Dictionary = {
	Enums.Player.PLAYER_1: false,
	Enums.Player.PLAYER_2: false,
}

## Previene llamadas concurrentes de la IA (por el await del delay)
var _ai_busy: bool = false


# ============================================================================
# API PÚBLICA — Llamada desde main.gd
# ============================================================================

## Inyecta las referencias de manos y slots. Llamar antes de start_game().
func initialize(p1_cards: CardHand, p2_cards: CardHand, p1_slots: Array[CardSlot], p2_slots: Array[CardSlot]) -> void:
	cards_player_1 = p1_cards
	cards_player_2 = p2_cards
	slots_player_1 = p1_slots
	slots_player_2 = p2_slots


## Inicia una nueva partida. Resetea todo el estado.
func start_game() -> void:
	randomize()
	current_player = Enums.Player.PLAYER_1 if randf() < 0.5 else Enums.Player.PLAYER_2
	current_turn = Enums.Turn.ROUND_1
	game_state = Enums.GameState.WAITING_ACTION
	_has_played_first_card[Enums.Player.PLAYER_1] = false
	_has_played_first_card[Enums.Player.PLAYER_2] = false
	_ai_busy = false
	_pending_action = Enums.Action.NONE
	_reset_round_cards()
	_reset_action_calls()
	
	game_started.emit(current_player)
	turn_started.emit(current_player)


## Tira una carta al slot correspondiente.
## Válido en estados: WAITING_ACTION (turno libre) o PLAYING_CARD (post-canto).
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
	
	# Registrar que este jugador ya tiró su primera carta en ronda 1
	# (bloquea envido/flor para ESTE jugador, el otro aún puede si no tiró)
	if current_turn == Enums.Turn.ROUND_1 and not _has_played_first_card[player]:
		_has_played_first_card[player] = true
	
	_round_cards[player] = card
	card_played.emit(card, player)
	
	# Avanzar: evaluar ronda si ambos jugaron, sino pasar turno
	if _is_round_complete():
		_evaluate_round()
	else:
		_advance_turn()


## Solicita un canto. Retorna true si fue válido.
## Llamado desde: main.gd (botón de canto del usuario) o ai_turn() (IA).
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


## Responde a un canto pendiente.
## El parámetro `alternative` permite:
##   - Subir la apuesta (envido→real envido, truco→retruco, etc.)
##   - Responder truco con envido en ronda 1 (anula el truco)
## Llamado desde: main.gd (botones aceptar/rechazar/subir) o ai_respond_to_action().
func respond_to_action(accepted: bool, responder: Enums.Player, alternative: Enums.Action = Enums.Action.NONE) -> bool:
	if _pending_action == Enums.Action.NONE: return false
	if responder == _action_requester: return false
	if game_state != Enums.GameState.WAITING_RESPONSE: return false
	
	var action: Enums.Action = _pending_action
	var requester: Enums.Player = _action_requester
	
	# Respuesta con alternativa (subir apuesta o anular truco con envido)
	if alternative != Enums.Action.NONE:
		# Regla especial: responder truco con envido (ANULA el truco)
		if action == Enums.Action.TRUCO:
			if _try_respond_truco_with_envido(alternative, responder):
				return true
		
		# Subir la apuesta (envido→real envido, truco→retruco, etc.)
		if _try_raise_action(action, alternative, responder):
			return true
	
	# Limpiar canto pendiente
	_pending_action = Enums.Action.NONE
	
	# Procesar resultado del canto aceptado
	if accepted:
		_handle_accepted(action, requester, responder)
	
	action_resolved.emit(action, accepted, requester)
	
	# Rechazar truco/retruco/vale4 = el que rechaza pierde la mano
	if not accepted and action in [Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4]:
		game_state = Enums.GameState.GAME_OVER
		# TODO: Otorgar puntos al ganador por rechazo de truco.
		# El requester gana la cantidad de puntos correspondiente al canto anterior.
		# Ejemplo: rechazo de Truco = 1 punto, rechazo de Retruco = 2, etc.
		return true
	
	# Después de cualquier resolución: jugador actual DEBE tirar carta
	game_state = Enums.GameState.PLAYING_CARD
	must_play_card.emit(current_player)
	return true


# ============================================================================
# INTELIGENCIA ARTIFICIAL
# ============================================================================
# La IA tiene 3 puntos de entrada (llamados desde main.gd según la señal):
#   ai_turn()              ← turn_started(P2)       → decide cantar o tirar
#   ai_play_card()         ← must_play_card(P2)     → tira carta obligatoria
#   ai_respond_to_action() ← action_requested(_, P1) → responde a canto del usuario
#
# Y 4 funciones de decisión internas donde va la inteligencia:
#   _decide_ai_action()    → ¿Qué canto hacer? (o NONE para no cantar)
#   _decide_ai_response()  → ¿Acepto o rechazo el canto del oponente?
#   _decide_ai_raise()     → ¿Subo la apuesta? (o NONE para no subir)
#   _choose_best_card()    → ¿Qué carta jugar?
# ============================================================================

## IA toma su turno: decide si cantar o tirar carta.
## Se llama desde main.gd cuando turn_started se emite para PLAYER_2.
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
	
	# Intentar cantar algo
	var action: Enums.Action = _decide_ai_action()
	if action != Enums.Action.NONE and request_action(action, Enums.Player.PLAYER_2):
		_ai_busy = false
		return
	
	# Si no canta, tirar carta
	_do_ai_play_card()


## IA tira carta obligatoriamente (después de resolver un canto).
## Se llama desde main.gd cuando must_play_card se emite para PLAYER_2.
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


## IA responde a un canto pendiente del usuario.
## Se llama desde main.gd cuando action_requested se emite por PLAYER_1.
func ai_respond_to_action() -> void:
	if _ai_busy: return
	if _pending_action == Enums.Action.NONE: return
	if game_state != Enums.GameState.WAITING_RESPONSE: return
	
	_ai_busy = true
	await get_tree().create_timer(DELAY_AI).timeout
	
	if _pending_action == Enums.Action.NONE or game_state != Enums.GameState.WAITING_RESPONSE:
		_ai_busy = false
		return
	
	# Primero evaluar si quiere subir la apuesta
	var raise_action: Enums.Action = _decide_ai_raise(_pending_action)
	if raise_action != Enums.Action.NONE:
		respond_to_action(false, Enums.Player.PLAYER_2, raise_action)
		_ai_busy = false
		return
	
	# Si no sube, decidir si acepta o rechaza
	var accepted: bool = _decide_ai_response(_pending_action)
	respond_to_action(accepted, Enums.Player.PLAYER_2)
	_ai_busy = false


## Juega una carta por la IA. Delega la elección a _choose_best_card().
func _do_ai_play_card() -> void:
	if cards_player_2.cards.is_empty():
		_ai_busy = false
		return
	var card: Card = _choose_best_card()
	play_card(card, Enums.Player.PLAYER_2)
	_ai_busy = false


## Verifica que la IA puede actuar (no se cambió de turno ni terminó el juego durante el await).
func _ai_can_act() -> bool:
	return current_player == Enums.Player.PLAYER_2 \
		and not cards_player_2.cards.is_empty() \
		and game_state != Enums.GameState.GAME_OVER


# ============================================================================
# DECISIONES DE IA — Agregar inteligencia aquí
# ============================================================================

## Decide qué canto hacer al inicio del turno de la IA.
## Retorna Enums.Action.NONE para no cantar (y tirar carta directamente).
##
## Estrategia:
##   - Envido/Flor: solo si el valor de envido/flor supera un umbral mínimo.
##   - Truco: solo si la mano restante es suficientemente fuerte.
##     → Si el oponente ya jugó una carta muy fuerte en esta ronda, NO cantar.
##     → En rondas avanzadas con pocas cartas, evaluar si se puede ganar.
##   - AGGRESSIVITY modula la probabilidad de cantar (0.0 = nunca, 1.0 = siempre).
func _decide_ai_action() -> Enums.Action:
	# Factor aleatorio: a veces la IA simplemente no canta
	if not _should_act(AGGRESSIVITY):
		print("No canta")
		return Enums.Action.NONE
	
	var cards: Array[CardData] = _get_hand_data(Enums.Player.PLAYER_2)
	if cards.is_empty():
		return Enums.Action.NONE
	
	# --- Prioridad 1: Envido/Flor en ronda 1 (antes de la primera carta) ---
	if _can_call_envido_flor():
		# Flor: cantar si el valor es decente (>= 25, siendo máximo ~47)
		if _is_action_valid(Enums.Action.FLOR):
			var flor: Dictionary = GameService.eval_flor(cards)
			if flor["valid"]:
				return Enums.Action.FLOR
		
		# Envido: cantar solo si el envido es bueno (>= 25 de ~33 máximo)
		if _is_action_valid(Enums.Action.ENVIDO):
			var envido: Dictionary = GameService.eval_envido(cards)
			if envido["valid"] and envido["points"] >= randi_range(20, 28):
				print("Canta envido")
				return Enums.Action.ENVIDO
	
	# --- Prioridad 2: Truco (si no se cantó y la mano lo justifica) ---
	if _is_action_valid(Enums.Action.TRUCO):
		if _should_call_truco(cards):
			return Enums.Action.TRUCO
	
	return Enums.Action.NONE


## Evalúa si conviene cantar truco con las cartas actuales de la IA.
## Considera la fuerza de la mano y la carta del oponente si ya jugó.
##
## evaluate_hand_strength: menor = más fuerte (~3 perfecta, ~42 peor, ~15 fuerte)
## get_card_power: menor = más fuerte (1 = Ancho Espada, 14 = Cuatro)
func _should_call_truco(cards: Array[CardData]) -> bool:
	var hand_strength: int = GameService.evaluate_hand_strength(cards)
	
	# Umbral de fuerza de mano para cantar truco (randomizado para variedad)
	# Con 3 cartas: <= 15 es mano fuerte. Con 2: <= 10. Con 1: <= 5.
	var threshold: int
	match cards.size():
		3: threshold = randi_range(12, 18)
		2: threshold = randi_range(8, 13)
		1: threshold = randi_range(4, 8)
		_: return false
	
	# Si la mano es débil, no cantar
	if hand_strength > threshold:
		return false
	
	# Si el oponente ya jugó una carta en esta ronda, verificar que podamos ganarla
	var opponent_card: Card = _round_cards[Enums.Player.PLAYER_1]
	if opponent_card:
		var opp_power: int = GameService.get_card_power(opponent_card.card_data as CardData)
		
		# Verificar si tenemos al menos una carta que le gane
		var can_win_round: bool = false
		for card: CardData in cards:
			if GameService.get_card_power(card) < opp_power:
				can_win_round = true
				break
		
		# Si no podemos ganar esta ronda, no cantar truco (pérdida obvia)
		if not can_win_round:
			return false
		
		# Si el oponente jugó algo muy fuerte (top 4: Ancho Espada, Ancho Basto, 7 Espada, 7 Oro)
		# ser más conservador: solo cantar si nuestra mejor carta le gana
		if opp_power <= 4:
			var our_best_power: int = 999
			for card: CardData in cards:
				our_best_power = mini(our_best_power, GameService.get_card_power(card))
			if our_best_power >= opp_power:
				return false # No le ganamos ni con la mejor → no cantar
	
	return true


## Decide si la IA acepta o rechaza un canto del oponente.
## Retorna true para aceptar, false para rechazar.
##
## PARA MEJORAR:
##   - Envido: comparar valor de envido propio contra un umbral (ej: aceptar si >= 25)
##   - Truco: evaluar fuerza de las cartas restantes (las que NO se jugaron aún)
##   - Flor: comparar valor de flor propio contra probabilidad de ganar
##   - Usar probabilidades (ej: 70% aceptar truco, 90% si tiene cartas fuertes)
func _decide_ai_response(action: Enums.Action) -> bool:
	match action:
		Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4:
			# TODO: Analizar cartas restantes en mano para decidir.
			# Ejemplo:
			#   var cards = _get_hand_data(Enums.Player.PLAYER_2)
			#   var strength = _evaluate_hand_strength(cards)
			#   return strength > THRESHOLD
			return true
		
		Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			# TODO: Comparar envido propio contra umbral.
			# Ejemplo:
			#   var cards = _get_hand_data(Enums.Player.PLAYER_2)
			#   var envido = GameService.eval_envido(cards)
			#   return envido["value"] >= 25
			return true
		
		Enums.Action.FLOR, Enums.Action.CONTRAFLOR, Enums.Action.CONTRAFLOR_AL_RESTO:
			# TODO: Comparar flor propia contra umbral.
			return true
		
		_:
			return true


## Decide si la IA quiere subir la apuesta ante un canto del oponente.
## Retorna la acción de subida (ej: RETRUCO) o NONE para no subir.
##
## Lógica actual:
##   - Truco → si el envido es alto y se puede, responder con ENVIDO (anula truco)
##   - Truco → si la mano es fuerte, subir a RETRUCO
##   - Envido → si el envido es muy alto, subir a REAL ENVIDO o FALTA ENVIDO
##   - AGGRESSIVITY controla la probabilidad de intentar subir (0.0 = nunca, 1.0 = siempre)
func _decide_ai_raise(action: Enums.Action) -> Enums.Action:
	# Umbrales de decisión (randomizados para variedad entre decisiones)
	# evaluate_hand_strength: menor = más fuerte (1=Ancho Espada, 14=Cuatro)
	# Con 3 cartas: ~3 (mano perfecta) a ~42 (peor mano), ~15 es una mano fuerte
	var THRESHOLD_TRUCO: int = randi_range(12, 18)
	var THRESHOLD_ENVIDO_FOR_TRUCO: int = randi_range(25, 28)
	var THRESHOLD_REAL_ENVIDO: int = randi_range(28, 30)
	var THRESHOLD_FALTA_ENVIDO: int = randi_range(30, 32)

	
	if action == Enums.Action.TRUCO:
		if not _should_act(AGGRESSIVITY):
			return Enums.Action.NONE
		
		var cards: Array[CardData] = _get_hand_data(Enums.Player.PLAYER_2)
		
		# Envido alto + condiciones válidas → responder con envido (anula truco)
		if _can_respond_truco_with_envido(Enums.Player.PLAYER_2):
			var envido: Dictionary = GameService.eval_envido(cards)
			if envido["valid"] and envido["points"] >= THRESHOLD_ENVIDO_FOR_TRUCO:
				return Enums.Action.ENVIDO

		# Mano fuerte → subir a retruco
		if GameService.evaluate_hand_strength(cards) < THRESHOLD_TRUCO:
			return Enums.Action.RETRUCO
		
	
	if action == Enums.Action.ENVIDO:
		if not _should_act(AGGRESSIVITY):
			return Enums.Action.NONE
		
		var envido: Dictionary = GameService.eval_envido(_get_hand_data(Enums.Player.PLAYER_2))
		if not envido["valid"]:
			return Enums.Action.NONE
		
		if envido["points"] >= THRESHOLD_FALTA_ENVIDO:
			return Enums.Action.FALTA_ENVIDO
		elif envido["points"] >= THRESHOLD_REAL_ENVIDO:
			return Enums.Action.REAL_ENVIDO
	
	return Enums.Action.NONE


## Elige qué carta jugar de la mano de la IA.
## Estrategia:
##   - Si el oponente ya jugó → buscar la carta más débil que le gane (economizar).
##     Si no puede ganar → tirar la más débil (sacrificar ronda, guardar fuertes).
##   - Si la IA juega primero:
##     → Ronda 1: carta intermedia (guardar la fuerte, no desperdiciar la débil)
##     → Ronda 2: si ganó ronda 1, jugar la más débil (ya tiene ventaja).
##                si perdió ronda 1, jugar la más fuerte (obligado a ganar).
##     → Ronda 3: siempre la más fuerte (última oportunidad).
##
## Escala de poder (GameService.get_card_power): menor = más fuerte.
func _choose_best_card() -> Card:
	var hand: Array[Card] = cards_player_2.cards.duplicate()
	if hand.is_empty(): return null
	if hand.size() == 1: return hand[0]
	
	# Ordenar mano por poder (menor = más fuerte primero)
	hand.sort_custom(_sort_by_power_asc)
	
	var opponent_card: Card = _round_cards[Enums.Player.PLAYER_1]
	
	if opponent_card:
		return _pick_card_vs_opponent(hand, opponent_card)
	else:
		return _pick_card_opening(hand)


## Elige carta cuando el oponente ya jugó.
## Busca la carta más débil que le gane. Si ninguna gana, tira la más débil.
func _pick_card_vs_opponent(sorted_hand: Array[Card], opponent_card: Card) -> Card:
	var opponent_power: int = GameService.get_card_power(opponent_card.card_data as CardData)
	
	# Buscar todas las cartas que le ganan (power < opponent_power)
	var winning_cards: Array[Card] = []
	for card: Card in sorted_hand:
		var power: int = GameService.get_card_power(card.card_data as CardData)
		if power < opponent_power:
			winning_cards.append(card)
	
	if not winning_cards.is_empty():
		# Tiene cartas que ganan → usar la MÁS DÉBIL que gane (economizar fuertes)
		# winning_cards está ordenado fuerte→débil, el último es el más débil que gana
		return winning_cards[winning_cards.size() - 1]
	
	# No puede ganar → tirar la carta MÁS DÉBIL (sacrificar, guardar fuertes)
	return sorted_hand[sorted_hand.size() - 1]


## Elige carta cuando la IA juega primero (no hay carta del oponente).
## Estrategia según ronda y situación.
func _pick_card_opening(sorted_hand: Array[Card]) -> Card:
	# sorted_hand[0] = más fuerte, sorted_hand[last] = más débil
	match current_turn:
		Enums.Turn.ROUND_1:
			# Ronda 1: jugar la carta intermedia
			# Guardamos la fuerte para rondas posteriores, no desperdiciamos la débil
			if sorted_hand.size() >= 3:
				if _should_act(AGGRESSIVITY):
					return sorted_hand[0] # jugar la más fuerte
				else:
					return sorted_hand[1] # intermedia
			else:
				return sorted_hand[0] # si solo quedan 2, jugar la más fuerte
		
		Enums.Turn.ROUND_2:
			# Ronda 2: depende de si ganamos la ronda anterior
			# Si ganamos ronda 1, jugar la más débil (ya tenemos ventaja)
			# Si perdimos ronda 1, jugar la más fuerte (obligados a ganar)
			# TODO: Llevar registro de rondas ganadas para mejorar esta decisión.
			# Por ahora, jugar la más fuerte (estrategia segura)
			return sorted_hand[0]
		
		Enums.Turn.ROUND_3:
			# Ronda 3: última oportunidad, jugar la más fuerte
			return sorted_hand[0]
		
		_:
			return sorted_hand[0]


## Comparador para ordenar cartas por poder ascendente (más fuerte primero).
## Menor power = carta más fuerte.
func _sort_by_power_asc(a: Card, b: Card) -> bool:
	var power_a: int = GameService.get_card_power(a.card_data as CardData)
	var power_b: int = GameService.get_card_power(b.card_data as CardData)
	return power_a < power_b


# ============================================================================
# REGLAS DE NEGOCIO — Validación de cantos
# ============================================================================
# Para agregar o cambiar reglas de cuándo se puede cantar:
#   _is_action_valid()              → precondiciones de cada canto
#   _can_call_envido_flor()         → cuándo envido/flor es válido (por jugador)
#   _can_respond_truco_with_envido() → cuándo se puede anular truco con envido
#   _is_valid_raise()               → cadenas válidas de escalada
# ============================================================================

## Valida si un canto es válido según las reglas de negocio.
## Para agregar un nuevo canto: agregar un case al match y definir sus precondiciones.
func _is_action_valid(action: Enums.Action) -> bool:
	# Si ya se cantó, no se puede repetir
	if _action_calls.has(action) and _action_calls[action]:
		return false
	
	match action:
		# Envido/Flor: solo ronda 1, antes de la primera carta
		Enums.Action.FLOR, Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			return _can_call_envido_flor()
		
		# Contraflor: solo si se cantó Flor antes
		Enums.Action.CONTRAFLOR:
			return _action_calls[Enums.Action.FLOR]
		
		# Contraflor al Resto: solo si se cantó Contraflor antes
		Enums.Action.CONTRAFLOR_AL_RESTO:
			return _action_calls[Enums.Action.CONTRAFLOR]
		
		# Truco: en cualquier momento si no se cantó
		Enums.Action.TRUCO:
			return true
		
		# Retruco: solo si se cantó Truco antes
		Enums.Action.RETRUCO:
			return _action_calls[Enums.Action.TRUCO]
		
		# Vale 4: solo si se cantó Retruco antes
		Enums.Action.VALE_4:
			return _action_calls[Enums.Action.RETRUCO]
		
		_:
			return false


## Envido/Flor solo se puede cantar en ronda 1, antes de que el jugador actual
## haya tirado su primera carta. Si P1 ya tiró pero P2 no, P2 aún puede cantar.
func _can_call_envido_flor() -> bool:
	return current_turn == Enums.Turn.ROUND_1 and not _has_played_first_card[current_player]


## Se puede responder truco con envido SOLO si:
##   - Estamos en ronda 1
##   - El jugador que responde NO tiró su primera carta aún
##   - No se cantó ningún tipo de envido antes
func _can_respond_truco_with_envido(responder: Enums.Player) -> bool:
	if current_turn != Enums.Turn.ROUND_1: return false
	if _has_played_first_card[responder]: return false
	if _action_calls[Enums.Action.ENVIDO]: return false
	if _action_calls[Enums.Action.REAL_ENVIDO]: return false
	if _action_calls[Enums.Action.FALTA_ENVIDO]: return false
	return true


## Verifica si un canto puede ser "subido" a otro.
## Define las cadenas válidas de escalada.
## Para agregar una nueva cadena: agregar un case al match.
##
## Cadenas actuales:
##   Envido → Real Envido | Falta Envido (salto directo válido)
##   Real Envido → Falta Envido
##   Truco → Retruco
##   Retruco → Vale 4
##   Flor → Contraflor
##   Contraflor → Contraflor al Resto
func _is_valid_raise(current_action: Enums.Action, raise: Enums.Action) -> bool:
	match current_action:
		Enums.Action.ENVIDO:
			return raise in [Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO]
		Enums.Action.REAL_ENVIDO:
			return raise == Enums.Action.FALTA_ENVIDO
		Enums.Action.TRUCO:
			return raise == Enums.Action.RETRUCO
		Enums.Action.RETRUCO:
			return raise == Enums.Action.VALE_4
		Enums.Action.FLOR:
			return raise == Enums.Action.CONTRAFLOR
		Enums.Action.CONTRAFLOR:
			return raise == Enums.Action.CONTRAFLOR_AL_RESTO
		_:
			return false


## Sube la apuesta: acepta implícitamente el canto actual y abre uno nuevo.
## Los roles se invierten: quien sube pasa a ser el requester.
## game_state sigue en WAITING_RESPONSE (el otro debe responder al raise).
func _try_raise_action(current_action: Enums.Action, raise: Enums.Action, responder: Enums.Player) -> bool:
	if not _is_valid_raise(current_action, raise): return false
	if _action_calls[raise]: return false
	
	# Registrar el raise como cantado
	_action_calls[raise] = true
	
	# El raise se convierte en el nuevo canto pendiente
	# Quien subió la apuesta es ahora el requester → el otro debe responder
	_pending_action = raise
	_action_requester = responder
	# game_state sigue en WAITING_RESPONSE
	
	print(IntlService.ACTION_WORDINGS[raise])
	action_requested.emit(raise, responder)
	return true


## Regla especial: al recibir truco, se puede responder con envido (anula el truco).
## Condiciones: ronda 1, sin carta jugada, sin envido previo.
## Resultado: truco se anula (se puede cantar de nuevo), envido se abre como nuevo canto.
func _try_respond_truco_with_envido(alternative: Enums.Action, responder: Enums.Player) -> bool:
	if not alternative in [Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO]:
		return false
	if not _can_respond_truco_with_envido(responder): return false
	if _action_calls[alternative]: return false
	
	# Anular truco (se puede cantar de nuevo más adelante)
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
# HANDLERS DE CANTOS ACEPTADOS — Cálculo de puntos
# ============================================================================
# Aquí se procesan los cantos ACEPTADOS. Es donde va la lógica de puntos.
# Responsabilidad: calcular quién gana el canto y sumar puntos.
# NO es responsable de elegir cartas ni de decidir acciones de la IA.
# ============================================================================

## Procesa un canto aceptado. Calcula resultados y otorga puntos.
func _handle_accepted(action: Enums.Action, _requester: Enums.Player, _responder: Enums.Player) -> void:
	match action:
		Enums.Action.FLOR, Enums.Action.CONTRAFLOR, Enums.Action.CONTRAFLOR_AL_RESTO:
			_eval_flor(action)
		Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
			_eval_envido(action)
		Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4:
			# Truco aceptado: no se calcula nada ahora.
			# Los puntos se otorgan al final de la mano según quién gane.
			# TODO: Registrar el multiplicador de puntos de la mano.
			# Truco = 2, Retruco = 3, Vale 4 = 4 puntos para el ganador de la mano.
			# Esto se debe evaluar cuando termine la ronda 3 o se agoten las cartas.
			print(IntlService.ACTION_WORDINGS[action], " aceptado")


## Evalúa y compara envido de ambos jugadores.
## TODO: Calcular puntos según la cadena de envido cantada.
## Ejemplo: Envido simple = 2 pts, Real Envido = 3 pts, Falta Envido = lo que falta.
## Los puntos van al jugador con mayor valor de envido.
func _eval_envido(action: Enums.Action) -> void:
	var p1: Dictionary = GameService.eval_envido(_get_hand_data(Enums.Player.PLAYER_1))
	var p2: Dictionary = GameService.eval_envido(_get_hand_data(Enums.Player.PLAYER_2))
	print(IntlService.ACTION_WORDINGS[action], " - P1: ", p1, " P2: ", p2)
	# TODO: Comparar p1["value"] vs p2["value"] y otorgar puntos al ganador.
	# En empate, gana el jugador que es "mano" (el que empezó la partida).


## Evalúa y compara flor de ambos jugadores.
## TODO: Calcular puntos según la cadena de flor cantada.
## Ejemplo: Flor = 3 pts, Contraflor = 6 pts, Contraflor al Resto = lo que falta.
func _eval_flor(action: Enums.Action) -> void:
	var p1: Dictionary = GameService.eval_flor(_get_hand_data(Enums.Player.PLAYER_1))
	var p2: Dictionary = GameService.eval_flor(_get_hand_data(Enums.Player.PLAYER_2))
	print(IntlService.ACTION_WORDINGS[action], " - P1: ", p1, " P2: ", p2)
	# TODO: Comparar p1["value"] vs p2["value"] y otorgar puntos al ganador.


# ============================================================================
# GESTIÓN DE RONDAS
# ============================================================================

## Avanza al siguiente turno sin evaluar ronda (el oponente aún no jugó).
func _advance_turn() -> void:
	current_player = Enums.Player.PLAYER_2 if current_player == Enums.Player.PLAYER_1 else Enums.Player.PLAYER_1
	game_state = Enums.GameState.WAITING_ACTION
	_ai_busy = false
	turn_started.emit(current_player)


## Verifica si ambos jugadores jugaron carta en la ronda actual.
func _is_round_complete() -> bool:
	return _round_cards[Enums.Player.PLAYER_1] != null and _round_cards[Enums.Player.PLAYER_2] != null


## Evalúa quién ganó la ronda y avanza el juego.
## TODO: Manejar empate (parda). En truco, el empate lo gana el jugador "mano".
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
		# TODO: Determinar ganador de la mano (mejor de 3 rondas).
		# TODO: Otorgar puntos de truco al ganador (1 pt base, o más si se cantó truco).
	
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


## Inicia la siguiente ronda. El ganador de la ronda anterior comienza.
func _start_next_round(winner: Enums.Player) -> void:
	match current_turn:
		Enums.Turn.ROUND_1: current_turn = Enums.Turn.ROUND_2
		Enums.Turn.ROUND_2: current_turn = Enums.Turn.ROUND_3
		_: current_turn = Enums.Turn.ROUND_3
	
	current_player = winner
	game_state = Enums.GameState.WAITING_ACTION
	_ai_busy = false
	_reset_round_cards()
	# NOTA: NO se resetean _action_calls aquí. Los cantos persisten toda la mano.
	
	turn_started.emit(winner)


# ============================================================================
# HELPERS
# ============================================================================

## Obtiene el slot correspondiente a un jugador y una ronda.
func _get_slot(player: Enums.Player, turn: Enums.Turn) -> CardSlot:
	var slots: Array[CardSlot] = slots_player_1 if player == Enums.Player.PLAYER_1 else slots_player_2
	var idx: int = 0
	match turn:
		Enums.Turn.ROUND_1: idx = 0
		Enums.Turn.ROUND_2: idx = 1
		Enums.Turn.ROUND_3: idx = 2
	if slots.is_empty(): return null
	return slots[idx] if idx < slots.size() else slots[0]


## Obtiene los CardData de la mano de un jugador (cartas que AÚN tiene en mano).
## Útil para evaluar envido, flor, fuerza de mano, etc.
func _get_hand_data(player: Enums.Player) -> Array[CardData]:
	var data: Array[CardData] = []
	var hand: CardHand = cards_player_1 if player == Enums.Player.PLAYER_1 else cards_player_2
	if not hand: return data
	for card: Card in hand.cards:
		if card and card.card_data:
			data.append(card.card_data as CardData)
	return data


## Resetea las cartas jugadas en la ronda actual. Se llama al inicio de cada ronda.
func _reset_round_cards() -> void:
	_round_cards[Enums.Player.PLAYER_1] = null
	_round_cards[Enums.Player.PLAYER_2] = null


## Resetea TODOS los cantos a false. Se llama SOLO al iniciar nueva partida.
func _reset_action_calls() -> void:
	for action: Enums.Action in _action_calls.keys():
		_action_calls[action] = false


## Retorna true con probabilidad `chance` (0.0 = nunca, 1.0 = siempre).
## Ejemplo: _should_act(0.7) → 70% de chance de retornar true.
func _should_act(chance: float) -> bool:
	return randf() <= chance
