class_name UiText
extends RefCounted
## Player-facing text. UI strings live in /locale/ui.csv as translation keys;
## content names (recipes, species, rivals, …) use "name.<id>" keys when the
## CSV has one, else a tidy version of the id ("megabean_kiosk" -> "Megabean Kiosk").


## A GameLoop error code as a sentence for a toast.
static func error(code: String) -> String:
	var key := "error." + code
	var text := TranslationServer.translate(key)
	return code if text == key else text


static func name(id: String) -> String:
	if id == "":
		return ""
	var key := "name." + id
	var text := TranslationServer.translate(key)
	return pretty(id) if text == key else text


## "Rare Swift Boots", or a fashion piece's name.
static func item_name(item: Item) -> String:
	var name := TranslationServer.translate("item." + item.type_id)
	if name == "item." + item.type_id:
		name = pretty(item.type_id)
	if item.kind != Item.EQUIPMENT:
		return name
	return "%s %s" % [TranslationServer.translate("tier." + item.tier), name]


## What a piece does: "+18% speed", "+7 power", or "looks only".
static func item_effect(item: Item, catalog: ItemCatalog) -> String:
	for stat: String in item.bonus(catalog):
		var amount: float = item.bonus(catalog)[stat]
		if stat == "speed" or stat == "appeal":
			return TranslationServer.translate("item.effect_share") % [roundi(amount * 100.0), TranslationServer.translate("stat." + stat)]
		return TranslationServer.translate("item.effect_amount") % [roundi(amount), TranslationServer.translate("stat." + stat)]
	return TranslationServer.translate("item.effect_looks")


static func role(role_id: String) -> String:
	return TranslationServer.translate("role." + role_id)


## "megabean_kiosk" -> "Megabean Kiosk".
static func pretty(id: String) -> String:
	var words := PackedStringArray()
	for word: String in id.split("_", false):
		words.append(word.capitalize())
	return " ".join(words)


## Seconds as m:ss.
static func clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
