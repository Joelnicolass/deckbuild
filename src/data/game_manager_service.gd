extends Node

# ============================================================================
# ENUMS
# ============================================================================

enum Player {
	PLAYER_1,
	PLAYER_2
}

enum Turn {
	ROUND_1,
	ROUND_2,
	ROUND_3
}

enum GameState {
	WAITING_ACTION,
	WAITING_RESPONSE,
	PLAYING_CARD,
	EVALUATING_ROUND,
	GAME_OVER,
}

const GAME_STATE_WORDINGS: Dictionary = {
	GameState.WAITING_ACTION: "Esperando acción",
	GameState.WAITING_RESPONSE: "Esperando respuesta",
	GameState.PLAYING_CARD: "Jugando carta",
	GameState.EVALUATING_ROUND: "Evaluando ronda",
	GameState.GAME_OVER: "Partida terminada",
}

const TURN_WORDINGS: Dictionary = {
	Turn.ROUND_1: "Mano 1",
	Turn.ROUND_2: "Mano 2",
	Turn.ROUND_3: "Mano 3",
}

const ACTION_WORDINGS: Dictionary = {
	Enums.Action.FLOR: "Flor",
	Enums.Action.ENVIDO: "Envido",
	Enums.Action.TRUCO: "Truco",
	Enums.Action.RETRUCO: "Retruco",
	Enums.Action.VALE_4: "Vale 4",
	Enums.Action.ACEPTAR: "Aceptar",
	Enums.Action.RECHAZAR: "Rechazar",
}

const PLAYER_WORDINGS: Dictionary = {
	Player.PLAYER_1: "Jugador 1",
	Player.PLAYER_2: "Jugador 2",
}

# ============================================================================
# SIGNALS
# ============================================================================

signal game_started(initial_player: Player)
signal card_played(card: Card, player: Player)
signal round_ended(winner: Player)
signal round_started(round: Turn, starting_player: Player)
signal turn_changed(new_player: Player)
signal round_result(result: Dictionary)

# ============================================================================
# STATE VARIABLES
# ============================================================================

var initial_player: Player
var current_turn: Turn = Turn.ROUND_1
var current_player: Player
var game_state: GameState = GameState.WAITING_ACTION

var cards_player_1: CardHand
var cards_player_2: CardHand
var slots_player_1: Array[CardSlot] = []
var slots_player_2: Array[CardSlot] = []

var cards_played_p1: int = 0
var cards_played_p2: int = 0

# Ronda actual: guarda las cartas jugadas por cada jugador
var current_round_cards: Dictionary = {
	Player.PLAYER_1: null,
	Player.PLAYER_2: null
}

# Control para evitar múltiples llamadas a ai_request
var _ai_request_in_progress: bool = false

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
	initial_player = Player.PLAYER_2 if randf() < 0.5 else Player.PLAYER_2
	current_player = initial_player
	current_turn = Turn.ROUND_1
	_reset_round_cards()

	game_started.emit(initial_player)
	round_started.emit(current_turn, initial_player)
	

func play_card(card: Card, player: Player) -> void:
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
	if _ai_request_in_progress: return
	if current_player != Player.PLAYER_2: return
	if cards_player_2.cards.is_empty(): return
	if game_state == GameState.GAME_OVER: return

	_ai_request_in_progress = true
	
	await get_tree().create_timer(1.0).timeout
	
	if current_player != Player.PLAYER_2:
		_ai_request_in_progress = false
		return

	if cards_player_2.cards.is_empty():
		_ai_request_in_progress = false
		return

	if game_state == GameState.GAME_OVER:
		_ai_request_in_progress = false
		return
	
	var random_card: Card = cards_player_2.cards.pick_random()
	play_card(random_card, Player.PLAYER_2)
	
	_ai_request_in_progress = false


# ============================================================================
# ROUND MANAGEMENT
# ============================================================================

func _on_card_played(card: Card, player: Player) -> void:
	current_round_cards[player] = card
	
	_switch_to_next_player()
	if _is_round_complete(): _evaluate_and_end_round()


func _switch_to_next_player() -> void:
	current_player = Player.PLAYER_2 if current_player == Player.PLAYER_1 else Player.PLAYER_1
	_ai_request_in_progress = false # Resetear flag cuando cambia el turno
	turn_changed.emit(current_player)


func _is_round_complete() -> bool:
	return current_round_cards[Player.PLAYER_1] != null and current_round_cards[Player.PLAYER_2] != null


func _evaluate_and_end_round() -> void:
	# Obtener las cartas directamente de los slots para asegurar que son las jugadas
	var slot_p1: CardSlot = _get_player_slot(Player.PLAYER_1, current_turn)
	var slot_p2: CardSlot = _get_player_slot(Player.PLAYER_2, current_turn)
	
	if not slot_p1 or not slot_p2: return
	
	var card_p1: Card = slot_p1.get_card()
	var card_p2: Card = slot_p2.get_card()
	
	if not card_p1 or not card_p2: return
	
	var evaluation: Dictionary = GameService.eval_power_cards(card_p1.card_data as CardData, card_p2.card_data as CardData)
	
	var winner: Player = Player.PLAYER_1 # TODO -> mano gana
	var winner_card: CardData = evaluation["winner"]

	if winner_card == card_p1.card_data: winner = Player.PLAYER_1
	else: winner = Player.PLAYER_2

	if current_turn < Turn.ROUND_3: _start_next_round(winner)
	else: game_state = GameState.GAME_OVER

	
	round_ended.emit(winner)
	
	round_result.emit({
		"winner": {
			"player": winner,
			"card": card_p1 if winner == Player.PLAYER_1 else card_p2,
		},
		"loser": {
			"player": Player.PLAYER_1 if winner == Player.PLAYER_2 else Player.PLAYER_2,
			"card": card_p1 if winner == Player.PLAYER_2 else card_p2,
		},
	})


func _start_next_round(round_winner: Player) -> void:
	var next_round: Turn
	match current_turn:
		Turn.ROUND_1:
			next_round = Turn.ROUND_2
		Turn.ROUND_2:
			next_round = Turn.ROUND_3
		_:
			next_round = Turn.ROUND_3
	
	current_turn = next_round
	current_player = round_winner
	_ai_request_in_progress = false # Resetear flag cuando inicia nueva ronda
	
	_reset_round_cards()
	
	round_started.emit(current_turn, round_winner)
	turn_changed.emit(round_winner)


func _reset_round_cards() -> void:
	current_round_cards[Player.PLAYER_1] = null
	current_round_cards[Player.PLAYER_2] = null


# ============================================================================
# PRIVATE METHODS
# ============================================================================


func _get_player_slot(player: Player, turn: Turn) -> CardSlot:
	var slots: Array[CardSlot]

	if player == Player.PLAYER_1: slots = slots_player_1
	else: slots = slots_player_2
		
	var index: int = 0
	
	match turn:
		Turn.ROUND_1: index = 0
		Turn.ROUND_2: index = 1
		Turn.ROUND_3: index = 2
	
	if slots.is_empty(): return null
	if index < slots.size(): return slots[index]
	return slots[0]
