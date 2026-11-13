class_name CustomDeck
extends RefCounted
## Stable printing IDs, bounded portable codes, and experimental Center Deck rules.
const PREFIX = "PNDK1."
const MAX_BYTES = 8192
static func database():
	return Engine.get_main_loop().root.get_node("CardDB").catalog("custom")
static func rules_id(id: String) -> String:
	return id.trim_suffix("@mog")
static func base_id(printing_id: String) -> String:
	var id = printing_id.trim_suffix("@mog")
	if id in ["Botnet", "Botnet1", "Botnet2", "Botnet3", "Botnet4", "Mognet", "Mognet1", "Mognet2", "Mognet3", "Mognet4"]: return "Botnet"
	return id
static func normalize(deck: Dictionary) -> Dictionary:
	var cards = {}
	var ids = deck.get("cards", {}).keys()
	ids.sort()
	for id in ids: cards[id] = int(deck.cards[id])
	return {"name": deck.get("name", ""), "cards": cards}
static func total(deck: Dictionary) -> int:
	var result = 0
	if not deck.get("cards") is Dictionary: return 0
	for count in deck.cards.values():
		if count is int or count is float:
			if is_finite(float(count)) and count >= 0 and count <= 200: result += int(count)
	return result
static func validate(deck: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not deck.get("name") is String or deck.name.strip_edges().is_empty() or deck.name.length() > 40: errors.append("Deck name must be 1–40 characters")
	if not deck.get("cards") is Dictionary: errors.append("Cards must be a dictionary"); return errors
	if deck.cards.size() > 200: errors.append("Too many entries"); return errors
	var db = database()
	var counts = {}
	for id in deck.cards:
		if not id is String or not db.cards.has(id): errors.append("Unknown card: " + str(id)); continue
		var card = db.get_card(id)
		if card.get("starter", false): errors.append(card.name + " can't be in a deck")
		var n = deck.cards[id]
		if not (n is int or n is float): errors.append("Invalid count for " + id); continue
		if not is_finite(float(n)) or n != floor(float(n)) or n < 1 or n > 200: errors.append("Invalid count for " + id); continue
		var base = base_id(id)
		counts[base] = counts.get(base, 0) + int(n)
	for id in counts:
		var legendary = db.has_subtype(id, "Legendary")
		var limit = 2 if legendary else 4
		if counts[id] > limit: errors.append("Too many copies of %s%s: %d (max %d)" % ["Legendary card " if legendary else "", db.get_card(id).name, counts[id], limit])
	var size = total(deck)
	if size < 60: errors.append("Needs at least 60 cards (has %d)" % size)
	if size > 200: errors.append("Needs at most 200 cards (has %d)" % size)
	return errors
static func printings() -> Array:
	var db = database()
	var result = []
	for id in db.cards:
		var card = db.get_card(id)
		if card.get("starter", false): continue
		# Physical duplicate catalog IDs are one buildable printing, with counts.
		if id in ["Botnet1", "Botnet2", "Botnet3", "Botnet4", "Mognet1", "Mognet2", "Mognet3", "Mognet4"]: continue
		result.append({"id": id, "name": card.name, "base_id": base_id(id), "cost": card.cost, "type_line": card.type_line, "set": "2026mog" if id.ends_with("@mog") else card.get("set", "2025"), "image": db.image_path(id), "legendary": db.has_subtype(id, "Legendary")})
	result.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0 if a.name != b.name else a.id < b.id)
	return result
static func encode(deck: Dictionary) -> String:
	if not validate(deck).is_empty(): return ""
	var bytes = JSON.stringify(normalize(deck)).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	return PREFIX + Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")
static func decode(code: String) -> Dictionary:
	if code.length() > MAX_BYTES or not code.begins_with(PREFIX): return {}
	var body = code.substr(PREFIX.length())
	if body.is_empty() or body.length() % 4 == 1: return {}
	for ch in body:
		if not ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_": return {}
	body = body.replace("-", "+").replace("_", "/")
	while body.length() % 4: body += "="
	var compressed = Marshalls.base64_to_raw(body)
	if compressed.is_empty(): return {}
	var bytes = BoundedInflater.new().inflate(compressed)
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return {}
	return parse_payload(bytes.get_string_from_utf8())
