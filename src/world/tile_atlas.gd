class_name TileAtlas
extends RefCounted

## Packs every tile of a GTA1Style into a single square RGBA texture so the whole
## city can be drawn with one material/draw call. `uv_rect(slot)` returns the
## sub-rect for a given global tile index (the same indexing as
## GTA1Style.get_tile_image_global).

const TILE := 64

var texture: ImageTexture
var cols := 1
var rows := 1
var count := 0


static func build(style: GTA1Style) -> TileAtlas:
	var a := TileAtlas.new()
	a.count = style.tile_count()
	a.cols = int(ceil(sqrt(float(a.count))))
	a.rows = int(ceil(float(a.count) / float(a.cols)))

	var img := Image.create(a.cols * TILE, a.rows * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for g in a.count:
		var t := style.get_tile_image_global(g)
		if t == null:
			continue
		img.blit_rect(t, Rect2i(0, 0, TILE, TILE), Vector2i((g % a.cols) * TILE, (g / a.cols) * TILE))

	a.texture = ImageTexture.create_from_image(img)
	return a


## Normalized UV rect (origin top-left) of a tile slot in the atlas.
func uv_rect(slot: int) -> Rect2:
	var col := slot % cols
	var row := slot / cols
	return Rect2(float(col) / cols, float(row) / rows, 1.0 / cols, 1.0 / rows)
