class_name EconomyManager extends Node

## Manages Gold, Renown, and Raid calculations.

# --- Signals ---
## Emitted when the player's core resources change.
signal gold_changed(new_gold: int)
signal renown_changed(new_renown: int)

# --- Core Resource Variables ---
var gold: int = 300:
	set(value):
		if gold != value:
			gold = value
			gold_changed.emit(gold)

var renown: int = 50:
	set(value):
		if renown != value:
			renown = value
			renown_changed.emit(renown)

# --- GDD Constants ---
const BASE_RSC: int = 50 #
const LOOT_TO_GOLD_CONVERSION: int = 1 #
const THRALL_TO_GOLD_VALUE: int = 10 #
const THRALL_TO_RENOWN_VALUE: int = 10 #

# --- System References ---
# We will connect these in the main scene or a bootstrapper.
var jarl_manager: JarlManager
var game_state_manager: GameStateManager

# --- Public API ---

## Calculates the Raid Success Chance (RSC) for the MVP abstracted raid.
## This is the core formula from the GDD.
func calculate_rsc(fylki_profile: FylkiProfile, raid_budget: int, jarl_traits: Array) -> int:
	
	# 1. Base + Budget Bonus
	var rsc: int = BASE_RSC + calculate_budget_bonus(raid_budget)
	
	# 2. Trait Bonus
	var trait_bonus: int = 0
	for trait in jarl_traits:
		if trait is JarlTrait:
			trait_bonus += trait.rsc_modifier_percent #
	rsc += trait_bonus
	
	# 3. Fylki Penalty
	rsc += fylki_profile.levy_penalty_rsc #
	
	# 4. Alliance Modifier (Future Scope, placeholder for now)
	# rsc += alliance_modifier 
	
	return clamp(rsc, 0, 100)

## Executes the abstracted raid, calculates results, and updates resources.
## This function will be called from the Raid Planning UI.
func execute_abstracted_raid(fylki_profile: FylkiProfile, raid_budget: int, jarl_traits: Array) -> void:
	if not jarl_manager:
		push_error("EconomyManager: JarlManager reference is not set!")
		return

	# 1. Pay the budget cost
	self.gold -= raid_budget
	
	# 2. Calculate Success
	var rsc: int = calculate_rsc(fylki_profile, raid_budget, jarl_traits)
	var is_success: bool = randi_range(1, 100) <= rsc
	
	var loot_won: int = 0
	var thralls_won: int = 0
	var renown_won: int = 0 # Placeholder for now, GDD doesn't specify base renown gain

	# 3. Process Results
	if is_success:
		print("RAID SUCCESSFUL! (RSC: %d)" % rsc)
		
		# Calculate winnings based on Fylki potential
		loot_won = fylki_profile.max_loot_potential #
		thralls_won = randi_range(fylki_profile.min_thralls_potential, fylki_profile.max_thralls_potential) #
		
		# Apply Jarl Trait modifiers for secondary effects
		for trait in jarl_traits:
			if trait is JarlTrait:
				match trait.secondary_effect_type:
					JarlTrait.SecondaryEffectType.LOOT:
						loot_won += int(loot_won * (trait.secondary_effect_percent / 100.0))
					JarlTrait.SecondaryEffectType.THRALLS:
						thralls_won += int(thralls_won * (trait.secondary_effect_percent / 100.0))
					JarlTrait.SecondaryEffectType.RENOWN:
						renown_won += int(renown_won * (trait.secondary_effect_percent / 100.0))

		# Convert Loot to Gold
		self.gold += (loot_won * LOOT_TO_GOLD_CONVERSION) #
		
		# NOTE: GDD states Thralls can be Gold OR Renown.
		# For the MVP, I'll default to Gold. We can add a player choice later.
		self.gold += (thralls_won * THRALL_TO_GOLD_VALUE)
		
		# Apply stress reduction on success
		jarl_manager.apply_raid_result(true)

	else:
		print("RAID FAILED! (RSC: %d)" % rsc)
		
		# Check for GDD failure threshold
		if rsc < 25:
			jarl_manager.apply_raid_result(false)
		else:
			# Raid failed, but not catastrophically, so no stress change.
			pass 

	print("Raid complete. Gold: %d, Renown: %d" % [gold, renown])
	
	# 4. Tell the GameStateManager to return to the Winter phase
	if game_state_manager:
		# This completes the loop, returning control to the management phase.
		game_state_manager.switch_phase(GameStateManager.GamePhase.WINTER)
	else:
		push_error("EconomyManager: GameStateManager reference is not set!")


## Calculates the RSC bonus from the Raid Budget.
## Implements the diminishing returns logic from the GDD.
func calculate_budget_bonus(budget: int) -> int:
	if budget <= 0:
		return 0
	
	# 0-100 Gold: +10% RSC (10G/1%)
	if budget <= 100:
		# Using floating point division ensures we get the correct percentage
		return int(floor(budget / 10.0))
	
	# NOTE: GDD only specifies 0-100 Gold.
	# For now, I will cap the bonus at 10% (100 Gold).
	# We can add more tiers later.
	return 10
