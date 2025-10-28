@tool
class_name JarlTrait extends Resource

## Enum for the secondary effect type, used for resource calculation in EconomyManager.
enum SecondaryEffectType {
	NONE,
	LOOT,
	THRALLS,
	RENOWN
}

@export_group("Core Trait Definition")
@export var trait_name: String = "New Trait" ## The human-readable name of the trait (e.g., Brave, Cowardly).
## COMMENT: Using a multiplier for stress allows the JarlManager to easily adjust stress behavior.
@export_range(-1.0, 1.0, 0.01) var stress_rate_multiplier: float = 1.0 

@export_group("Raid Success Modifiers (RSC)")
## COMMENT: The percentage added or subtracted from the base Raid Success Chance (e.g., +15 for Brave).
@export_range(-100, 100, 1) var rsc_modifier_percent: int = 0 

@export_group("Secondary Resource Modifiers")
## COMMENT: Which resource output this trait affects (Loot, Thralls, or Renown).
@export var secondary_effect_type: SecondaryEffectType = SecondaryEffectType.NONE 
## COMMENT: The percentage increase or decrease applied to the final resource output (e.g., +10 for Loot Acquired).
@export_range(-100, 100, 1) var secondary_effect_percent: int = 0 
