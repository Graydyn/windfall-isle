class_name GrantAdService
extends AdService
## Every placement is available and grants instantly. Used by the MVP (spec 8:
## "AdService stubbed") and permanently by the Play Pass build (spec 6).


func is_available(_placement: Placement) -> bool:
	return true


func request_reward(_placement: Placement, on_granted: Callable) -> void:
	on_granted.call()
