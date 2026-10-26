class_name AdjacencyRule
extends RefCounted
## Extra Vibe for every pair of touching pieces where one has tag_a and the
## other has tag_b (either way round; for tag_a == tag_b both need it).

var tag_a: String = ""
var tag_b: String = ""
var vibe: float = 0.0


static func from_dict(values: Dictionary) -> AdjacencyRule:
	var rule := AdjacencyRule.new()
	var tags: Variant = values.get("tags", [])
	if tags is Array and tags.size() == 2:
		rule.tag_a = str(tags[0])
		rule.tag_b = str(tags[1])
	rule.vibe = float(values.get("vibe", 0.0))
	return rule


func matches(a: Piece, b: Piece) -> bool:
	return (a.tags.has(tag_a) and b.tags.has(tag_b)) or (a.tags.has(tag_b) and b.tags.has(tag_a))
