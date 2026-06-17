class_name TrafficManager
extends Node3D

## Spawns and owns the ambient traffic fleet on a RoadGraph. This first cut simply
## populates a fixed number of cars on random through-streets near a point and lets
## each drive itself; per-player streaming (spawn just out of view, despawn when far,
## recycle) is the next step once the driving reads right.
##
## In game each TrafficCar self-drives from its own _physics_process. tick(delta) is
## here only so a test can step the whole fleet deterministically (cars spawned with
## auto = false).

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
var cars: Array[TrafficCar] = []
var _rng := RandomNumberGenerator.new()


## Spawn `count` cars on through-streets (nodes with 2+ links). If `near` is a real
## cell, only cells within `radius` (Chebyshev) are eligible. `auto` toggles whether
## the cars self-drive (game) or wait to be stepped via tick() (tests).
func populate(road: RoadGraph, count: int, near := Vector2i(-1, -1), radius := 50, auto := true) -> void:
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
	var used := {}
	var made := 0
	for cell in candidates:
		if made >= count:
			break
		if used.has(cell):
			continue
		used[cell] = true
		_spawn(cell, auto)
		made += 1


func _spawn(cell: Vector2i, auto: bool) -> void:
	var car := TrafficCar.new()
	var pair: Array = MODELS[_rng.randi() % MODELS.size()]
	car.model_path = pair[0]
	car.texture_path = pair[1]
	car.graph = graph
	car.start_cell = cell
	car.auto = auto
	add_child(car)
	cars.append(car)


## Step every car once — tests only (cars spawned with auto = false).
func tick(delta: float) -> void:
	for c in cars:
		c.tick(delta)
