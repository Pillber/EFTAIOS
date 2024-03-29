extends Node

enum CardType {
	# noise deck
	NOISE_THIS_SECTOR,
	NOISE_ANY_SECTOR,
	SILENT_SECTOR,
	
	# escape deck
	ESCAPE_SUCCESS,
	ESCAPE_FAIL,
}

class Card:
	var type: CardType
	var discard: bool
	var item = null
	
	func _init(p_type: CardType, to_discard: bool, p_item = null):
		type = p_type
		discard = to_discard
		item = p_item

"""
	77 total: 17 items
	27 Noise in Any Sector
	27 Noise in This Sector
	
	6 Silence (no item)
	17 Silence (with item)
		2 Attack - TurnState.ATTACKING
		3 Adrenaline - TurnState.MOVING
		3 Sedatives - TurnState.MOVING 
		1 Cat - TurnState.MAKING_NOISE
		1 Defense - When Attacked
		1 Clone - When Attacked
		1 Teleport - Any Time
		2 Spotlight - Any Time
		1 Sensor - Any Time
		1 Mutation - Any Time
"""
"""
	Player Abilities
	Human:
		Captain - First move is always sedative
		Pilot - One time Cat
		Psychologist - Start in Alien Spawn
		Soldier - One time Attack
		Executive Officer - "Lurk" (Stay still) once
		Co-Pilot - One time Teleport
		Engineer - Draw two escape cards, use one reshuffle other
		Medic - Force reveal identity
	Alien:
		Blink - Can use Teleport
		Silent - can use Sedatives
		Surge - Can use Adrenaline
		Brute - Immune to Attacks (reveal when attacked)
		Invisible - Immune to Spotlight and Sensor (reveal when targeted)
		Lurking - Attack without moving (still do sector stuff?)
		Fast - Move 3 spaces first turn
		Psychic - Every Silence is Noise in Any Sector

"""


var noise_deck_params = [
	{
		"type" : CardType.NOISE_THIS_SECTOR,
		"count" : 27,
		"discard" : true,
	},
	{
		"type" : CardType.NOISE_ANY_SECTOR,
		"count" : 27,
		"discard" : true,
	},
	{
		"type" : CardType.SILENT_SECTOR,
		"count" : 6,
		"discard" : false,
		"item" : null
	},
	{
		"type" : CardType.SILENT_SECTOR,
		"count" : 2,
		"discard" : false,
		"item" : "attack"
	},
]

var escape_deck_params = [
	{
		"type" : CardType.ESCAPE_SUCCESS,
		"count" : 4,
		"discard" : false,
	},
	{
		"type" : CardType.ESCAPE_FAIL,
		"count" : 1,
		"discard" : false,
	}
	
]

class Deck:
	
	var draw_pile: Array[Card]
	var discard_pile: Array[Card]
	
	func _init(params: Array):
		draw_pile = []
		discard_pile = []
		
		for card_type in params:
			var type = card_type["type"]
			var count = card_type["count"]
			var discard = card_type["discard"]
			var item = card_type["item"] if card_type.has("item") else null
			
			for _i in range(count):
				draw_pile.append(Card.new(type, discard, item))

		draw_pile.shuffle()
		
	func draw_card() -> Card:
		if discard_pile.size() != 0 and draw_pile.size() == 0:
			print("shuffling")
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		var drawn_card = draw_pile.pop_back()
		if drawn_card.discard:
			discard_pile.append(drawn_card)
		return drawn_card

var noise_deck: Deck
var escape_deck: Deck

func _ready() -> void:
	noise_deck = Deck.new(noise_deck_params)
	escape_deck = Deck.new(escape_deck_params)
