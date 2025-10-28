# res://scenes/gs_winter/WinterScene.gd
extends Control
## Manages the WinterScene UI, which serves as the GDD's "Raid Planning Screen".
## It pulls data from singletons to populate the UI, calls the EconomyManager
## for RSC previews, and executes the raid on user confirmation.

# --- UI Node References ---
@onready var gold_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/GoldLabel
@onready var renown_label: Label = $MarginContainer/VBoxContainer/HeaderPanel/HBoxContainer/RenownLabel
@onready var jarl_name_label: Label = $MarginContainer/VBoxContainer/JarlPanel/HBoxContainer/JarlNameLabel
@onready var jarl_stress_label: Label = $MarginContainer/VBoxContainer/JarlPanel/HBoxContainer/JarlStressLabel
@onready var fylki_select: OptionButton = $MarginContainer/VBoxContainer/PlanningVBox/FylkiSelect
@onready var budget_input: SpinBox = $MarginContainer/VBoxContainer/PlanningVBox/BudgetInput
@onready var rsc_display: Label = $MarginContainer/VBoxContainer/FooterVBox/RSCDisplay
@onready var launch_raid_button: Button = $MarginContainer/VBoxContainer/FooterVBox/LaunchRaidButton

# Directory where Fylki data files are stored.
const FYLKI_DATA_PATH = "res://resources/data/fylkie_profile/"

# Store the loaded FylkiProfile resources.
var _fylki_profiles: Array[FylkiProfile] = []

func _ready() -> void:
	# --- 1. Connect to Singleton Signals ---
	# We connect to signals to ensure our UI updates *automatically*
	# when another system changes our Gold, Renown, or Stress.
	EconomyManager.gold_updated.connect(_on_gold_updated)
	EconomyManager.renown_updated.connect(_on_renown_updated)
	JarlManager.stress_changed.connect(_on_stress_changed)
	
	# --- 2. Connect Internal UI Signals (in code, per architecture) ---
	launch_raid_button.pressed.connect(_on_launch_raid_pressed)
	
	# Any change to these parameters should trigger a recalculation of the RSC.
	budget_input.value_changed.connect(_on_raid_parameters_changed)
	fylki_select.item_selected.connect(_on_raid_parameters_changed)

	# --- 3. Populate UI with Initial Data ---
	_populate_fylki_dropdown()
	_update_static_labels()
	
	# Set budget input limits based on GDD and current gold
	# GDD specifies a 0-100 gold investment range
	budget_input.max_value = clamp(EconomyManager.gold, 0, EconomyManager.MAX_BUDGET_INVESTMENT)
	
	# Do an initial RSC calculation
	_on_raid_parameters_changed()


func _exit_tree() -> void:
	# Always disconnect signals on cleanup.
	if EconomyManager.gold_updated.is_connected(_on_gold_updated):
		EconomyManager.gold_updated.disconnect(_on_gold_updated)
	if EconomyManager.renown_updated.is_connected(_on_renown_updated):
		EconomyManager.renown_updated.disconnect(_on_renown_updated)
	if JarlManager.stress_changed.is_connected(_on_stress_changed):
		JarlManager.stress_changed.disconnect(_on_stress_changed)
		
	# No need to disconnect internal signals (Button, SpinBox) if the
	# nodes are children, as Godot handles that. We only disconnect
	# external (Singleton) signals.


## Populates the OptionButton by loading all FylkiProfile.tres
## files from the data directory.
func _populate_fylki_dropdown() -> void:
	_fylki_profiles.clear()
	fylki_select.clear()
	
	var dir = DirAccess.open(FYLKI_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(FYLKI_DATA_PATH + file_name)
				if res is FylkiProfile:
					_fylki_profiles.append(res)
			file_name = dir.get_next()
	else:
		push_error("WinterScene: Failed to open Fylki data directory at: %s" % FYLKI_DATA_PATH)
		return

	# Now add the loaded profiles to the OptionButton
	for i in _fylki_profiles.size():
		var profile: FylkiProfile = _fylki_profiles[i]
		fylki_select.add_item(profile.fylki_name, i)
		# Store the *actual* resource as metadata. This is the key.
		fylki_select.set_item_metadata(i, profile)

	if _fylki_profiles.is_empty():
		push_warning("WinterScene: No FylkiProfile resources found in %s" % FYLKI_DATA_PATH)
		launch_raid_button.disabled = true
		rsc_display.text = "No Targets Available"


## Updates all labels that reflect the current game state.
func _update_static_labels() -> void:
	# Get data from managers
	_on_gold_updated(EconomyManager.gold)
	_on_renown_updated(EconomyManager.renown)
	_on_stress_changed(JarlManager.stress)
	jarl_name_label.text = "Jarl: %s" % JarlManager.jarl_name


# --- Signal Callbacks ---

## Called when budget or Fylki selection changes.
func _on_raid_parameters_changed(_any_value = 0) -> void:
	var selected_fylki: FylkiProfile = get_selected_fylki()
	if not selected_fylki:
		rsc_display.text = "RSC: --%"
		return

	# MODIFIED: Use roundi() to explicitly convert float to int
	var budget: int = roundi(budget_input.value)
	
	# Call our new "preview" function on the EconomyManager!
	var rsc: int = EconomyManager.calculate_rsc_preview(selected_fylki, budget)
	
	rsc_display.text = "Raid Success Chance: %s%%" % rsc


## Called when the "Launch Raid" button is pressed.
func _on_launch_raid_pressed() -> void:
	var selected_fylki: FylkiProfile = get_selected_fylki()
	if not selected_fylki:
		push_warning("WinterScene: Tried to launch raid with no Fylki selected.")
		return

	# MODIFIED: Use roundi() to explicitly convert float to int
	var budget: int = roundi(budget_input.value)
	
	print("WinterScene: Launching raid on %s with %s gold." % [selected_fylki.fylki_name, budget])
	
	# This is it. This call runs the entire abstracted MVP loop.
	EconomyManager.execute_abstracted_raid(selected_fylki, budget)
	
	# The EconomyManager will emit 'raid_completed' (which we could use
	# for a popup) and then tell the GameStateManager to switch phases,
	# which reloads this scene, completing the loop.


## Updates the Gold label.
func _on_gold_updated(new_gold: int) -> void:
	gold_label.text = "Gold: %s" % new_gold
	# Update budget input in case we lost gold
	budget_input.max_value = clamp(new_gold, 0, EconomyManager.MAX_BUDGET_INVESTMENT)
	budget_input.value = clamp(budget_input.value, 0, budget_input.max_value)


## Updates the Renown label.
func _on_renown_updated(new_renown: int) -> void:
	renown_label.text = "Renown: %s" % new_renown


## Updates the Jarl's stress label.
func _on_stress_changed(new_stress: int) -> void:
	var status: String = "Calm"
	if new_stress >= JarlManager.STRESS_THRESHOLD:
		status = "Stressed!"
	elif new_stress > 40:
		status = "Uneasy"
	
	# MODIFIED: Corrected variable name from 'jarl_label' to 'jarl_stress_label'
	jarl_stress_label.text = "Stress: %s (%s)" % [new_stress, status]


## Helper function to get the currently selected Fylki resource.
func get_selected_fylki() -> FylkiProfile:
	var selected_id = fylki_select.get_selected_id()
	if selected_id < 0:
		return null
	
	return fylki_select.get_item_metadata(selected_id) as FylkiProfile
