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
- [ ] Solid/heightfield city collision (thin-shell lids let the car sit in slightly)

### Phase 2 — Graphics data
- [ ] `.G24` style parser: tile textures (64×64), palettes
- [ ] Build a tile atlas `Texture2D` for the renderer
- [ ] Sprite extraction (objects/cars) — for reference / future billboards

### Phase 3 — World extrusion
- [x] `MapBuilder`: blocks → `ArrayMesh` (cube faces, tile UVs, face culling)
- [x] `TileAtlas`: pack all tiles into one texture/material
- [x] Offscreen render pipeline (Xvfb + OpenGL3) for headless screenshots
- [x] Slope/ramp geometry (45 block types, ported from OpenGTA slope1_data.h → `src/world/slope_data.gd`)
- [x] Sky + horizon + sea plane + sun/fog (`src/world/scenery.gd`)
- [x] Block rotation (lid 0/90/180/270) + left-right/top-bottom face-flip applied to UVs
- [ ] Static collision from the block grid (`StaticBody3D` / heightmap)
- [ ] Chunk the city so it streams (256×256×6 is ~400k potential cubes)

### Phase 4 — Drive a car  ← milestone ✅ DONE
- [x] Low-poly car model — Kenney Car Kit (CC0) GLB, wheels mounted to VehicleWheel3D
- [x] `VehicleBody3D` with arcade-tuned handling (`src/vehicle/car.gd`)
- [x] Street-level chase camera (`src/app/drive_world.gd`)
- [x] Spawn finder picks a clear street (`src/world/spawn_finder.gd`); car drives (validated)
- [ ] Camera wall-occlusion handling; tune handling feel in-editor
- [ ] Drive toward the model's visual front consistently (sign polish)

### Later
- Pedestrians & traffic (low-poly + simple AI)
- Lighting / ambient occlusion so the extruded city doesn't look flat
- Mission scripting (reverse-engineered GTA1 mission format) — big, optional
- 8-bit `.GRY` path for users with that data variant

## Decisions locked in
- Engine: **Godot 4** (open-source, matches the OpenGTA ethos)
- Cars/peds: **simple 3D models** (GTA1 only ships 2D sprites)
- First playable target: **driving**, not just walking
