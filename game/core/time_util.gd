class_name TimeUtil
## The single wall-clock read point. All other code takes `now: int` params.


static func now() -> int:
	return int(Time.get_unix_time_from_system())
