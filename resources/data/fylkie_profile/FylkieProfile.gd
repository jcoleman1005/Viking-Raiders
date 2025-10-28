@tool
class_name FylkiProfile extends Resource

@export_group("Core Fylki Data")
@export var fylki_name: String = "New Fylki" ## The name of the rival clan (e.g., Olaf the Aggressor).
@export var capital_location: String = "North Sea Coast" ## Descriptive location for the Raid Planning Screen.

@export_group("Geopolitical & Raid Risk")
## COMMENT: The RSC penalty applied when raiding this Fylki (e.g., -25 for High Levy).
@export_range(-100, 0, 1) var levy_penalty_rsc: int = 0 
## COMMENT: The maximum Loot a player can acquire from a successful raid against this Fylki (Strategic Reward).
@export var max_loot_potential: int = 50 
@export var min_thralls_potential: int = 0 ## The minimum number of thralls a player can capture (for Abstracted Raid).
@export var max_thralls_potential: int = 10 ## The maximum number of thralls a player can capture.

@export_group("Rival Personality")
## COMMENT: Reference to the JarlTrait resource that describes this rival's nature (e.g., Trait_Warlike.tres).
@export var key_trait: JarlTrait 
