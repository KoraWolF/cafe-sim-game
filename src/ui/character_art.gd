class_name CharacterArt
extends RefCounted
## Rigged characters: cut-out animation on one shared chibi rig (see
## docs/art-guide.md). A customer type's body parts are in
## art/characters/customers/<type>/, a Synth species' tech parts in
## art/characters/synths/<species>/ (made by tools/art/character_parts.py). A
## Synth is its customer type's body plus its species' parts (its arm_front
## replaces the customer's, and it has no prop). Every part is drawn on the same
## 256 x 440 canvas with the feet at (128, 430), so the bones only rotate
## parts about their joints.
##
## Animations are functions of time, so any number of characters share them:
## idle, walk, carry, sit, eat, cook, rest, happy, angry, and for battles
## attack, cast, hurt and down. A character with no art keeps its placeholder.

## Canvas of every part, and where the feet are on it.
const CANVAS := Vector2(256, 440)
const FEET := Vector2(128, 430)
## The SVGs are imported at half their canvas (svg/scale in their .import files).
const IMPORT_SCALE: float = 0.5
## World pixels per canvas pixel in the café (a character about 97 px tall).
const SIZE: float = 0.22
## The joints (canvas).
const HIPS := Vector2(128, 340)
const NECK := Vector2(130, 244)
const SHOULDER_BACK := Vector2(72, 262)
const SHOULDER_FRONT := Vector2(190, 262)
const HIP_BACK := Vector2(113, 340)
const HIP_FRONT := Vector2(150, 340)
## The head's centre and the front hand (canvas), for overlays and props.
const HEAD_CENTRE := Vector2(130, 150)
const HAND_FRONT := Vector2(198, 344)

static var _parts: Dictionary[String, Texture2D] = {}
static var _missing: Dictionary[String, bool] = {}


## The customer type a Synth species came from (its body), or "".
static func body_of(species_id: String, data: GameData) -> String:
	for type: CustomerType in data.customer_types.values():
		if type.synth_species == species_id:
			return type.id
	return ""


## Whether a customer type has art (and, for a Synth, its species too; type_id
## is then the species' body, see body_of).
static func has_art(type_id: String, species_id := "") -> bool:
	if species_id != "" and _part("synths/" + species_id, "visor") == null:
		return false
	return type_id != "" and _part("customers/" + type_id, "torso") != null


