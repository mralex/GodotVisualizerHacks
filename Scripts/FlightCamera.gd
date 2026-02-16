extends Camera3D

@export var base_speed: float = 0.5
@export var max_speed: float = 4.0
@export var speed_smoothing: float = 3.0
@export var sway_amount: float = 0.3
@export var roll_amount: float = 0.02

var current_speed: float = 0.5
var total_distance: float = 0.0
var target_speed: float = 0.5

func set_target_speed(bass_energy: float) -> void:
	target_speed = lerpf(base_speed, max_speed, clampf(bass_energy, 0.0, 1.0))

func _process(delta: float) -> void:
	# Smooth speed transitions
	current_speed = lerpf(current_speed, target_speed, speed_smoothing * delta)
	total_distance += current_speed * delta

	# Gentle sinusoidal sway on X/Y for organic feel
	var sway_time = total_distance * 0.05
	var sway_x = sin(sway_time * 0.7) * sway_amount
	var sway_y = sin(sway_time * 0.5 + 1.3) * sway_amount * 0.6
	position.x = sway_x
	position.y = sway_y

	# Subtle roll
	var roll = sin(sway_time * 0.3 + 0.7) * roll_amount
	rotation.z = roll

	# Always look forward along -Z
	rotation.x = 0.0
	rotation.y = 0.0
