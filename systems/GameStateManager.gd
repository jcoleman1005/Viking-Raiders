extends Node
# Manages the overall game state, particularly transitions between Winter and Summer phases.

enum GameState {
	WINTER, # Grand Strategy phase
	SUMMER  # Real-time Strategy (Raid) phase
}

signal game_state_changed(new_state)

var current_state: GameState = GameState.WINTER:
	set(value):
		if current_state != value:
			current_state = value
			game_state_changed.emit(current_state)

func _ready() -> void:
	# Ensure the initial state is broadcasted if other nodes need it on startup.
	game_state_changed.emit(current_state)
	print("GameStateManager ready. Current state: WINTER")

func transition_to_summer() -> void:
	"""Initiates the transition to the Summer (RTS) phase."""
	if current_state == GameState.WINTER:
		self.current_state = GameState.SUMMER
		print("Transitioning to SUMMER phase.")
		# Here you would add logic to switch scenes, show raid UI, etc.

func transition_to_winter() -> void:
	"""Initiates the transition back to the Winter (GS) phase."""
	if current_state == GameState.SUMMER:
		self.current_state = GameState.WINTER
		print("Transitioning to WINTER phase.")
		# Here you would add logic to handle raid results and return to the main map.

func is_winter() -> bool:
	return current_state == GameState.WINTER

func is_summer() -> bool:
	return current_state == GameState.SUMMER
