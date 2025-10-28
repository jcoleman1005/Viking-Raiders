# res://systems/EconomyManager.gd
extends Node

## Manages Gold, Renown, Loot conversion , and Abstracted Raid resolution.
signal gold_updated(new_gold: int)
signal renown_updated(new_renown: int)
## Emitted after a raid is resolved, carrying a summary for the UI.
signal raid_completed(raid_summary: Dictionary)

# --- Core GDD Values ---
const BASE_RSC: int = 50
const BUDGET_SCALE_GOLD_PER_PERCENT: int = 10
const MAX_BUDGET_INVESTMENT: int = 100
const LOOT_TO_GOLD_CONVERSION: int = 1
const THRALL_TO_GOLD_CONVERSION: int = 10

# GDD Success/Failure thresholds
const RSC_SUCCESS_THRESHOLD: int = 50
const RSC_FAILURE_THRESHOLD: int = 25

## PROVISIONAL: GDD is silent on base Renown.
## Added to make Renown-modifying traits functional.
const BASE_RENOWN_PER_RAID: int = 5

# --- Player Resources ---
var gold: int = 300:
	set(value):
		if gold != value:
			gold = value
			gold_updated.emit(gold)

var renown: int = 50:
	set(value):
		if renown != value:
			renown = value
			renown_updated.emit(renown)

# --- Singleton References ---
var jarl_manager
var game_state_manager

func _ready() -> void:
	# Store singleton references for performance.
	# This requires JarlManager and GameStateManager to be registered as Autoloads.
	jarl_manager = get_node_or_null("/root/JarlManager")
	game_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not jarl_manager:
		push_error("EconomyManager: JarlManager singleton not found. Ensure it is an Autoload.")
	if not game_state_manager:
		push_error("EconomyManager: GameStateManager singleton not found. Ensure it is an Autoload.")

## Calculates the RSC bonus from Gold investment.
func calculate_budget_bonus(investment: int) -> int:
	var clamped_investment = clamp(investment, 0, MAX_BUDGET_INVESTMENT)
	var bonus = clamped_investment / BUDGET_SCALE_GOLD_PER_PERCENT
	return bonus


# --- NEW PUBLIC FUNCTION ---
## Calculates the RSC for UI preview purposes *without* executing the raid.
## This contains the core formula from the GDD.
func calculate_rsc_preview(target_fylki: FylkiProfile, budget_investment: int) -> int:
	if not jarl_manager:
		push_warning("EconomyManager: JarlManager not ready, cannot calculate RSC preview.")
		return BASE_RSC

	# 1. Calculate all components of the RSC formula
	var budget_bonus: int = calculate_budget_bonus(budget_investment)
	var trait_bonus: int = jarl_manager.get_total_rsc_modifier_from_traits()
	
	# Fylki penalty is stored as a negative int (e.g., -25)
	var fylki_penalty: int = target_fylki.levy_penalty_rsc
	
	# GDD Formula: (Base + Budget + Trait) - (Fylki Penalty)
	var total_rsc: int = BASE_RSC + budget_bonus + trait_bonus + fylki_penalty
	
	# 2. Clamp the final result between 0 and 100
	total_rsc = clamp(total_rsc, 0, 100)
	
	return total_rsc


## The core function for resolving the MVP's Abstracted Raid.
func execute_abstracted_raid(target_fylki: FylkiProfile, budget_investment: int) -> Dictionary:
	if not jarl_manager or not game_state_manager:
		push_error("EconomyManager: Missing core singletons. Aborting raid.")
		return {}

	# --- MODIFICATION ---
	# Tell the GameStateManager we are *ENTERING* the Summer phase.
	# This is the "Abstracted Raid" itself.
	game_state_manager.switch_phase(GameStateManager.GamePhase.SUMMER)

	if budget_investment > gold:
		print("EconomyManager: Not enough gold for raid budget. Aborting.")
		# We must still return to WINTER, or the game is stuck
		game_state_manager.switch_phase(GameStateManager.GamePhase.WINTER)
		return {}

	# 1. Deduct cost
	self.gold -= budget_investment
	
	# 2. Calculate RSC 
	var total_rsc: int = calculate_rsc_preview(target_fylki, budget_investment)

	# 3. Determine Outcome & Apply Stress 
	var outcome: String = "Neutral"
	var loot_multiplier: float = 0.0
	
	if total_rsc >= RSC_SUCCESS_THRESHOLD:
		outcome = "Success"
		loot_multiplier = 1.0
		jarl_manager.apply_raid_result(true) # Apply stress reduction
	elif total_rsc < RSC_FAILURE_THRESHOLD:
		outcome = "Failure"
		loot_multiplier = 0.0
		jarl_manager.apply_raid_result(false) # Apply stress increase
	else:
		outcome = "Neutral"
		loot_multiplier = 0.5

	# 4. Calculate Loot & Thralls
	var rsc_lerp_factor = float(total_rsc) / 100.0
	var base_loot = lerp(0.0, float(target_fylki.max_loot_potential), rsc_lerp_factor)
	var base_thralls = lerp(float(target_fylki.min_thralls_potential), float(target_fylki.max_thralls_potential), rsc_lerp_factor)
	var base_renown = float(BASE_RENOWN_PER_RAID)

	# 5. Apply Jarl's Secondary Trait Modifiers
	var loot_mod: float = 1.0
	var thrall_mod: float = 1.0
	var renown_mod: float = 1.0

	for jarl_trait in jarl_manager.jarl_traits:
		var effect_percent = float(jarl_trait.secondary_effect_percent) / 100.0
		match jarl_trait.secondary_effect_type:
			JarlTrait.SecondaryEffectType.LOOT:
				loot_mod += effect_percent
			JarlTrait.SecondaryEffectType.THRALLS:
				thrall_mod += effect_percent
			JarlTrait.SecondaryEffectType.RENOWN:
				renown_mod += effect_percent

	var final_loot: int = roundi(base_loot * loot_multiplier * loot_mod)
	var final_thralls: int = roundi(base_thralls * loot_multiplier * thrall_mod)
	var final_renown: int = roundi(base_renown * loot_multiplier * renown_mod)

	# 6. Add Final Resources
	self.gold += final_loot * LOOT_TO_GOLD_CONVERSION
	self.gold += final_thralls * THRALL_TO_GOLD_CONVERSION 
	self.renown += final_renown

	# 7. Emit summary and transition phase 
	var summary = {
		"outcome": outcome,
		"total_rsc": total_rsc,
		"loot_won": final_loot,
		"thralls_captured": final_thralls,
		"renown_gained": final_renown,
		"budget_spent": budget_investment,
		"target_fylki": target_fylki.fylki_name
	}
	
	raid_completed.emit(summary)
	print("Raid completed. Outcome: %s (RSC: %d)" % [outcome, total_rsc])
	
	# --- MODIFICATION ---
	# Tell the GameStateManager to *RETURN* to the Winter phase.
	# Now the state will be SUMMER, and the target will be WINTER,
	# so the scene reload will work.
	game_state_manager.switch_phase(GameStateManager.GamePhase.WINTER)
	
	return summary
