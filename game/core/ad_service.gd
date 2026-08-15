class_name AdService
extends RefCounted
## The single seam all ad interactions go through (spec 6). Implementations:
## GrantAdService (MVP and Play Pass builds) auto-grants every reward;
## AdmobAdService (post-MVP, free build only) shows real rewarded video.
## Game code must only ever talk to Ads.service, never to an implementation.

enum Placement { TIMER_SKIP, FUEL_REFILL, PAYOUT_DOUBLE, BONUS_CRATE }


func is_available(_placement: Placement) -> bool:
	return false


func request_reward(_placement: Placement, _on_granted: Callable) -> void:
	pass
