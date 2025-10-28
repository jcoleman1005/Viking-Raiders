# res://systems/EconomyManager.gd
class_name EconomyManager extends Node

## Manages Gold, Renown, Loot conversion , and Abstracted Raid resolution[cite: 18].

signal gold_updated(new_gold: int)
signal renown_updated(new_renown: int)
## Emitted after a raid is resolved, carrying a summary for the UI.
signal raid_completed(raid_summary: Dictionary)

# --- Core GDD Values ---
const BASE_RSC: int = 50 [cite: 25]
const BUDGET_SCALE_GOLD_PER_PERCENT: int = 10 [cite: 27]
const MAX_BUDGET_INVESTMENT: int = 100 [cite: 27]
const LOOT_TO_GOLD_CONVERSION: int = 1 [cite: 26]
const THRALL_TO_GOLD_CONVERSION: int = 10 [cite: 27]

# GDD  Success/Failure thresholds
const RSC_SUCCESS_THRESHOLD: int = 50
const RSC_FAILURE_THRESHOLD: int = 25

## PROVISIONAL: GDD is silent on base Renown. Added to make Renown-modifying traits  functional.
const BASE_RENOWN_PER_RAID: int = 5

# --- Player Resources ---
var gold: int = 300: [cite: 25]
	set(value):
		if gold != value:
			gold = value
			gold_updated.emit(gold)

var renown: int = 50: [cite: 25]
	set(value):
		if renown != value:
			renown = value
			renown_updated.emit(renown)

# --- Singleton References ---
var jarl_manager: JarlManager
var game_state_manager: GameStateManager

func _ready() -> void:
	# Store singleton references for performance.
	# This requires JarlManager and GameStateManager to be registered as Autoloads.
	jarl_manager = get_node_or_null("/root/JarlManager")
	game_state_manager = get_node_or_null("/root/GameStateManager")
	
	if not jarl_manager:
		push_error("EconomyManager: JarlManager singleton not found. Ensure it is an Autoload.")
	if not game_state_manager:
		push_error("EconomyManager: GameStateManager singleton not found. Ensure it is an Autoload.")

## Calculates the RSC bonus from Gold investment[cite: 19, 27].
func calculate_budget_bonus(investment: int) -> int:
	var clamped_investment = clamp(investment, 0, MAX_BUDGET_INVESTMENT)
	var bonus = clamped_investment / BUDGET_SCALE_GOLD_PER_PERCENT
	return bonus

## The core function for resolving the MVP's Abstracted Raid[cite: 18].
func execute_abstracted_raid(target_fylki: FylkiProfile, budget_investment: int) -> Dictionary:
	if not jarl_manager or not game_state_manager:
		push_error("EconomyManager: Missing core singletons. Aborting raid.")
		return {}

	if budget_investment > gold:
		print("EconomyManager: Not enough gold for raid budget. Aborting.")
		return {}

	# 1. Deduct cost
	self.gold -= budget_investment
	
	# 2. Calculate RSC 
	var budget_bonus: int = calculate_budget_bonus(budget_investment)
	var trait_bonus: int = jarl_manager.get_total_rsc_modifier_from_traits()
	var fylki_penalty: int = target_fylki.levy_penalty_rsc [cite: 50]
	
	# GDD Formula: (Base + Budget + Trait) - (Fylki Penalty)
	var total_rsc: int = (BASE_RSC + budget_bonus + trait_bonus) - fylki_penalty
	total_rsc = clamp(total_rsc, 0, 100)

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
		# Neutral outcome (25-49 RSC). Per GDD, no stress change.
		# PROVISIONAL: GDD is silent on Neutral loot. Defaulting to 50%.
		outcome = "Neutral"
		loot_multiplier = 0.5 

	# 4. Calculate Loot & Thralls
	# We scale rewards based on the RSC (a 51% success is worse than a 90%)
	var rsc_lerp_factor = float(total_rsc) / 100.0
	var base_loot = lerp(0.0, float(target_fylki.max_loot_potential), rsc_lerp_factor) [cite: 51]
	var base_thralls = lerp(float(target_fylki.min_thralls_potential), float(target_fylki.max_thralls_potential), rsc_lerp_factor) [cite: 51, 52]
	var base_renown = float(BASE_RENOWN_PER_RAID)

	# 5. Apply Jarl's Secondary Trait Modifiers [cite: 59]
	var loot_mod: float = 1.0
	var thrall_mod: float = 1.0
	var renown_mod: float = 1.0

	for trait in jarl_manager.jarl_traits:
		var effect_percent = float(trait.secondary_effect_percent) / 100.0 [cite: 60]
		match trait.secondary_effect_type:
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
	# GDD [cite: 27] says Gold OR Renown. Defaulting to Gold for MVP.
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
	
	# Tell the GameStateManager to return to the management phase
	game_state_manager.switch_phase(GameStateManager.GamePhase.WINTER)
	
	return summary
