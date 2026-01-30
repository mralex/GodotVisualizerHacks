extends Camera3D

## Camera that orbits around the scene center

@export var orbit_speed: float = 0.3
@export var orbit_radius: float = 6.0
@export var orbit_height: float = 3.0
@export var look_at_offset: Vector3 = Vector3(0, 0, 0)

var angle: float = 0.0

func _process(delta: float) -> void:
	angle += orbit_speed * delta

	position.x = cos(angle) * orbit_radius
	position.z = sin(angle) * orbit_radius
	position.y = orbit_height + sin(angle * 0.5) * 0.5

	look_at(look_at_offset)
