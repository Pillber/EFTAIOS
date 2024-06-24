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
		2 Attack - TurnState.ATTACKING (DONE)
		1 Defense - When Attacked (DONE)
		1 Clone - When Attacked (DONE)
		1 Cat - TurnState.MAKING_NOISE (DONE)
		3 Adrenaline - TurnState.MOVING (DONE)
		3 Sedatives - TurnState.MOVING 
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


var noise_deck_params = preload("res://decks/noise_deck.tres").deck
var escape_deck_params = preload("res://decks/escape_deck.tres").deck

class Deck:
	
	var draw_pile: Array[Card]
	var discard_pile: Array[Card]
	
	func _init(params: Array):
		draw_pile = []
		discard_pile = []
		
		for card_type in params:
			for _i in range(card_type.count):
				draw_pile.append(Card.new(card_type.type, card_type.discard, card_type.item))

		draw_pile.shuffle()
		
	func draw_card(force_discard: bool = false) -> Card:
		if discard_pile.size() != 0 and draw_pile.size() == 0:
			print("shuffling")
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		var drawn_card = draw_pile.pop_back()
		if force_discard or drawn_card.discard:
			discard_pile.append(drawn_card)
		return drawn_card

var noise_deck: Deck
var escape_deck: Deck

func _ready() -> void:
	noise_deck = Deck.new(noise_deck_params)
	escape_deck = Deck.new(escape_deck_params)
