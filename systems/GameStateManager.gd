# res://systems/GameStateManager.gd
extends Node

## Enum for the two distinct phases of the hybrid game.
enum GamePhase {
	WINTER, # Grand Strategy, Management, Diplomacy, Raid Planning
	SUMMER  # Real-Time Strategy, Raiding, Combat Resolution (Abstracted in MVP)
}

## Signals
signal phase_changed(new_phase: GamePhase)
signal game_started()

var current_phase: GamePhase = GamePhase.WINTER

# --- Scene Registry (Replaces string paths) ---
const SCENE_REGISTRY_PATH: String = "res://resources/data/scene_registry.tres"
var scene_registry: SceneRegistry

func _ready() -> void:
	# Load the scene registry resource.
	scene_registry = load(SCENE_REGISTRY_PATH)
	if not scene_registry:
		push_error("GameStateManager: FAILED TO LOAD SCENE REGISTRY. Check path: %s" % SCENE_REGISTRY_PATH)
		get_tree().quit() # This is a fatal error, we can't run.
		return

	# Use call_deferred to ensure the scene tree is fully ready before loading the first scene.
	call_deferred("start_game")

## Initializes the game, loading the initial scene and emitting the startup signal.
func start_game() -> void:
	print("GameStateManager: Initializing game...")
	
	# Load the Winter Scene from our registry.
	if scene_registry.winter_scene:
		# Use change_scene_to_packed, which takes the PackedScene object directly.
		get_tree().change_scene_to_packed(scene_registry.winter_scene)
		current_phase = GamePhase.WINTER
		game_started.emit()
		print("GameStateManager: Game started, currently in WINTER phase.")
	else:
		# This error is now much more specific.
		push_error("GameStateManager: Winter Scene is not assigned in scene_registry.tres!")

## Switches the game between the Winter and Summer phases.
func switch_phase(target_phase: GamePhase) -> void:
	# --- MODIFICATION ---
	# We've changed the logic here to allow the SUMMER -> WINTER transition.
	
	if current_phase == target_phase:
		# It's fine to call WINTER -> WINTER, but we don't want to log an error.
		# We only care if we try to enter a state we're already in.
		if target_phase == GamePhase.SUMMER:
			print("GameStateManager: Already in SUMMER phase.")
			return
		elif target_phase == GamePhase.WINTER:
			# This is the "Already in phase 0" log. We can silence it.
			# print("GameStateManager: Already in WINTER phase.")
			pass
		
	# Only set the phase if it's a real change.
	if current_phase != target_phase:
		current_phase = target_phase
	
	match target_phase:
		GamePhase.SUMMER:
			# This is the "Abstracted Raid" phase.
			# As per the GDD, we don't load a scene. We just log.
			print("GameStateManager: Entering SUMMER phase (Abstracted Raid)")
			pass 
			
		GamePhase.WINTER:
			print("GameStateManager: Switching back to the WINTER phase (Management)")
			if scene_registry.winter_scene:
				get_tree().change_scene_to_packed(scene_registry.winter_scene)
			else:
				push_error("GameStateManager: Winter Scene is not assigned in scene_registry.tres!")
	
	phase_changed.emit(target_phase)
