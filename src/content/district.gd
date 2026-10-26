class_name District
extends RefCounted
## A part of the city and the rival cafés in it that can be raided.

var id: String = ""
var rivals: Array[RivalCafe] = []


static func from_dict(values: Dictionary) -> District:
	var district := District.new()
	district.id = values.get("id", "")
	for entry: Variant in values.get("rivals", []):
		if entry is Dictionary:
			district.rivals.append(RivalCafe.from_dict(entry))
	return district


func rival_by_id(rival_id: String) -> RivalCafe:
	for rival: RivalCafe in rivals:
		if rival.id == rival_id:
			return rival
	return null
