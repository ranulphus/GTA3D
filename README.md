# GTA3D

An open-source, **street-level (3D)** re-imagining of the original *Grand Theft Auto* (1997).

The original GTA was rendered with a top-down camera, but its world data is
actually a full 3D grid of textured cubes. GTA3D reads the **original GTA1 game
data files** and extrudes that grid into real 3D geometry, then drops a
GTA III–style chase camera into the streets — the game DMA Design's data always
described, viewed the way later GTAs would render it.

In the spirit of [OpenGTA](https://github.com/madebr/OpenGTA): bring your own
original data files, no copyrighted assets are redistributed here.

## Status

Playable: you can drive and walk around a real GTA1 city. Ambient traffic is
being reworked. See [docs/ROADMAP.md](docs/ROADMAP.md).

- [x] GTA1 `.CMP` map parser (`src/formats/gta1_map.gd`), tested and validated on real maps
- [x] GTA1 `.G24` style/graphics parser (`src/formats/gta1_style.gd`), tiles and palettes validated on real data
- [x] Map → 3D mesh extruder (`src/world/`): textured city with slopes/ramps, block rotation and flip UVs
- [x] Sky, sea, sun/fog, and animated river/harbour water (cars float, sink and respawn)
- [x] Solid trimesh collision, so you can drive over *and under* bridges and overhangs
- [x] Low-poly PSX-style cars (ggbot, CC0) on `VehicleBody3D`, with self-righting and a wall-aware chase camera
- [x] **Milestone:** drive a car around a loaded GTA1 city ✅
- [x] On foot: walk/run with Mixamo animations, get in and out of cars
- [x] Pause menu, free-fly camera, tile inspector, road-map overlay
- [~] Ambient traffic: road graph and AI drivers built, but spawning is off while the road map is verified
- [ ] City streaming/chunking, lighting/AO polish, mission scripting

## Drive it

Open the project in **Godot 4.6+** and press Play (main scene is `scenes/Drive.tscn`).
It loads a city, extrudes it, spawns a car on a street, and follows with a chase camera.

| Key | Action |
|---|---|
| Arrows / WASD | Drive, or walk on foot (Shift runs) |
| Enter | Get in / out of a car |
| C | Cycle car model |
| F | Toggle free-fly camera (WASD, Q/E down/up, Shift boost) |
| G | Toggle the road-map overlay (direction arrows + junctions) |
| I | Tile inspector (in fly mode) |
| Esc | Pause menu |

Headless validation (no editor needed):

```sh
GODOT=/path/to/godot ./render.sh            # screenshots of the 3D city
GODOT=/path/to/godot xvfb-run -a "$GODOT" --rendering-driver opengl3 \
  --path . --script res://tests/drive_test.gd -- NYC   # proves the car drives
```

## Requirements

- [Godot 4.6+](https://godotengine.org/)
- Your own original **GTA1 data files** (the game is available as free download;
  see below). Place the level files (e.g. `NYC.CMP`, `SANB.CMP`, `MIAMI.CMP`)
  and their matching style files (`*.G24` / `*.GRY`) under [`data/`](data/).

## Running the tests (no game data needed)

```sh
godot --headless --path . --script res://tests/test_gta1_map.gd
```

## Project layout

```
src/formats/   parsers for GTA1 file formats (.CMP map, .G24/.GRY style)
src/world/     map → 3D mesh extrusion, collision, water, scenery, road graph, traffic
src/vehicle/   cars, physics, AI traffic driver
src/character/ on-foot pedestrian
src/app/       game loop, cameras, HUD
src/ui/        pause menu
scenes/        Godot scenes (Drive, Car, ...)
tests/         headless GDScript tests
data/          <-- you put your original GTA1 files here (git-ignored)
docs/          format reference & roadmap
```

## License & credits

Engine code is licensed under **Apache License 2.0** (see [LICENSE](LICENSE)).

- The original GTA data files are copyright **DMA Design / Rockstar Games** and
  are **not** included or redistributed — bring your own (see [data/](data/)).
- File-format knowledge derives from the community **[OpenGTA](https://github.com/madebr/OpenGTA)**
  project and DMA's *CityScape Data Structure* docs. The slope geometry table is
  ported from OpenGTA's `slope1_data.h` (zlib-licensed).
- Vehicle models are the **[PSX Style Cars by ggbot](https://ggbot.itch.io/psx-style-cars)** (CC0).
File-format knowledge derives from the community OpenGTA project and DMA's
*CityScape Data Structure* documentation.
