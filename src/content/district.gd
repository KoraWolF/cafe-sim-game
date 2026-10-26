class_name District
extends RefCounted
## A part of the city: the rival cafés that can be raided for Influence, and the
## MegaBean flagship whose defeat takes the district over. Districts open in
## the order of /data/districts.json.

var id: String = ""
var rivals: Array[RivalCafe] = []
## The boss. Raidable once the district's Influence reaches influence_required.
var flagship: RivalCafe = null
var influence_required: int = 0
## Coins an owned district pays every night.
var income: int = 0


static func from_dict(values: Dictionary) -> District:
	var district := District.new()
	district.id = values.get("id", "")
	for entry: Variant in values.get("rivals", []):
		if entry is Dictionary:
			district.rivals.append(RivalCafe.from_dict(entry))
	var flagship: Variant = values.get("flagship")
	if flagship is Dictionary:
		district.flagship = RivalCafe.from_dict(flagship)
	district.influence_required = int(values.get("influence_required", 0))
	district.income = int(values.get("income", 0))
	return district


## A rival or the flagship.
func rival_by_id(rival_id: String) -> RivalCafe:
	for rival: RivalCafe in rivals:
		if rival.id == rival_id:
			return rival
	if flagship != null and flagship.id == rival_id:
		return flagship
	return null


func is_flagship(rival_id: String) -> bool:
	return flagship != null and flagship.id == rival_id
