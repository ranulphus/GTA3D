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

Early foundation. See [docs/ROADMAP.md](docs/ROADMAP.md).

- [x] GTA1 `.CMP` map parser (`src/formats/gta1_map.gd`) — tested + validated on real maps
- [x] GTA1 `.G24` style/graphics parser (`src/formats/gta1_style.gd`) — tiles/palettes validated on real data
- [x] Map → 3D mesh extruder (`src/world/`) — textured city renders in 3D (NYC: 137k tris)
- [x] Low-poly car (Kenney CC0) + `VehicleBody3D` physics + chase camera + trimesh collision
- [x] **Milestone:** drive a car around a loaded GTA1 city ✅
- [ ] Slope/ramp geometry + block rotation/flip UVs (v1 draws slopes as cubes)
- [ ] Pedestrians, traffic, lighting polish, mission scripting

## Drive it

Open the project in **Godot 4.3+** and press Play (main scene is `scenes/Drive.tscn`),
then drive with the **arrow keys** or **WASD**. It loads a city, extrudes it,
spawns a car on a street, and follows with a chase camera.

Headless validation (no editor needed):

```sh
GODOT=/path/to/godot ./render.sh            # screenshots of the 3D city
GODOT=/path/to/godot xvfb-run -a "$GODOT" --rendering-driver opengl3 \
  --path . --script res://tests/drive_test.gd -- NYC   # proves the car drives
```

## Requirements

- [Godot 4.3+](https://godotengine.org/)
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
src/world/     map → 3D mesh extrusion
src/vehicle/   cars, physics, camera
scenes/        Godot scenes (Main, Car, ...)
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
- Vehicle models are from **[Kenney's Car Kit](https://kenney.nl/assets/car-kit)** (CC0).
File-format knowledge derives from the community OpenGTA project and DMA's
*CityScape Data Structure* documentation.
