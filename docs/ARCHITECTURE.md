# Arquitectura — Truco Argentino

## Índice

1. [Visión general](#visión-general)
2. [Archivos y responsabilidades](#archivos-y-responsabilidades)
3. [Máquina de estados](#máquina-de-estados)
4. [Diagrama de señales](#diagrama-de-señales)
5. [Flujo completo de un turno](#flujo-completo-de-un-turno)
6. [Flujo de cantos (acciones)](#flujo-de-cantos-acciones)
7. [Reglas de negocio](#reglas-de-negocio)
8. [Inteligencia Artificial](#inteligencia-artificial)
9. [Dónde agregar lógica](#dónde-agregar-lógica)
10. [Ejemplos de flujo completo](#ejemplos-de-flujo-completo)

---

## Visión general

El juego se estructura en 3 capas:

```
┌─────────────────────────────────────────────────┐
│  main.gd (UI / Presentación)                    │
│  - Conecta señales                              │
│  - Habilita/deshabilita drag & drop             │
│  - Dispara acciones de la IA                    │
│  - Animaciones de cartas                        │
├─────────────────────────────────────────────────┤
│  game_manager_service.gd (Lógica de flujo)      │
│  - Máquina de estados                           │
│  - Gestión de turnos y rondas                   │
│  - Validación de cantos                         │
│  - Lógica de la IA                              │
│  - Emisión de señales                           │
├─────────────────────────────────────────────────┤
│  game_service.gd (Lógica de dominio)            │
│  - eval_power_cards() → quién gana la ronda     │
│  - eval_envido() → valor de envido              │
│  - eval_flor() → valor de flor                  │
│  - eval_truco() → poder de carta                │
├─────────────────────────────────────────────────┤
│  deck_service.gd / card_data.gd (Datos)         │
│  - Creación del mazo                            │
│  - Reparto de cartas                            │
│  - Modelo de datos de carta                     │
└─────────────────────────────────────────────────┘
```

La comunicación entre capas es **unidireccional por señales**:
- `main.gd` **escucha** señales de `game_manager_service.gd`
- `main.gd` **llama** funciones públicas de `game_manager_service.gd`
- `game_manager_service.gd` **llama** funciones de `game_service.gd` para evaluar jugadas

---

## Archivos y responsabilidades

| Archivo | Responsabilidad |
|---|---|
| `main.gd` | UI: drag & drop, botones, animaciones, conectar señales |
| `game_manager_service.gd` | Flujo del juego: turnos, rondas, cantos, IA |
| `game_service.gd` | Evaluación pura: poder de cartas, envido, flor |
| `deck_service.gd` | Creación y reparto del mazo |
| `enums.gd` | Enums: Action, Player, Turn, GameState |
| `intl_service.gd` | Textos internacionalizados de acciones |
| `card_data.gd` | Resource: datos de una carta (palo, valor) |

---

## Máquina de estados

```
                    ┌──────────────┐
         start_game │              │
        ───────────►│WAITING_ACTION│◄─────────────────────┐
                    │              │                       │
                    └──┬───────┬───┘                       │
                       │       │                           │
              canta    │       │  tira carta               │
                       ▼       ▼                           │
            ┌─────────────┐  ┌──────────┐                  │
            │  WAITING_    │  │ ¿Ronda   │                  │
            │  RESPONSE    │  │completa? │                  │
            └──┬──┬──┬─────┘  └──┬────┬──┘                  │
               │  │  │           │    │                     │
    acepta/    │  │  │ sube    No│    │Sí                   │
    rechaza    │  │  │ apuesta   │    │                     │
               │  │  │           │    ▼                     │
               │  │  │           │ ┌──────────┐             │
               │  │  └───────────┤ │_evaluate │             │
               │  │              │ │ _round() │             │
               ▼  │              │ └────┬─────┘             │
        ┌──────────┐             │      │                   │
        │PLAYING_  │             │      ▼                   │
        │CARD      │             │  ┌──────────┐            │
        └────┬─────┘             │  │¿Ronda 3? │            │
             │                   │  └──┬────┬──┘            │
             │ tira carta        │   No│    │Sí             │
             │                   │     │    ▼               │
             │                   │     │ ┌──────────┐       │
             │                   │     │ │GAME_OVER │       │
             │                   │     │ └──────────┘       │
             │                   │     │                    │
             └───────────────────┘     └────────────────────┘
                _advance_turn()          _start_next_round()
```

### Estados

| Estado | Significado | Acciones permitidas |
|---|---|---|
| `WAITING_ACTION` | Turno activo del jugador | Cantar o tirar carta |
| `WAITING_RESPONSE` | Canto pendiente | Solo responder (aceptar, rechazar, subir) |
| `PLAYING_CARD` | Post-canto resuelto | Solo tirar carta |
| `GAME_OVER` | Juego terminado | Ninguna |

---

## Diagrama de señales

```
game_manager_service.gd                          main.gd
═══════════════════════                          ═══════

turn_started(player) ──────────────────────────► _on_turn_started()
                                                   │
                                                   ├─ P1: habilitar drag
                                                   └─ P2: llamar ai_turn()

must_play_card(player) ────────────────────────► _on_must_play_card()
                                                   │
                                                   ├─ P1: habilitar drag (sin cantos)
                                                   └─ P2: llamar ai_play_card()

action_requested(action, requester) ───────────► _on_action_requested()
                                                   │
                                                   ├─ P1 cantó: llamar ai_respond_to_action()
                                                   └─ P2 cantó: mostrar botones aceptar/rechazar

action_resolved(action, accepted, requester) ──► (informativa, para UI futura)

card_played(card, player) ─────────────────────► (informativa, para animaciones futuras)

round_result(result) ──────────────────────────► _on_round_result()
                                                   └─ Animar cartas ganadoras/perdedoras

game_started(player) ──────────────────────────► (informativa, turn_started se emite después)
```

### Flujo de llamadas UI → GameManager

```
main.gd                                          game_manager_service.gd
═══════                                          ═══════════════════════

Botón Truco ──────► request_action(TRUCO, P1) ──► valida → emite action_requested
Botón Envido ─────► request_action(ENVIDO, P1) ─► valida → emite action_requested
Botón Aceptar ────► respond_to_action(true, P1) ► procesa → emite must_play_card
Botón Rechazar ───► respond_to_action(false, P1)► procesa → emite must_play_card o GAME_OVER
Drag & drop ──────► play_card(card, P1) ─────────► coloca → emite card_played → avanza
```

---

## Flujo completo de un turno

### Turno sin canto

```
turn_started(P1)
  → main.gd habilita drag
  → P1 arrastra carta al slot
  → play_card(card, P1)
    → coloca carta en slot
    → card_played emitido
    → ¿Ronda completa? No → _advance_turn()
      → turn_started(P2) emitido
        → main.gd llama ai_turn()
          → IA decide no cantar
          → _do_ai_play_card()
            → play_card(card, P2)
              → ¿Ronda completa? Sí → _evaluate_round()
                → round_result emitido (animación)
                → _start_next_round(ganador)
                  → turn_started(ganador) emitido
```

### Turno con canto

```
turn_started(P1)
  → main.gd habilita drag + botones de canto
  → P1 presiona botón "Envido"
  → request_action(ENVIDO, P1)
    → valida → game_state = WAITING_RESPONSE
    → action_requested(ENVIDO, P1) emitido
      → main.gd detecta requester == P1
      → llama ai_respond_to_action()
        → IA decide aceptar
        → respond_to_action(true, P2)
          → _handle_accepted() evalúa envido
          → action_resolved emitido
          → game_state = PLAYING_CARD
          → must_play_card(P1) emitido
            → main.gd habilita drag (solo carta, sin cantos)
            → P1 arrastra carta
            → play_card(card, P1) ...
```

---

## Flujo de cantos (acciones)

### Tipos de respuesta a un canto

```
Canto pendiente ──► Respuesta del oponente
                    │
                    ├─ Aceptar ────────► Canto se resuelve → PLAYING_CARD
                    │                    (evalúa envido/flor, o sube valor de truco)
                    │
                    ├─ Rechazar ───────► Envido/Flor: continúa → PLAYING_CARD
                    │                    Truco/Retruco/Vale4: pierde → GAME_OVER
                    │
                    ├─ Subir apuesta ──► Acepta implícitamente el canto actual
                    │                    Nuevo canto pendiente (roles invertidos)
                    │                    → sigue WAITING_RESPONSE
                    │
                    └─ Anular ─────────► Solo truco→envido en ronda 1
                       (regla especial)  Cancela truco, abre envido
                                         → sigue WAITING_RESPONSE
```

### Cadenas válidas de escalada

```
ENVIDO ──────► REAL ENVIDO ──────► FALTA ENVIDO
  │                                     ▲
  └─────────────────────────────────────┘
              (salto directo válido)

TRUCO ───────► RETRUCO ──────────► VALE 4

FLOR ────────► CONTRAFLOR ───────► CONTRAFLOR AL RESTO
```

### Regla especial: Truco → Envido

```
P1 canta TRUCO
  └─► P2 responde con ENVIDO (solo ronda 1, si no se cantó envido)
       └─► Truco se ANULA (se puede cantar de nuevo)
           Envido se abre como nuevo canto
           P1 debe responder al envido
```

---

## Reglas de negocio

Toda la lógica de reglas está en **3 funciones** dentro de `game_manager_service.gd`:

### 1. `_is_action_valid(action)` — ¿Se puede cantar esto?

Controla las **precondiciones** para cantar cada acción desde cero.

```
ENVIDO / REAL ENVIDO / FALTA ENVIDO / FLOR
  → Solo ronda 1, antes de que el jugador que canta tire su primera carta
  → Es por jugador: si P1 ya tiró pero P2 no, P2 aún puede cantar
  → No repetir si ya se cantó

CONTRAFLOR → Solo si FLOR fue cantada
CONTRAFLOR AL RESTO → Solo si CONTRAFLOR fue cantada

TRUCO → En cualquier momento, si no se cantó antes
RETRUCO → Solo si TRUCO fue cantado
VALE 4 → Solo si RETRUCO fue cantado
```

**Modificar aquí para**: cambiar cuándo se puede cantar algo.

### 2. `_is_valid_raise(current, raise)` — ¿Se puede subir a esto?

Define las **cadenas de escalada** válidas.

**Modificar aquí para**: agregar/cambiar cadenas de subida.

### 3. `_can_respond_truco_with_envido()` — ¿Se puede anular truco con envido?

Condiciones para la regla especial.

**Modificar aquí para**: cambiar las condiciones de la anulación.

---

## Inteligencia Artificial

La IA tiene **4 puntos de decisión** independientes:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DECISIONES DE LA IA                          │
├────────────────────┬────────────────────────┬───────────────────┤
│ Momento            │ Función                │ Retorna           │
├────────────────────┼────────────────────────┼───────────────────┤
│ Es mi turno,       │ _decide_ai_action()    │ Enums.Action      │
│ ¿canto algo?       │                        │ (o NONE)          │
├────────────────────┼────────────────────────┼───────────────────┤
│ Me cantaron algo,  │ _decide_ai_response()  │ bool              │
│ ¿acepto?           │                        │ (true/false)      │
├────────────────────┼────────────────────────┼───────────────────┤
│ Me cantaron algo,  │ (lógica en             │ Enums.Action      │
│ ¿subo la apuesta?  │ ai_respond_to_action)  │ (alternative)     │
├────────────────────┼────────────────────────┼───────────────────┤
│ Debo tirar carta,  │ _do_ai_play_card()     │ Card              │
│ ¿cuál elijo?       │                        │                   │
└────────────────────┴────────────────────────┴───────────────────┘
```

### Flujo de decisión de la IA

```
ai_turn() [turn_started → WAITING_ACTION]
  │
  ├─► _decide_ai_action() → ¿cantar?
  │     ├─ Sí → request_action() → esperar respuesta
  │     └─ No ↓
  │
  └─► _do_ai_play_card() → tirar carta

ai_play_card() [must_play_card → PLAYING_CARD]
  │
  └─► _do_ai_play_card() → tirar carta (obligatorio)

ai_respond_to_action() [action_requested → WAITING_RESPONSE]
  │
  ├─► ¿Subir apuesta? → respond_to_action(_, P2, RAISE)
  │
  └─► _decide_ai_response() → aceptar o rechazar
        └─► respond_to_action(accepted, P2)
```

---

## Dónde agregar lógica

### Nuevos cantos del usuario (UI)

**Archivo**: `main.gd`
**Patrón**: crear función `_on_X_pressed()` conectada a un botón.

```gdscript
# Ejemplo: botón de Envido
func _on_envido_pressed() -> void:
    if GameManagerService.current_player != Enums.Player.PLAYER_1:
        return
    GameManagerService.request_action(Enums.Action.ENVIDO, Enums.Player.PLAYER_1)
```

No se necesita tocar `game_manager_service.gd` — las validaciones ya están.

### Subir apuesta desde UI

**Archivo**: `main.gd`
**Patrón**: botón que llama `respond_to_action` con `alternative`.

```gdscript
# Ejemplo: botón "Quiero Retruco" (visible cuando te cantan Truco)
func _on_retruco_pressed() -> void:
    GameManagerService.respond_to_action(false, Enums.Player.PLAYER_1, Enums.Action.RETRUCO)
```

### IA más inteligente — Cantar

**Archivo**: `game_manager_service.gd`
**Función**: `_decide_ai_action() → Enums.Action`

```gdscript
# Evalúa sus cartas y decide si cantar. Retorna NONE para no cantar.
func _decide_ai_action() -> Enums.Action:
    # Ejemplo: cantar envido solo si tiene 27+
    if _can_call_envido_flor():
        var cards = _get_hand_data(Enums.Player.PLAYER_2)
        var envido = GameService.eval_envido(cards)
        if envido["valid"] and envido["value"] >= 27:
            return Enums.Action.ENVIDO
    return Enums.Action.NONE
```

### IA más inteligente — Aceptar/rechazar

**Archivo**: `game_manager_service.gd`
**Función**: `_decide_ai_response(action) → bool`

```gdscript
# Evalúa si acepta o rechaza según la acción y sus cartas.
func _decide_ai_response(action: Enums.Action) -> bool:
    match action:
        Enums.Action.ENVIDO:
            var cards = _get_hand_data(Enums.Player.PLAYER_2)
            return GameService.eval_envido(cards)["value"] >= 25
        Enums.Action.TRUCO:
            return randf() > 0.3  # 70% de aceptar
        _:
            return true
```

### IA más inteligente — Subir apuesta

**Archivo**: `game_manager_service.gd`
**Función**: `ai_respond_to_action()` — agregar lógica antes de aceptar/rechazar.

```gdscript
# Dentro de ai_respond_to_action(), antes de la respuesta normal:
var raise = _decide_ai_raise(_pending_action)
if raise != Enums.Action.NONE:
    respond_to_action(false, Enums.Player.PLAYER_2, raise)
    return
```

### IA más inteligente — Elegir carta

**Archivo**: `game_manager_service.gd`
**Función**: `_do_ai_play_card()`

```gdscript
# Reemplazar pick_random() con lógica de selección.
func _do_ai_play_card() -> void:
    var best_card: Card = _choose_best_card()
    play_card(best_card, Enums.Player.PLAYER_2)
    _ai_busy = false

func _choose_best_card() -> Card:
    # Evaluar qué carta jugar según:
    # - Carta del oponente en el slot actual (si ya jugó)
    # - Cartas restantes en mano
    # - Ronda actual
    return cards_player_2.cards.pick_random()  # placeholder
```

### Nuevas reglas de negocio

**Archivo**: `game_manager_service.gd`

| Quiero... | Modifico... |
|---|---|
| Cambiar cuándo se puede cantar algo | `_is_action_valid()` |
| Agregar/cambiar cadenas de subida | `_is_valid_raise()` |
| Cambiar condiciones de truco→envido | `_can_respond_truco_with_envido()` |
| Agregar nueva regla de anulación | Nuevo `_try_respond_X_with_Y()` en `respond_to_action()` |
| Cambiar cuándo envido/flor es válido | `_can_call_envido_flor()` |

### Cálculo de puntos

**Archivo**: `game_manager_service.gd`
**Función**: `_handle_accepted(action, requester, responder)`

```gdscript
# Aquí se procesan los cantos aceptados.
# Actualmente solo imprime. Agregar lógica de puntos aquí.
func _handle_accepted(action, _requester, _responder):
    match action:
        Enums.Action.ENVIDO, Enums.Action.REAL_ENVIDO, Enums.Action.FALTA_ENVIDO:
            _eval_envido(action)
            # TODO: calcular puntos según _action_calls (toda la cadena)
            # TODO: sumar puntos al ganador
        Enums.Action.TRUCO, Enums.Action.RETRUCO, Enums.Action.VALE_4:
            # TODO: registrar multiplicador de mano
            # (los puntos se otorgan al final de la mano)
```

### Animaciones y feedback visual

**Archivo**: `main.gd`
**Señales disponibles**:

| Señal | Uso para animación |
|---|---|
| `action_requested` | Mostrar texto "¡ENVIDO!" con animación |
| `action_resolved` | Mostrar resultado "Aceptado" / "No quiero" |
| `must_play_card` | Highlight de la zona de juego |
| `card_played` | Animación de carta jugada |
| `round_result` | Animación de carta ganadora/perdedora (ya implementada) |

---

## Ejemplos de flujo completo

### Ejemplo A: Envido → Real Envido → Acepta

```
RONDA 1, turno P1

1. turn_started(P1) → main.gd habilita drag + botones
2. P1 presiona "Envido"
3. request_action(ENVIDO, P1) → válido
4. game_state = WAITING_RESPONSE
5. action_requested(ENVIDO, P1) → main.gd → ai_respond_to_action()
6. IA decide subir → respond_to_action(_, P2, REAL_ENVIDO)
7. _try_raise_action(ENVIDO, REAL_ENVIDO, P2) → válido
8. action_requested(REAL_ENVIDO, P2) → main.gd muestra aceptar/rechazar
9. P1 presiona "Aceptar"
10. respond_to_action(true, P1)
11. _handle_accepted(REAL_ENVIDO) → evalúa envido
12. action_resolved(REAL_ENVIDO, true, P2)
13. game_state = PLAYING_CARD
14. must_play_card(P1) → main.gd habilita drag
15. P1 tira carta → play_card(card, P1)
16. _advance_turn() → turn_started(P2)
17. ai_turn() → IA tira carta
18. Ronda completa → _evaluate_round() → round_result
```

### Ejemplo B: Truco → Envido (anulación) → Acepta

```
RONDA 1, turno P1

1. turn_started(P1) → habilita drag + botones
2. P1 presiona "Truco"
3. request_action(TRUCO, P1) → válido
4. action_requested(TRUCO, P1) → ai_respond_to_action()
5. IA decide responder con Envido
   → respond_to_action(_, P2, ENVIDO)
6. _try_respond_truco_with_envido(ENVIDO, P2) → válido
7. Truco ANULADO (_action_calls[TRUCO] = false)
8. action_requested(ENVIDO, P2) → main.gd muestra aceptar/rechazar
9. P1 presiona "Aceptar"
10. respond_to_action(true, P1)
11. _handle_accepted(ENVIDO) → evalúa envido
12. game_state = PLAYING_CARD
13. must_play_card(P1) → P1 tira carta
14. (Truco puede cantarse de nuevo porque fue anulado)
```

### Ejemplo C: Truco rechazado

```
RONDA 2, turno P2 (IA)

1. turn_started(P2) → ai_turn()
2. IA decide cantar Truco
3. request_action(TRUCO, P2) → válido
4. action_requested(TRUCO, P2) → main.gd muestra aceptar/rechazar
5. P1 presiona "Rechazar"
6. respond_to_action(false, P1)
7. action_resolved(TRUCO, false, P2)
8. game_state = GAME_OVER (P1 pierde la mano)
```