## Draws a character with its feet at `feet` on canvas, `size` world px per
## canvas px, posed by pose: {"anim", "t" (seconds into it), "face" ("neutral",
## "happy", "angry", "eat", "rest"), "mirror" (facing left), "tint", "glow"
## (species colour)}. Returns the head's centre (for clicks and overlays).
static func draw(canvas: CanvasItem, feet: Vector2, size: float, type_id: String, species_id: String, pose: Dictionary) -> Vector2:
	var body := "customers/" + type_id
	var tech := "synths/" + species_id if species_id != "" else ""
	var bones := _pose(pose.get("anim", "idle"), float(pose.get("t", 0.0)))
	var tint: Color = pose.get("tint", Color.WHITE)
	var mirror := -1.0 if pose.get("mirror", false) else 1.0
	var base := Transform2D(0.0, feet) * Transform2D(0.0, Vector2(size * mirror, size), 0.0, Vector2.ZERO) \
		* Transform2D(0.0, -FEET)
	# Knocked down: the whole body tips over at the feet.
	base = base * _about(FEET, bones["fall"])
	var root := base * Transform2D(0.0, bones["lift"])
	var torso := root * _about(HIPS, bones["torso"])
	var head := torso * _about(NECK, bones["head"])
	var legs := Vector2(1.0, bones["legs"])
	_put(canvas, base, body, "shadow", Color(tint, tint.a * (1.0 - absf(bones["fall"]) * 0.4)))
	if tech != "":
		_put(canvas, root, tech, "glow", pose.get("glow", Color.WHITE) * Color(1, 1, 1, tint.a))
	_put(canvas, root * _about(HIP_BACK, bones["leg_back"], legs), body, "leg_back", tint)
	_put(canvas, torso * _about(SHOULDER_BACK, bones["arm_back"]), body, "arm_back", tint)
	_put(canvas, root * _about(HIP_FRONT, bones["leg_front"], legs), body, "leg_front", tint)
	_put(canvas, torso, body, "torso", tint)
	var arm := torso * _about(SHOULDER_FRONT, bones["arm_front"])
	if tech != "":
		_put(canvas, arm, tech, "arm_front", tint)
	else:
		_put(canvas, arm, body, "arm_front", tint)
		if bones["prop"]:
			_put(canvas, arm, body, "prop", tint)
	if bones["tray"]:
		_draw_tray(canvas, arm * HAND_FRONT, size)
	_put(canvas, head, body, "head", tint)
	var face: String = "face_" + str(pose.get("face", "neutral"))
	if tech == "" or face != "face_neutral":
		_put(canvas, head, body, face if _part(body, face) != null else "face_neutral", tint)
	_put(canvas, head, body, "hair", tint)
	if tech != "":
		_put(canvas, head, tech, "visor", tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return head * HEAD_CENTRE


## The bones for an animation t seconds in: rotations (radians), the body's
## lift (canvas px), the legs' length (1 = standing), the fall, and whether
## the prop and a tray are shown.
static func _pose(anim: String, t: float) -> Dictionary:
	var bones := {"lift": Vector2.ZERO, "torso": 0.0, "head": 0.0, "arm_back": 0.0, "arm_front": 0.0,
		"leg_back": 0.0, "leg_front": 0.0, "legs": 1.0, "fall": 0.0, "prop": true, "tray": false}
	var breathe := sin(t * 2.4)
	bones["lift"] = Vector2(0, breathe * 2.0)
	bones["head"] = sin(t * 1.3) * 0.03
	bones["arm_back"] = 0.04 + breathe * 0.03
	bones["arm_front"] = -0.04 - breathe * 0.03
	match anim:
		"walk", "move", "carry":
			var step := sin(t * 10.0)
			bones["lift"] = Vector2(0, -absf(cos(t * 10.0)) * 9.0)
			bones["leg_back"] = step * 0.42
			bones["leg_front"] = -step * 0.42
			bones["arm_back"] = -step * 0.35
			bones["arm_front"] = step * 0.35
			bones["torso"] = 0.03
			if anim == "carry":
				bones["arm_front"] = -1.05
				bones["arm_back"] = 0.9
				bones["prop"] = false
				bones["tray"] = true
		"carry_still":
			bones["arm_front"] = -1.05
			bones["arm_back"] = 0.9
			bones["prop"] = false
			bones["tray"] = true
		"sit", "eat":
			bones["lift"] = Vector2(0, 40.0 + breathe * 1.5)
			bones["legs"] = 0.5
			bones["prop"] = false
			if anim == "eat":
				# Fork to mouth and back, about once a second.
				bones["arm_front"] = 2.3 * (0.5 + 0.5 * sin(t * 5.0))
				bones["head"] = 0.06 * sin(t * 5.0)
		"cook":
			bones["arm_front"] = -0.7 + 0.3 * sin(t * 8.0)
			bones["arm_back"] = 0.5 + 0.15 * sin(t * 8.0 + 1.0)
			bones["prop"] = false
		"rest":
			bones["lift"] = Vector2(0, sin(t * 1.2) * 1.5)
			bones["head"] = 0.12
			bones["prop"] = false
		"happy":
			bones["lift"] = Vector2(0, -absf(sin(t * 7.0)) * 26.0)
			bones["arm_front"] = -2.5
			bones["arm_back"] = 2.5
			bones["prop"] = false
		"angry":
			var stomp := sin(t * 12.0)
			bones["lift"] = Vector2(0, -absf(stomp) * 6.0)
			bones["leg_back"] = stomp * 0.3
			bones["leg_front"] = -stomp * 0.3
			bones["arm_front"] = 0.25
			bones["arm_back"] = -0.25
			bones["head"] = 0.08 * sin(t * 18.0)
		"attack":
			var swing := sin(PI * clampf(t / 0.35, 0.0, 1.0))
			bones["torso"] = 0.22 * swing
			bones["arm_front"] = -2.2 * swing
			bones["prop"] = false
		"cast":
			bones["arm_front"] = -2.6
			bones["arm_back"] = 2.6
			bones["lift"] = Vector2(0, -10.0)
			bones["prop"] = false
		"hurt":
			bones["torso"] = -0.18
			bones["head"] = -0.15
			bones["prop"] = false
		"down":
			bones["fall"] = -1.45
			bones["prop"] = false
	return bones


## A part's texture, or null if that character has no such part.
static func _part(folder: String, name: String) -> Texture2D:
	var path := "res://art/characters/%s/%s.svg" % [folder, name]
	if _parts.has(path):
		return _parts[path]
	if _missing.has(path):
		return null
	if not ResourceLoader.exists(path):
		_missing[path] = true
		return null
	_parts[path] = load(path)
	return _parts[path]


static func _put(canvas: CanvasItem, xform: Transform2D, folder: String, name: String, tint: Color) -> void:
	var texture := _part(folder, name)
	if texture == null:
		return
	canvas.draw_set_transform_matrix(xform)
	canvas.draw_texture_rect(texture, Rect2(Vector2.ZERO, CANVAS), false, tint)


## A turn of angle about a point, with a scale (about the same point).
static func _about(point: Vector2, angle: float, scale := Vector2.ONE) -> Transform2D:
	return Transform2D(0.0, point) * Transform2D(angle, scale, 0.0, Vector2.ZERO) * Transform2D(0.0, -point)


## A round tray with a cup, held at the front hand (world).
static func _draw_tray(canvas: CanvasItem, hand: Vector2, size: float) -> void:
	canvas.draw_set_transform(hand + Vector2(0, -6) * size / SIZE, 0.0, Vector2(1.0, 0.4) * size / SIZE)
	canvas.draw_circle(Vector2.ZERO, 14.0, Color("d9dde8"))
	canvas.draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 20, Color("6b7390"), 2.0)
	canvas.draw_set_transform(hand + Vector2(0, -14) * size / SIZE, 0.0, Vector2.ONE * size / SIZE)
	canvas.draw_rect(Rect2(Vector2(-5, -6), Vector2(10, 9)), Color("f1e4cc"))
	canvas.draw_rect(Rect2(Vector2(-5, -6), Vector2(10, 9)), Color("8a5a3c"), false, 1.5)
