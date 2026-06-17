class_name TrafficManager
extends Node3D

## Spawns and owns the ambient traffic fleet on a RoadGraph. Each car is a full-physics
## TrafficDriver (a Car with an AI at the wheel), placed on a through-street facing its
## first leg and left to drive itself. This first cut populates a fixed number near a
## point; per-player streaming (spawn just out of view, despawn when far, recycle) is
## the next step.

## (model_path, texture_path) pairs — the committed PSX cars, minus car1 (the player's).
const MODELS := [
	["res://assets/vehicles/psx/car2/Car2.obj", ""],
	["res://assets/vehicles/psx/car3/Car3.obj", ""],
	["res://assets/vehicles/psx/car4/Car4.obj", ""],
	["res://assets/vehicles/psx/car5/Car5_Taxi.obj", ""],
	["res://assets/vehicles/psx/car6/Car6.obj", ""],
	["res://assets/vehicles/psx/car8/Car8.obj", ""],
]

var graph: RoadGraph
var cars: Array[TrafficDriver] = []
var _rng := RandomNumberGenerator.new()


## Spawn `count` cars on through-streets (nodes with 2+ links). If `near` is a real
## cell, only cells within `radius` (Chebyshev) are eligible.
func populate(road: RoadGraph, count: int, near := Vector2i(-1, -1), radius := 50) -> void:
	graph = road
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in graph.nodes:
		if ((graph.nodes[cell] as Dictionary).links as Array).size() < 2:
			continue
		if near.x >= 0 and (absi(cell.x - near.x) > radius or absi(cell.y - near.y) > radius):
			continue
		candidates.append(cell)
	if candidates.is_empty():
		push_warning("TrafficManager: no spawn cells found")
		return
	candidates.shuffle()
	var made := 0
	for cell in candidates:
		if made >= count:
			break
		_spawn(cell)
		made += 1


func _spawn(cell: Vector2i) -> void:
	var car := TrafficDriver.new()
	var pair: Array = MODELS[_rng.randi() % MODELS.size()]
	car.model_path = pair[0]
	car.texture_path = pair[1]
	car.graph = graph
	car.start_cell = cell
	add_child(car)

	# Drop it on the road facing a neighbour (Car's hood is -Z, which Basis.looking_at
	# aims at the given direction). A little height so it settles onto its wheels.
	var node: Dictionary = graph.nodes[cell]
	var links: Array = node.links
	var dir := Vector3(0, 0, 1)
	if not links.is_empty():
		var nb: Vector2i = links[_rng.randi() % links.size()]
		var d := Vector3(nb.x - cell.x, 0.0, nb.y - cell.y)
		if d.length() > 0.01:
			dir = d.normalized()
	car.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), node.pos + Vector3(0, 0.3, 0))
	cars.append(car)
