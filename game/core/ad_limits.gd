class_name AdLimits
## Per-calendar-day caps for rewarded-ad placements (spec 6: fuel refills are
## "limited per day"; the bonus crate is daily). Counts live in save.ads and
## reset lazily when DailyCrate.day_of rolls over; no midnight process exists.


static func _ads(data: Dictionary, now: int) -> Dictionary:
	if not data.has("ads"):
		data["ads"] = {}
	var ads: Dictionary = data["ads"]
	var today := DailyCrate.day_of(now)
	if int(ads.get("day", -1)) != today:
		ads["day"] = today
		ads["counts"] = {}
	if not ads.has("counts"):
		ads["counts"] = {}
	return ads


static func used(data: Dictionary, placement: String, now: int) -> int:
	return int((_ads(data, now)["counts"] as Dictionary).get(placement, 0))


static func can_use(data: Dictionary, placement: String, limit: int, now: int) -> bool:
	return used(data, placement, now) < limit


static func use(data: Dictionary, placement: String, limit: int, now: int) -> bool:
	# Call this at GRANT time, not request time: a dismissed rewarded ad must
	# never burn the daily limit.
	if not can_use(data, placement, limit, now):
		return false
	var counts: Dictionary = _ads(data, now)["counts"]
	counts[placement] = int(counts.get(placement, 0)) + 1
	return true
