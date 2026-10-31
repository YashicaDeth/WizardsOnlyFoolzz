class_name ArtGallery
extends RefCounted
## Greg, 29 September: "an in-game art gallery ... from posters and business
## cards and different things you can click on and add to your art gallery",
## kept as a digital gallery in the Brain Index. Every piece is Greg's own art
## (Desktop/Art Collections), brought in at game size under art/gallery/.
## Posters are torn from walls (a tab comes away), cards are picked up;
## either way the piece lands here, once, and stays with the save.

const SUBJECT := "art_gallery"
## id -> title, file, and how it is found in the world.
const PIECES := {
	"cellout_wizards": {"title": "CELLOUT // WIZARDS ONLY FOOLS", "file": "res://art/gallery/cellout_wizards.jpg", "kind": "poster"},
	"war_time": {"title": "WAR TIME", "file": "res://art/gallery/war_time.jpg", "kind": "poster"},
	"spitrost": {"title": "SPITROST", "file": "res://art/gallery/spitrost.jpg", "kind": "poster"},
	"powers_that_be": {"title": "POWERS THAT BE", "file": "res://art/gallery/powers_that_be.jpg", "kind": "poster"},
	"cover_me_in_moss": {"title": "COVER ME IN MOSS", "file": "res://art/gallery/cover_me_in_moss.jpg", "kind": "poster"},
	"mirror_hands": {"title": "MIRROR HANDS", "file": "res://art/gallery/mirror_hands.jpg", "kind": "poster"},
	"jester_seal": {"title": "THE JESTER SEAL", "file": "res://art/gallery/jester_seal.jpg", "kind": "card"},
	"the_hand": {"title": "THE HAND", "file": "res://art/gallery/the_hand.jpg", "kind": "card"},
}


static func collected() -> Array:
	return (WorldHistory.subject(SUBJECT).get("collected", []) as Array).duplicate()


static func has(piece_id: String) -> bool:
	return collected().has(piece_id)


## Adds a piece to the gallery. False if it is unknown or already there.
static func collect(piece_id: String, where: String = "") -> bool:
	if not PIECES.has(piece_id) or has(piece_id):
		return false
	var list := collected()
	list.append(piece_id)
	WorldHistory.register_subject(SUBJECT, {"kind": "collection"})
	WorldHistory.update_subject(SUBJECT, {"collected": list}, "art_collected")
	WorldHistory.record_event("art_collected", {"piece": piece_id, "location": where})
	return true


static func texture(piece_id: String) -> Texture2D:
	return load(str(PIECES.get(piece_id, {}).get("file", ""))) as Texture2D
