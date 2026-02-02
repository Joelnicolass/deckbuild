# card_data.gd
class_name CardData extends CardResource

enum CardSuit {
    ESPADA,
    BASTO,
    ORO,
    COPA,
}

enum CardValue {
    UNO,
    DOS,
    TRES,
    CUATRO,
    CINCO,
    SEIS,
    SIETE,
    DIEZ,
    ONCE,
    DOCE,
}

@export var card_suit: CardSuit
@export var card_value: CardValue
@export var card_image: Texture2D