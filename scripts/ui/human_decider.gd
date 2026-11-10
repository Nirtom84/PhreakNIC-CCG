class_name HumanDecider
extends Decider
var ui
func _init(table): ui = table
func choose_option(_p, prompt: String, options: Array[String]) -> int:
 return await ui.decision(prompt, options, [], 1, 1, false)
func choose_options(_p, prompt: String, options: Array[String], count: int) -> Array[int]:
 var result: Array[int] = []
 for i in await ui.decision(prompt, options, [], count, count, true): result.append(i)
 return result
func choose_cards(_p, prompt: String, cards: Array, min_n: int, max_n: int) -> Array:
 var result: Array = []
 for i in await ui.decision(prompt, [], cards, min_n, max_n, true): result.append(cards[i])
 return result
func choose_player(_p, prompt: String, players: Array) -> PlayerState:
 var names: Array[String] = []
 for p in players: names.append(ui.player_name(p))
 return players[await ui.decision(prompt, names, [], 1, 1, false)]
func choose_number(_p, prompt: String, allowed: Array[int]) -> int:
 var names: Array[String] = []
 for n in allowed: names.append(str(n))
 return allowed[await ui.decision(prompt, names, [], 1, 1, false)]
func confirm(_p, prompt: String) -> bool:
 return await ui.decision(prompt, ["Yes", "No"], [], 1, 1, false) == 0
func name_a_card(_p, prompt: String) -> String:
 var ids: Array = ui.engine.db().pool_ids(ui.engine.state.card_pool)
 ids.sort_custom(func(a, b): return ui.engine.db().get_card(a).name < ui.engine.db().get_card(b).name)
 var names: Array[String] = []
 for id in ids: names.append(ui.engine.db().get_card(id).name)
 return ids[await ui.decision(prompt, names, [], 1, 1, false, true)]

func allocate_prevention(player, amount: int, sources: Array) -> Array:
 var result: Array = []
 var remaining = amount
 for i in sources.size():
  var later = 0
  for j in range(i + 1, sources.size()): later += sources[j].capacity
  var minimum = maxi(0, mini(remaining, remaining - later))
  var maximum = mini(remaining, sources[i].capacity)
  var n = maximum
  if minimum < maximum:
   var allowed: Array[int] = []
   for value in range(minimum, maximum + 1): allowed.append(value)
   var name = sources[i].get("name", "")
   if sources[i].card != null: name = ui.engine.db().get_card(sources[i].card.id).name
   n = await choose_number(player, "Prevent how many of %d damage with %s?" % [remaining, name], allowed)
  result.append(n)
  remaining -= n
 return result
