@tool
class_name UnitStats extends Resource

@export_group("Unit Identity")
@export var unit_name: String = "Hirdman Warrior" ## Name of the unit type.
@export var recruitment_cost: int = 50 ## Gold cost to hire this unit during the Winter Phase.

@export_group("Combat Statistics")
@export var health: float = 100.0 ## Hit points for the full RTS implementation.
@export var damage: float = 15.0 ## Damage per attack.
@export var speed: float = 5.0 ## Movement speed on the RTS map.

@export_group("RTS Logistics")
@export var loot_capacity: int = 5 ## How much loot this unit can carry back to the Longship.
