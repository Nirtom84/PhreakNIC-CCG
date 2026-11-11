class_name BotPace
extends RefCounted
const BOT_PACES = [0.0, 0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 5.0]
static func allowed(value) -> bool:
	if not (value is int or value is float): return false
	for pace in BOT_PACES:
		if float(value) == pace: return true
	return false
static func nearest(value) -> float:
	if not (value is int or value is float) or not is_finite(float(value)): return 0.5
	var result = 0.5
	var distance = INF
	for pace in BOT_PACES:
		if absf(float(value) - pace) < distance:
			result = pace
			distance = absf(float(value) - pace)
	return result
static func pace_label(value, short: bool = false) -> String:
	var pace = nearest(value)
	return "Instant" if pace == 0 else (str(int(pace)) if pace == int(pace) else str(pace)) + (" s" if short else " s per card")
static func saved_pace(data: Dictionary) -> float:
	if data.has("bot_pace"): return nearest(data.bot_pace)
	var speed = data.get("bot_speed", -1)
	if (speed is int or speed is float) and (speed == 0 or speed == 1 or speed == 2): return [0.5, 0.25, 0.0][int(speed)]
	return 0.0 if data.get("fast", data.get("bot_fast", false)) == true else 0.5
