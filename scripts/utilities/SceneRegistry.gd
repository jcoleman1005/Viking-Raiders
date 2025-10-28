@tool
class_name SceneRegistry extends Resource
## A central data resource for holding and tracking all core scene files.
## This allows us to change scenes without using "magic string" paths,
## and it allows the Director to assign scenes in the Inspector.

@export_group("Core Loop Scenes")
@export var winter_scene: PackedScene ## Drag res://scenes/gs_winter/WinterScene.tscn here.
@export var summer_scene: PackedScene ## Drag res://scenes/rts_summer/SummerScene.tscn here.

# We can add other scenes here later (e.g., MainMenu, Credits)
