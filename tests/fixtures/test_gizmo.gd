extends GizmoBase
## Framework test double: records what setup gave it.

var configured := false


func _configure() -> void:
	configured = true