static func parse_payload(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return {}
	var parser = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary: return {}
	var deck = parser.data
	if not validate(deck).is_empty(): return {}
	return normalize(deck)
static func to_file_text(deck: Dictionary) -> String:
	var code = encode(deck)
	if code.is_empty(): return ""
	var readable = []
	for id in normalize(deck).cards: readable.append("%d × %s [%s]" % [deck.cards[id], database().get_card(id).name, id])
	return JSON.stringify({"name": deck.name, "code": code, "cards": readable}, "  ")
static func from_file_text(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > 32768: return {}
	text = text.strip_edges()
	if text.begins_with(PREFIX): return decode(text)
	var parser = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary: return {}
	var code = parser.data.get("code")
	return decode(code) if code is String else {}

## Small bounded RFC 1950/1951 reader: native decompression logs errors on
## untrusted input. All malformed/truncated streams instead return empty here.
class BoundedInflater:
	extends RefCounted
	var source: PackedByteArray
	var bit = 16
	var failed = false
	var output = PackedByteArray()
	func bits(n: int) -> int:
		if failed or bit + n > (source.size() - 4) * 8: failed = true; return 0
		var value = 0
		for i in n:
			value |= ((source[bit >> 3] >> (bit & 7)) & 1) << i
			bit += 1
		return value
	func tree(lengths: Array) -> Dictionary:
		var counts = []
		counts.resize(16)
		counts.fill(0)
		for n in lengths:
			if n < 0 or n > 15: failed = true; return {}
			if n: counts[n] += 1
		var codes = []
		codes.resize(16)
		codes.fill(0)
		var code = 0
		for n in range(1, 16):
			code = (code + counts[n - 1]) << 1
			if code + counts[n] > (1 << n): failed = true; return {}
			codes[n] = code
		var result = {}
		for symbol in lengths.size():
			var n = lengths[symbol]
			if not n: continue
			result[(1 << n) | codes[n]] = symbol
			codes[n] += 1
		return result
	func symbol(table: Dictionary) -> int:
		var code = 0
		for n in range(1, 16):
			code = (code << 1) | bits(1)
			if failed: return -1
			if table.has((1 << n) | code): return table[(1 << n) | code]
		failed = true
		return -1
	func emit(value: int):
		if output.size() >= MAX_BYTES: failed = true; return
		output.append(value)
	func inflate(bytes: PackedByteArray) -> PackedByteArray:
		source = bytes
		if source.size() < 6 or source[0] & 15 != 8 or source[0] >> 4 > 7 or ((source[0] << 8) | source[1]) % 31 != 0 or source[1] & 32: return PackedByteArray()
		var final_block = false
		while not final_block and not failed:
			final_block = bits(1) == 1
			var kind = bits(2)
			if kind == 0:
				bit = (bit + 7) & ~7
				var size = bits(16)
				if bits(16) != (size ^ 65535): failed = true; break
				if size > MAX_BYTES - output.size(): failed = true; break
				for i in size: emit(bits(8))
				continue
			if kind == 3: failed = true; break
			var lengths = []
			var distances = []
			if kind == 1:
				for i in 288: lengths.append(8 if i < 144 else (9 if i < 256 else (7 if i < 280 else 8)))
				for i in 32: distances.append(5)
			else:
				var literal_count = bits(5) + 257
				var distance_count = bits(5) + 1
				var code_count = bits(4) + 4
				var order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
				var code_lengths = []
				code_lengths.resize(19)
				code_lengths.fill(0)
				for i in code_count: code_lengths[order[i]] = bits(3)
				var codes = tree(code_lengths)
				var combined = []
				while combined.size() < literal_count + distance_count and not failed:
					var value = symbol(codes)
					if value < 0: break
					if value < 16: combined.append(value); continue
					var repeat_count = 0
					var repeated = 0
					if value == 16:
						if combined.is_empty(): failed = true; break
						repeated = combined.back()
						repeat_count = bits(2) + 3
					elif value == 17: repeat_count = bits(3) + 3
					else: repeat_count = bits(7) + 11
					if combined.size() + repeat_count > literal_count + distance_count: failed = true; break
					for i in repeat_count: combined.append(repeated)
				if failed: break
				lengths = combined.slice(0, literal_count)
				distances = combined.slice(literal_count)
			if lengths.size() <= 256 or lengths[256] == 0: failed = true; break
			var literals = tree(lengths)
			var offsets = tree(distances)
			var bases = [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258]
			var extras = [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0]
			var distance_bases = [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577]
			while not failed:
				var value = symbol(literals)
				if value < 0 or value == 256: break
				if value < 256: emit(value); continue
				if value > 285: failed = true; break
				var length = bases[value - 257] + bits(extras[value - 257])
				var distance_symbol = symbol(offsets)
				if distance_symbol < 0 or distance_symbol > 29: failed = true; break
				var extra = maxi(0, (distance_symbol >> 1) - 1)
				var distance = distance_bases[distance_symbol] + bits(extra)
				if distance > output.size() or length > MAX_BYTES - output.size(): failed = true; break
				for i in length: emit(output[output.size() - distance])
		if failed or ((bit + 7) >> 3) != source.size() - 4: return PackedByteArray()
		var a = 1
		var b = 0
		for byte in output:
			a = (a + byte) % 65521
			b = (b + a) % 65521
		var checksum = (b << 16) | a
		var size = source.size()
		var expected = (source[size - 4] << 24) | (source[size - 3] << 16) | (source[size - 2] << 8) | source[size - 1]
		return output if checksum == expected else PackedByteArray()
