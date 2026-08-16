class_name DailyCrate
## Daily salvage crate (spec 5): calendar-day based, no punishing streaks.

const SECONDS_PER_DAY := 86400


static func day_of(now: int) -> int:
	@warning_ignore("integer_division")
	return now / SECONDS_PER_DAY


static func can_claim(data: Dictionary, now: int) -> bool:
	return day_of(now) > int((data.get("daily_crate", {}) as Dictionary).get("last_claim_day", 0))


static func claim(data: Dictionary, retention_defs: Dictionary, now: int) -> Dictionary:
	if not can_claim(data, now):
		return {}
	(data.get("daily_crate", {}) as Dictionary)["last_claim_day"] = day_of(now)
	return (retention_defs.get("daily_crate", {}) as Dictionary).duplicate()
