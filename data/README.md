# Put your original GTA1 data files here

This folder is **git-ignored** — GTA1 assets are copyright DMA Design / Rockstar
Games and must not be committed or redistributed.

The original *Grand Theft Auto* has been distributed for free by Rockstar; obtain
your own copy and copy the data files here, for example:

```
data/
  NYC.CMP        # Liberty City map
  SANB.CMP       # San Andreas map
  MIAMI.CMP      # Vice City map
  STYLE001.G24   # 24-bit graphics/style for a level
  ...            # (.GRY for the 8-bit variant)
```

Exact filenames depend on your distribution. Once files are here, GTA3D can load
a city. Until then, the parser test (`tests/test_gta1_map.gd`) runs on synthetic
data and needs none of these.
