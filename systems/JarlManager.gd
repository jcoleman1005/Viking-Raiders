extends Node

# Manages the Jarl's personal stats, particularly Stress and Trait acquisition.

const STRESS_THRESHOLD: int = 70
const STRESS_ON_SUCCESS: int = -20
const STRESS_ON_FAILURE: int = 30

signal stress_changed(new_stress: int)
signal trait_acquired(trait_resource) # We'll pass the actual trait resource later
signal jarl_is_stressed(jarl_stress: int)

var jarl_name: String = "Harald Bluetooth"
var jarl_traits: Array = [] # This will hold JarlTrait custom resources

var stress: int = 25:
	set(value):
		var new_stress = clamp(value, 0, 100)
		if stress != new_stress:
			stress = new_stress
			stress_changed.emit(stress)
			print("Jarl stress is now: %d" % stress)
			if stress >= STRESS_THRESHOLD:
				jarl_is_stressed.emit(stress)
				# In a full implementation, this signal would be connected
				# to a system that triggers a crisis event.
				print("Jarl has reached the stress threshold!")


func _ready() -> void:
	print("JarlManager ready.")


func apply_raid_result(raid_successful: bool) -> void:
	"""
	Applies the stress effect of a raid's outcome.
	"""
	if raid_successful:
		self.stress += STRESS_ON_SUCCESS
		print("Raid was successful. Jarl is pleased. Stress reduced.")
	else:
		self.stress += STRESS_ON_FAILURE
		print("Raid failed. Jarl is furious. Stress increased.")


func add_trait(trait_resource) -> void:
	"""
	Adds a new trait to the Jarl. This would be called by an event system.
	The 'trait_resource' should be a custom resource of type JarlTrait.
	"""
	if not jarl_traits.has(trait_resource):
		jarl_traits.append(trait_resource)
		trait_acquired.emit(trait_resource)
		print("Jarl acquired new trait: %s" % trait_resource.trait_name)
		# Add logic here to apply the trait's modifiers from the resource
	else:
		print("Jarl already has the trait: %s" % trait_resource.trait_name)


func get_total_rsc_modifier_from_traits() -> float:
	"""
	Calculates the sum of all Raid Success Chance (RSC) modifiers
	from the Jarl's current traits.
	"""
	var total_modifier: float = 0.0
	for trait in jarl_traits:
		if trait and trait.has("rsc_modifier"):
			total_modifier += trait.rsc_modifier
	return total_modifier
