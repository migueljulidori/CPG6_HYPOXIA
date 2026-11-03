extends Node2D
## Pedras assadas; visiveis pelo shader de visao (sem alpha por tile).

func _ready() -> void:
	z_index = -95
