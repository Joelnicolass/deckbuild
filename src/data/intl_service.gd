extends Node


var WORDINGS_ACTION: Dictionary = {
	Enums.Action.NONE: "",
	Enums.Action.FLOR: "Flor",
	Enums.Action.ENVIDO: "Envido",
	Enums.Action.TRUCO: "Truco",
	Enums.Action.RETRUCO: "Retruco",
	Enums.Action.VALE_4: "Vale 4",
}

var WORDINGS_SUIT: Dictionary = {
	CardData.CardSuit.ESPADA: "Espada",
	CardData.CardSuit.BASTO: "Basto",
	CardData.CardSuit.ORO: "Oro",
	CardData.CardSuit.COPA: "Copas",
}

var WORDINGS_VALUE: Dictionary = {
	CardData.CardValue.UNO: "Uno",
	CardData.CardValue.DOS: "Dos",
	CardData.CardValue.TRES: "Tres",
	CardData.CardValue.CUATRO: "Cuatro",
	CardData.CardValue.CINCO: "Cinco",
	CardData.CardValue.SEIS: "Seis",
	CardData.CardValue.SIETE: "Siete",
	CardData.CardValue.DIEZ: "Diez",
	CardData.CardValue.ONCE: "Once",
	CardData.CardValue.DOCE: "Doce",
}

# Términos del Truco Argentino
var WORDINGS_TRUCO_TERMS: Dictionary = {
	"ancho_falso": "Ancho falso",
	"buenas": "Buenas",
	"figura": "Figura",
	"negra": "Negra",
	"hembra": "Hembra",
	"ir_al_pie": "Ir al pie",
	"irse_al_mazo": "Irse al mazo",
	"macho": "Macho",
	"malas": "Malas",
	"mano": "Mano",
	"matar": "Matar",
	"parda": "Parda",
	"pasar": "Pasar",
	"pie": "Pie",
	"pie_total": "Pie total",
	"poner": "Poner",
	"siete_bravo": "Siete bravo",
	"siete_falso": "Siete falso",
	"tantos": "Tantos",
	"viejas": "Viejas",
}

var WORDINGS_TRUCO_DESCRIPTIONS: Dictionary = {
	"ancho_falso": "Son el uno de oros y el uno de copas.",
	"buenas": "Son los últimos 15 puntos (la segunda mitad de la partida), se considera que se entra en las \"buenas\" cuando el equipo que va ganando alcanza los 16 puntos.",
	"figura": "Son las cartas 10, 11 y 12 de cualquier palo.",
	"negra": "Son las cartas 10, 11 y 12 de cualquier palo.",
	"hembra": "Es el as de bastos.",
	"ir_al_pie": "Es cuando se juega una carta de bajo valor esperando que el pie del equipo juegue la carta de más valor para ganar la ronda del Truco.",
	"irse_al_mazo": "Apoyar las cartas en el mazo general de cartas, abandonando la ronda correspondiente.",
	"macho": "Es el as de espadas.",
	"malas": "Son los primeros 15 puntos.",
	"mano": "Es el primer jugador a la derecha del repartidor.",
	"matar": "Jugar una carta de mayor valor que otra en el Truco.",
	"parda": "Es cuando se juegan dos cartas del mismo valor y quedan empatadas o \"empardadas\".",
	"pasar": "No cantar el tanto del Envido, dejando la responsabilidad del Envido al resto de los compañeros del equipo.",
	"pie": "Es el último jugador de cada equipo.",
	"pie_total": "Es el repartidor.",
	"poner": "Jugar una carta de mucho valor para el Truco y que representa la mejor del equipo en esa ronda.",
	"siete_bravo": "Es el siete de espadas.",
	"siete_falso": "Son el siete de bastos y el siete de copas.",
	"tantos": "Son los puntos que se tiene para el Envido.",
	"viejas": "Es cuando se tiene 27 puntos para el Envido.",
}


func get_card_name(card: CardData) -> String:
	var value_name: String = IntlService.WORDINGS_VALUE.get(card.card_value, "Desconocido")
	var suit_name: String = IntlService.WORDINGS_SUIT.get(card.card_suit, "Desconocido")
	return value_name + " de " + suit_name


func get_card_special_name(card: CardData) -> String:
	# Macho: 1 de espadas
	if card.card_value == CardData.CardValue.UNO and card.card_suit == CardData.CardSuit.ESPADA:
		return IntlService.WORDINGS_TRUCO_TERMS["macho"]
	# Hembra: 1 de bastos
	if card.card_value == CardData.CardValue.UNO and card.card_suit == CardData.CardSuit.BASTO:
		return IntlService.WORDINGS_TRUCO_TERMS["hembra"]
	# Siete bravo: 7 de espadas
	if card.card_value == CardData.CardValue.SIETE and card.card_suit == CardData.CardSuit.ESPADA:
		return IntlService.WORDINGS_TRUCO_TERMS["siete_bravo"]
	# Siete falso: 7 de bastos o copas
	if card.card_value == CardData.CardValue.SIETE and (card.card_suit == CardData.CardSuit.BASTO or card.card_suit == CardData.CardSuit.COPA):
		return IntlService.WORDINGS_TRUCO_TERMS["siete_falso"]
	# Ancho falso: 1 de oros o copas
	if card.card_value == CardData.CardValue.UNO and (card.card_suit == CardData.CardSuit.ORO or card.card_suit == CardData.CardSuit.COPA):
		return IntlService.WORDINGS_TRUCO_TERMS["ancho_falso"]
	# Figura/Negra: 10, 11, 12
	if card.card_value == CardData.CardValue.DIEZ or card.card_value == CardData.CardValue.ONCE or card.card_value == CardData.CardValue.DOCE:
		return IntlService.WORDINGS_TRUCO_TERMS["figura"]
	
	return ""


func format_card_info(card: CardData) -> String:
	var card_name: String = get_card_name(card)
	var special_name: String = get_card_special_name(card)
	
	if special_name != "":
		return card_name + " (" + special_name + ")"
	return card_name
