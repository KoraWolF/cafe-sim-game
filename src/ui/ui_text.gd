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
