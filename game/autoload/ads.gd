extends Node
## Picks the AdService implementation at boot. The MVP ships GrantAdService
## only (spec 8). Post-MVP, the free build's export preset defines an "admob"
## feature tag and this becomes:
##   service = AdmobAdService.new() if OS.has_feature("admob") else GrantAdService.new()

var service: AdService


func _init() -> void:
	service = GrantAdService.new()
