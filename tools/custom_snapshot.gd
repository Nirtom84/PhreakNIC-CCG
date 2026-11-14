extends SceneTree
func _initialize():
 var codes = CustomBotDecks.load_decks().map(func(d): return CustomDeck.encode(d))
 var file = FileAccess.open(OS.get_environment("CB_DECK_OUT"), FileAccess.WRITE)
 file.store_string(JSON.stringify(codes)); file.close()
 quit()
