extends Node

## E2.2/E2.3. The roster must actually be 72 unique, correctly-numbered
## entries, and the original seals must be tied to real subjects this world
## already built rather than floating free of them.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	check(GoeticSeals.GOETIA.size() == 72, "the Goetia roster has exactly 72 entries (%d)" % GoeticSeals.GOETIA.size())

	var numbers := {}
	var names := {}
	for entry in GoeticSeals.GOETIA:
		var number := int(entry.number)
		numbers[number] = true
		names[str(entry.name).to_lower()] = true
		check(str(entry.get("name", "")) != "", "entry %d has a name" % number)
		check(str(entry.get("rank", "")) != "", "entry %d has a rank" % number)
	check(numbers.size() == 72, "all 72 numbers are unique")
	for expected in range(1, 73):
		check(numbers.has(expected), "number %d is present" % expected)
	check(names.size() == 72, "all 72 names are unique")

	check(GoeticSeals.seal(1).name == "Bael", "seal(1) is Bael")
	check(GoeticSeals.seal(72).name == "Andromalius", "seal(72) is Andromalius")
	check(GoeticSeals.seal(999).is_empty(), "an out-of-range lookup returns nothing rather than crashing")
	check(GoeticSeals.by_name("bael").rank == "King", "by_name() is case-insensitive and reads the Goetia")

	# --- E2.3: original seals are tied to real subjects, not invented free-floating names
	check(not GoeticSeals.ORIGINAL.is_empty(), "there is at least one original seal")
	for entry in GoeticSeals.ORIGINAL:
		var faction_id := str(entry.get("faction_id", ""))
		var entity_id := str(entry.get("entity_id", ""))
		check(faction_id != "" or entity_id != "", "%s is tied to a real faction or entity id, not floating free" % str(entry.get("name", entry.get("id", ""))))

	var marrow_seals := GoeticSeals.original_for_faction("choir_of_marrow")
	check(marrow_seals.size() >= 1, "the Choir of Marrow has at least one original seal")
	var clear_frequency_seal := GoeticSeals.original_for_entity("clear_frequency")
	check(str(clear_frequency_seal.get("name", "")) != "", "The Clear Frequency (a real AscentEntities entry) has its own original seal")
	check(GoeticSeals.by_name("the marrow-keeper").faction_id == "choir_of_marrow", "by_name() also resolves an original seal")

	print("GOETIC_SEALS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
