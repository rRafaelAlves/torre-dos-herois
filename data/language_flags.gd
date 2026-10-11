extends RefCounted


static func texture_for(locale: String) -> Texture2D:
	var image := Image.create(32, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color("1b2028"))
	for y in range(18):
		for x in range(30):
			image.set_pixel(x + 1, y + 1, _pixel_for(locale, x, y))
	return ImageTexture.create_from_image(image)


static func _pixel_for(locale: String, x: int, y: int) -> Color:
	match locale:
		"pt_BR":
			var green := Color("16804a")
			if absf(float(x) - 14.5) / 12.5 + absf(float(y) - 8.5) / 7.0 > 1.0:
				return green
			if pow(float(x) - 14.5, 2.0) + pow(float(y) - 8.5, 2.0) <= 24.0:
				if absf(float(y) - (8.5 + (float(x) - 14.5) * 0.32)) < 0.85:
					return Color("f5f4df")
				return Color("264c9a")
			return Color("f1c74c")
		"en":
			var first_diagonal: float = absf(float(y) - float(x) * 17.0 / 29.0)
			var second_diagonal: float = absf(float(y) - (17.0 - float(x) * 17.0 / 29.0))
			if x in range(13, 17) or y in range(7, 11):
				return Color("c33748")
			if x in range(11, 19) or y in range(5, 13):
				return Color("f4f0e4")
			if minf(first_diagonal, second_diagonal) < 1.1:
				return Color("c33748")
			if minf(first_diagonal, second_diagonal) < 2.2:
				return Color("f4f0e4")
			return Color("244579")
		"fr":
			return Color("2555a4") if x < 10 else (Color("f5f1e8") if x < 20 else Color("df4b50"))
		"ja":
			return Color("bd3047") if pow(float(x) - 14.5, 2.0) + pow(float(y) - 8.5, 2.0) <= 27.0 else Color("f5f1e8")
		"es":
			if y < 5 or y >= 13:
				return Color("bb3342")
			if x in range(8, 11) and y in range(7, 12):
				return Color("bb3342")
			if x == 9 and y == 6:
				return Color("f8efda")
			return Color("f4c84a")
		"zh_CN":
			if (x in range(5, 8) and y in range(3, 10)) or (y in range(5, 8) and x in range(3, 10)) or (x == 4 and y in [4, 8]) or (x == 8 and y in [4, 8]):
				return Color("f6d154")
			if Vector2i(x, y) in [Vector2i(12, 2), Vector2i(15, 4), Vector2i(15, 8), Vector2i(12, 10)]:
				return Color("f6d154")
			return Color("c82f43")
	return Color("30404d")
