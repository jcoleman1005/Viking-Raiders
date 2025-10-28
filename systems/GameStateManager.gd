class_name GameStateManager extends Node

## Enum for the two distinct phases of the hybrid game.
enum GamePhase {
	WINTER, # Grand Strategy, Management, Diplomacy, Raid Planning
	SUMMER  # Real-Time Strategy, Raiding, Combat Resolution (Abstracted in MVP)
}

## Signals
signal phase_changed(new_phase: GamePhase)
signal game_started()

var current_phase: GamePhase = GamePhase.WINTER

# --- Scene Paths (Provisional and Configurable Defaults) ---
# NOTE: These paths use safe defaults based on the GDD structure.
const WINTER_SCENE_PATH: String = "res://scenes/gs_winter/WinterScene.tscn"
const SUMMER_SCENE_PATH: String = "res://scenes/rts_summer/SummerScene.tscn"

func _ready() -> void:
	# Use call_deferred to ensure the scene tree is fully ready before loading the first scene.
	call_deferred("start_game")

## Initializes the game, loading the initial scene and emitting the startup signal.
func start_game() -> void:
	print("GameStateManager: Initializing game...")
	
	# Load the Winter Scene as the entry point for the MVP loop.
	if load(WINTER_SCENE_PATH):
		get_tree().change_scene_to_file(WINTER_SCENE_PATH)
		current_phase = GamePhase.WINTER
		game_started.emit()
		print("GameStateManager: Game started, currently in WINTER phase.")
	else:
		# If the Winter Scene is missing, print an error for immediate debugging.
		push_error("GameStateManager: Failed to load Winter Scene. Check path: ", WINTER_SCENE_PATH)

## Switches the game between the Winter and Summer phases.
func switch_phase(target_phase: GamePhase) -> void:
	if current_phase == target_phase:
		print("GameStateManager: Already in phase ", target_phase)
		return

	current_phase = target_phase
	
	match current_phase:
		GamePhase.SUMMER:
			# NOTE: For the MVP, the 'Summer' scene is the Abstracted Raid screen.
			# We will not load a new scene here yet. The Raid Planning screen (in the Winter Scene)
			# will call EconomyManager.execute_raid() and then call switch_phase back to WINTER
			# once the raid resolution is complete.
			pass 
			
		GamePhase.WINTER:
			print("GameStateManager: Switching back to the WINTER phase (Management)")
			get_tree().change_scene_to_file(WINTER_SCENE_PATH)
	
	# FIX IMPLEMENTED: Emitting the target_phase argument is critical for listeners.
	phase_changed.emit(target_phase)
