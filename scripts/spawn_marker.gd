extends Marker2D

@export var spawn_id: String = "default"


func _ready() -> void:
	add_to_group("spawn_marker")
