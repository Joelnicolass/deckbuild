extends Sprite2D

# Ángulo de rotación en radianes (90 grados)
const ROTATION_ANGLE = deg_to_rad(90)
# Duración de la animación en segundos
const ROTATION_DURATION = 0.5

func _input(event):
	# Detecta cuando se presiona cualquier tecla
	if event is InputEventKey and event.pressed:
		# Crea un Tween para animar la rotación de forma suave
		var tween = create_tween()
		var target_rotation = rotation + ROTATION_ANGLE
		tween.tween_property(self, "rotation", target_rotation, ROTATION_DURATION)
