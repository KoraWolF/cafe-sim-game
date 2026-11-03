class_name District
extends RefCounted
## A town of the city: its MegaBean bars, and the boss bar (the flagship) that
## opens once every bar has been beaten and whose defeat takes the town over.
## Towns open in the order of /data/districts.json; each bar has a spot on the
## town map, and the first town shows the player's own bar at `home`.

var id: String = ""
var rivals: Array[RivalCafe] = []
## The boss. Raidable once every rival has been beaten (see NightOps.flagship_unlocked).
var flagship: RivalCafe = null
## Kept from when Influence opened the boss; nothing reads it now.
var influence_required: int = 0
## The player's bar on this town's map (a share of the map), or (-1, -1) for none.
var home: Vector2 = Vector2(-1, -1)
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
	var home: Variant = values.get("home", [])
	if home is Array and (home as Array).size() == 2:
		district.home = Vector2(float(home[0]), float(home[1]))
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
