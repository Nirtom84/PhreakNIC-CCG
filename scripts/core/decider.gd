class_name Decider
extends RefCounted
## Override with UI dialogs that await a signal. All engine calls await this API.
func choose_option(_player, _prompt: String, _options: Array[String]) -> int: return 0
func choose_options(_player, _prompt: String, options: Array[String], count: int) -> Array[int]:
	var result: Array[int] = []
	for i in mini(count, options.size()): result.append(i)
	return result
func choose_cards(_player, _prompt: String, cards: Array, min_n: int, _max_n: int) -> Array: return cards.slice(0, min_n)
func choose_player(_player, _prompt: String, players: Array) -> PlayerState: return players[0] if not players.is_empty() else null
func choose_number(_player, _prompt: String, allowed: Array[int]) -> int: return allowed[0] if not allowed.is_empty() else 0
func confirm(_player, _prompt: String) -> bool: return false
func name_a_card(_player, _prompt: String) -> String: return "Hacking"
