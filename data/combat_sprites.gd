extends RefCounted

# Trocar um retrato exige apenas substituir o PNG correspondente.
const TEXTURES := {
	"guerreiro": preload("res://assets/combat_sprites/guerreiro.png"),
	"patrulheiro": preload("res://assets/combat_sprites/patrulheiro.png"),
	"bruxa": preload("res://assets/combat_sprites/bruxa.png"),
	"sacerdotisa": preload("res://assets/combat_sprites/sacerdotisa.png"),
	"feiticeiro": preload("res://assets/combat_sprites/feiticeiro.png"),
	"goblin": preload("res://assets/combat_sprites/goblin.png"),
	"esqueleto": preload("res://assets/combat_sprites/esqueleto.png"),
	"orc": preload("res://assets/combat_sprites/orc.png"),
	"cultista": preload("res://assets/combat_sprites/cultista.png"),
	"guardiao": preload("res://assets/combat_sprites/guardiao.png"),
}

const SIDE_TEXTURES := {
	"guerreiro": preload("res://assets/combat_sprites/guerreiro_lado.png"),
	"patrulheiro": preload("res://assets/combat_sprites/patrulheiro_lado.png"),
	"bruxa": preload("res://assets/combat_sprites/bruxa_lado.png"),
	"sacerdotisa": preload("res://assets/combat_sprites/sacerdotisa_lado.png"),
	"feiticeiro": preload("res://assets/combat_sprites/feiticeiro_lado.png"),
}

static var _idle_frames: Dictionary = {}


static func texture_for(fighter_id: String) -> Texture2D:
	return TEXTURES.get(_base_fighter_id(fighter_id))


static func side_texture_for(hero_id: String) -> Texture2D:
	return SIDE_TEXTURES.get(_base_fighter_id(hero_id))


static func _base_fighter_id(fighter_id: String) -> String:
	var separator: int = fighter_id.rfind("_")
	if separator < 0:
		return fighter_id
	var suffix: String = fighter_id.substr(separator + 1)
	return fighter_id.substr(0, separator) if suffix.is_valid_int() else fighter_id


static func idle_frames_for(fighter_id: String) -> Array[Texture2D]:
	if _idle_frames.has(fighter_id):
		return _idle_frames[fighter_id]
	var base: Texture2D = side_texture_for(fighter_id)
	if base == null:
		base = texture_for(fighter_id)
	var frames: Array[Texture2D] = []
	if base == null:
		return frames
	frames.append(base)
	var source: Image = base.get_image()
	source.convert(Image.FORMAT_RGBA8)
	for phase in [1, 2]:
		var frame: Image = Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		for y in source.get_height():
			for x in source.get_width():
				var pixel: Color = source.get_pixel(x, y)
				if pixel.a < 0.1:
					continue
				var destination := Vector2i(x, y)
				# Only the upper silhouette breathes; the feet remain on the same pixels.
				if y >= 3 and y <= 10:
					if phase == 1:
						destination.y -= 1
					else:
						destination.x += 1
				if destination.x >= 0 and destination.x < source.get_width() and destination.y >= 0 and destination.y < source.get_height():
					frame.set_pixelv(destination, pixel)
		frames.append(ImageTexture.create_from_image(frame))
	_idle_frames[fighter_id] = frames
	return frames
