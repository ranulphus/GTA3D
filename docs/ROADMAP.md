# Roadmap

Goal: **drive a car, street-level, around a real GTA1 city** rendered in 3D.

### Phase 1 — Map data ✅
- [x] `.CMP` map parser → 256×256 grid of stacked blocks
- [x] Headless test with synthetic data (no copyrighted files)
- [x] Correct column decode = `getBlockAtNew` (N = 6 − offset, top-to-bottom).
      The legacy count-based decode hid all buildings and left gaps.

### Engine / UX
- [x] Godot **4.6** (AGX tonemapping)
- [x] Free-fly camera mode (toggle **F**, mouse-look, WASD/Q-E, Shift boost) + HUD
- [x] Solid city collision — multi-surface trimesh (`MapBuilder.build_collision`):
      drivable lids + ramps + building/kerb/sea walls, two-sided so nothing tunnels.
      Replaces the single-height heightfield, so a car can drive **under** bridges
      and building overhangs as well as over them.

- [x] [Esc] pause menu (`src/ui/pause_menu.gd`)
- [x] Tile inspector ([I] in fly mode) + crosshair tile readout

### Phase 2 — Graphics data ✅
- [x] `.G24` style parser: tile textures (64×64), palettes (`src/formats/gta1_style.gd`)
- [x] Build a tile atlas `Texture2D` for the renderer (`src/world/tile_atlas.gd`)
- [ ] Sprite extraction (objects/cars) — for reference / future billboards

### Phase 3 — World extrusion
- [x] `MapBuilder`: blocks → `ArrayMesh` (cube faces, tile UVs, face culling)
- [x] `TileAtlas`: pack all tiles into one texture/material
- [x] Offscreen render pipeline (Xvfb + OpenGL3) for headless screenshots
- [x] Slope/ramp geometry (45 block types, ported from OpenGTA slope1_data.h → `src/world/slope_data.gd`)
- [x] Sky + horizon + sea plane + sun/fog (`src/world/scenery.gd`)
- [x] Block rotation (lid 0/90/180/270) + flip_left_right E/W-wall face-flip applied to UVs (un-reverses banners like "General HOSPITAL", the DOCKS signs; N/S faces read correct without a flip)
- [x] Static collision from the block grid (`StaticBody3D` + `ConcavePolygonShape3D`)
- [ ] Chunk the city so it streams (256×256×6 is ~400k potential cubes)

### Phase 4 — Drive a car  ← milestone ✅ DONE
- [x] Low-poly cars — PSX Style Cars by ggbot (CC0); single-mesh bodies with a
      shared wheel model mounted on VehicleWheel3D (`src/vehicle/car.gd`)
- [x] `VehicleBody3D` with arcade-tuned handling; hood faces drive-forward, [C] cycles models
- [x] Street-level chase camera (`src/app/drive_world.gd`)
- [x] Spawn finder picks a clear street (`src/world/spawn_finder.gd`); car drives (validated)
- [x] Wall-aware chase camera with speed zoom
- [x] Self-righting after tips/crashes; tight low-speed steering; stronger brakes
- [x] Water: animated rivers/harbour; cars float, sink (~10s death-cam) and respawn
- [ ] Tune handling feel in-editor

### Phase 5 — Pedestrians ✅
- [x] On-foot mode: walk/run, get in/out of cars ([Enter]) (`src/character/pedestrian.gd`)
- [x] Mixamo idle/walk/run animation at natural cadence

### Phase 6 — Traffic  ← in progress
- [x] Road graph from the map (`src/world/road_graph.gd`), classified by the real
      carriageway tiles, incl. bridges/overpasses and roads under walkways
- [x] Road-map overlay ([G]): direction arrows per link, markers at junctions
- [x] AI drivers + traffic manager (`src/vehicle/traffic_driver.gd`, `src/world/traffic_manager.gd`)
- [ ] Rework driving as the planned hybrid system on the verified road map
- [ ] Re-enable traffic spawning (currently off in `drive_world.gd`)

### Later
- Lighting / ambient occlusion so the extruded city doesn't look flat
- Mission scripting (reverse-engineered GTA1 mission format) — big, optional
- 8-bit `.GRY` path for users with that data variant

## Decisions locked in
- Engine: **Godot 4** (open-source, matches the OpenGTA ethos)
- Cars/peds: **simple 3D models** (GTA1 only ships 2D sprites)
- First playable target: **driving**, not just walking
