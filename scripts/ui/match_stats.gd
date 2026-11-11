extends RefCounted
# Pure data: no engine, UI, card objects, or wall-clock dependencies.
var seats: Array = []
var duration = 0.0
var winner_seat = -1
var card_pool = "2025"
var bot_difficulties: Array = []
var since_resume = false
var finished = false
func setup(count: int, pool: String, difficulties: Array, resumed = false):
 card_pool = pool
 bot_difficulties = difficulties.duplicate()
 since_resume = resumed
 for i in count:
  seats.append({"turns": 0, "damage_dealt": 0, "damage_taken": 0, "life_gained": 0, "cards_played": 0, "cards_bought": 0, "hacking_spent": 0, "cards_removed": 0, "biggest_hit": 0, "played": {}, "most_played_id": "", "priciest_id": "", "priciest_cost": -1, "final_life": 0, "final_deck_size": 0})
func turn(seat: int):
 if seat >= 0 and seat < seats.size(): seats[seat].turns += 1
func damage(source: int, target: int, amount: int):
 if amount <= 0: return
 if source >= 0 and source < seats.size():
  seats[source].damage_dealt += amount
  seats[source].biggest_hit = maxi(seats[source].biggest_hit, amount)
 if target >= 0 and target < seats.size(): seats[target].damage_taken += amount
func gain(seat: int, amount: int):
 if seat >= 0 and seat < seats.size(): seats[seat].life_gained += maxi(0, amount)
func played(seat: int, id: String):
 if seat < 0 or seat >= seats.size(): return
 var s = seats[seat]
 s.cards_played += 1
 s.played[id] = int(s.played.get(id, 0)) + 1
 if s.most_played_id == "" or s.played[id] > s.played[s.most_played_id]: s.most_played_id = id
## The card that defined this seat's game: the most-played card that is not a starter
## (Hacker and Attack would win every time), ties going to the costlier card, else the priciest buy.
func star_card(seat: int) -> String:
 if seat < 0 or seat >= seats.size(): return ""
 var s = seats[seat]
 var best = ""
 for id in s.played:
  if not CardDB.cards.has(id) or CardDB.cards[id].get("starter", false): continue
  var better = best == "" or s.played[id] > s.played[best] or (s.played[id] == s.played[best] and int(CardDB.cards[id].get("cost", 0)) > int(CardDB.cards[best].get("cost", 0)))
  if better: best = id
 return best if best != "" else (s.priciest_id if CardDB.cards.has(s.priciest_id) else "")
func bought(seat: int, id: String, cost: int):
 if seat < 0 or seat >= seats.size(): return
 var s = seats[seat]
 s.cards_bought += 1
 s.hacking_spent += maxi(0, cost)
 if cost > s.priciest_cost:
  s.priciest_cost = cost
  s.priciest_id = id
func removed(seat: int):
 if seat >= 0 and seat < seats.size(): seats[seat].cards_removed += 1
func finish(winner: int, players: Array):
 winner_seat = winner
 finished = true
 for p in players:
  seats[p.seat].final_life = p.life
  var cards = p.deck + p.hand + p.discard + p.play_area + p.reserve
  var pending = cards.duplicate()
  while not pending.is_empty():
   var c = pending.pop_back()
   cards.append_array(c.attached)
   pending.append_array(c.attached)
  seats[p.seat].final_deck_size = cards.size()
func to_dict() -> Dictionary:
 return {"seats": seats.duplicate(true), "duration": duration, "winner_seat": winner_seat, "card_pool": card_pool, "player_count": seats.size(), "bot_difficulties": bot_difficulties.duplicate(), "since_resume": since_resume, "finished": finished}
static func from_dict(data: Dictionary):
 var result = load("res://scripts/ui/match_stats.gd").new()
 if not data.get("seats") is Array or data.seats.size() < 2 or data.seats.size() > 4: return null
 if data.get("card_pool") not in ["2025", "2026", "2026mog"] or not data.get("bot_difficulties") is Array: return null
 if not data.get("since_resume") is bool or not data.get("finished") is bool: return null
 if data.bot_difficulties.size() != data.seats.size(): return null
 for level in data.bot_difficulties:
  if not (level is int or level is float) or not is_finite(float(level)) or level != floor(float(level)) or level < -1 or level > 2: return null
 result.setup(data.seats.size(), data.card_pool, data.bot_difficulties.map(func(level): return int(level)), data.since_resume)
 for i in result.seats.size():
  if not data.seats[i] is Dictionary: return null
  for key in result.seats[i]:
   var value = data.seats[i].get(key)
   var expected = result.seats[i][key]
   if expected is int:
    if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or value < (-1 if key == "priciest_cost" else 0): return null
    value = int(value)
   elif typeof(value) != typeof(expected): return null
   if key == "played":
    for id in value:
     if not id is String or not (value[id] is int or value[id] is float) or value[id] < 0 or not is_finite(float(value[id])) or float(value[id]) != floor(float(value[id])): return null
     value[id] = int(value[id])
   result.seats[i][key] = value
 var elapsed = data.get("duration", 0)
 if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed < 0: return null
 for seat in result.seats:
  if seat.most_played_id != "" and not seat.played.has(seat.most_played_id): return null
 result.duration = float(elapsed)
 var winner = data.get("winner_seat", -1)
 if not (winner is int or winner is float) or not is_finite(float(winner)) or winner != floor(float(winner)): return null
 result.winner_seat = int(winner)
 if result.winner_seat < -1 or result.winner_seat >= result.seats.size(): return null
 result.finished = bool(data.get("finished", false))
 return result
