class_name WireSiteCatalog
extends RefCounted

## Authored places on the Wire. These are content descriptors, not UI panels:
## renderers are expected to honour each site's own `aesthetic` instead of
## painting the device chrome over every page.

const SURFACE := 1
const UNDERBELLY := 2

const SITES := [
	{
		"id": "morrow_find", "uri": "wire://morrow.find/", "title": "Morrow Find",
		"kind": "search", "band": SURFACE,
		"summary": "A search engine that remembers misspellings longer than people.",
		"keywords": ["search", "directory", "people", "places", "products", "rumours"],
		"aesthetic": {"layout": "paper-white search field and drifting result slips", "palette": ["bone", "ink", "fruit-sticker-red"], "type": "friendly rounded bitmap", "motion": "results bob as if afloat", "reduced_motion": "static stacked cards"},
		"sections": [{"heading": "WHAT ARE YOU TRYING TO REMEMBER?", "body": "Search people, ruins, products, transmissions, fungi, or a phrase you overheard."}],
		"links": [{"label": "today's handmade doors", "target": "hinge_garden"}, {"label": "CellOutz service status", "target": "celloutz_living"}],
	},
	{
		"id": "celloutz_living", "uri": "wire://celloutz.living/", "title": "CellOutz Living",
		"kind": "corporate_portal", "band": SURFACE, "owner_subject_id": "celloutz",
		"summary": "Your identity, signal and afterlife in one compulsory account.",
		"keywords": ["celloutz", "9g", "signal", "account", "contacts", "terms", "identity"],
		"aesthetic": {"layout": "immaculate service tiles inside an overfriendly halo", "palette": ["milk-white", "municipal-blue", "warning-orange"], "type": "corporate humanist", "motion": "help mascot waves one beat too late", "reduced_motion": "still mascot portrait"},
		"sections": [{"heading": "YOU ARE STILL CONNECTED", "body": "Coverage is a civic feeling. Billing is a physical fact."}, {"heading": "TERMS OF CONTINUANCE", "body": "Your profile may remain active after you cease to be available."}],
		"links": [{"label": "find anything", "target": "morrow_find"}, {"label": "community signal diary", "target": "mast_watch"}, {"label": "leave the official site", "target": "softrot_picnic"}],
	},
	{
		"id": "softrot_picnic", "uri": "wire://home.softrot/~moth/picnic.html", "title": "Moth's Soft-Rot Picnic Page!!!",
		"kind": "personal_homepage", "band": SURFACE, "owner_subject_id": "moth_jerrow",
		"summary": "Fungus photos, soup ratings, six guestbooks and a blinking apology.",
		"keywords": ["moth", "jerrow", "fungus", "spores", "soup", "personal", "guestbook", "soft rot"],
		"aesthetic": {"layout": "tilted scrapbook with too many stamps", "palette": ["moss", "jam-purple", "sunny-yellow"], "type": "hand-labelled pixel", "motion": "tiny mushrooms march along the footer", "reduced_motion": "mushroom border"},
		"sections": [{"heading": "HELLO FROM SOMEWHERE DAMP", "body": "today's honest lunch: half a pear and the safe blue shelf fungus."}, {"heading": "MY FRIENDS", "body": "Nix fixed the little radio. Vale did not sign the guestbook but I know they came."}],
		"links": [{"label": "Nix's repair notes", "target": "lantern_repair"}, {"label": "weather the Board denies", "target": "mast_watch"}, {"label": "DO NOT CLICK: marrow recipes", "target": "marrow_exchange"}],
	},
	{
		"id": "lantern_repair", "uri": "wire://gate-lanterns.pub/repair-notes", "title": "Gate Lantern Repair Notes",
		"kind": "community_wiki", "band": SURFACE, "owner_subject_id": "nix_arden",
		"summary": "Practical diagrams whose comments keep becoming mutual aid.",
		"keywords": ["nix", "arden", "repair", "medicine", "radio", "battery", "gate lanterns"],
		"aesthetic": {"layout": "wide illustrated cards with thumb-sized tabs", "palette": ["warm-cream", "workshop-green", "pencil-grey"], "type": "console manual sans", "motion": "page corners lift on focus", "reduced_motion": "focus outline"},
		"sections": [{"heading": "MAKE IT SERVICEABLE", "body": "A cracked object is still an object. A cracked person needs tea before solder."}],
		"links": [{"label": "Moth's thank-you page", "target": "softrot_picnic"}, {"label": "receiver frequencies", "target": "number_station_archive"}],
	},
	{
		"id": "mast_watch", "uri": "wire://mastwatch.ash/skyproof/", "title": "MASTWATCH: The Weather Has Owners",
		"kind": "conspiracy_collage", "band": SURFACE,
		"summary": "Satellite arithmetic, weather accusations and forty-seven red arrows.",
		"keywords": ["mast", "satellite", "weather", "666", "orbit", "nasa", "signal", "conspiracy"],
		"aesthetic": {"layout": "annotated sky photographs pinned over one another", "palette": ["chemical-cyan", "marker-red", "photocopier-black"], "type": "mixed ransom display", "motion": "arrows redraw themselves", "reduced_motion": "numbered arrow legend"},
		"sections": [{"heading": "THE CLOUDS HAVE ACCOUNT NUMBERS", "body": "Orbit 6 / mast 6 / ration docket 6. Coincidence is a subscription service."}],
		"links": [{"label": "the signal they buried", "target": "number_station_archive"}, {"label": "who owns your name", "target": "celloutz_living"}, {"label": "unredacted donor geometry", "target": "marrow_exchange"}],
	},
	{
		"id": "number_station_archive", "uri": "wire://archive.static/88.50", "title": "The 88.50 Listening Room",
		"kind": "abandoned_archive", "band": SURFACE,
		"summary": "Listener transcripts from a number station that has not stopped broadcasting.",
		"keywords": ["radio", "88.50", "frequency", "transmission", "numbers", "archive", "signal"],
		"aesthetic": {"layout": "narrow transcript reel around a silent waveform", "palette": ["faded-teal", "oxide", "paper"], "type": "library terminal mono", "motion": "waveform advances only when audio exists", "reduced_motion": "timestamped transcript"},
		"sections": [{"heading": "RECOVERED TAPE 33", "body": "five heads / one frame / do not answer the sixth voice"}],
		"links": [{"label": "signal diary", "target": "mast_watch"}, {"label": "a handmade door to nowhere", "target": "hinge_garden"}],
	},
	{
		"id": "hinge_garden", "uri": "wire://hinge.garden/doors/", "title": "Hinge Garden",
		"kind": "art_site", "band": SURFACE,
		"summary": "A gallery of doors photographed open, with nowhere visible behind them.",
		"keywords": ["art", "doors", "gallery", "photography", "ruins", "dreams"],
		"aesthetic": {"layout": "one enormous image with tiny garden-path links", "palette": ["cloud-pink", "leaf-green", "door-blue"], "type": "ornamental serif captions", "motion": "door shadows change with device time", "reduced_motion": "fixed noon shadows"},
		"sections": [{"heading": "DOOR 109: FOUND STANDING ALONE", "body": "The photographer's account posted this tomorrow."}],
		"links": [{"label": "guest photographer", "target": "softrot_picnic"}, {"label": "search for the address", "target": "morrow_find"}],
	},
	{
		"id": "marrow_exchange", "uri": "wire://below/marrow-exchange", "title": "Marrow Exchange / Quiet Ledger",
		"kind": "underbelly_market", "band": UNDERBELLY, "owner_subject_id": "doctor_vanta",
		"summary": "A terminal-only exchange for fictional relic tissue and compromised histories.",
		"keywords": ["marrow", "doctor", "vanta", "donor", "contraband", "market", "darkweb", "organs"],
		"gate": {"kind": "signal_grade", "minimum": UNDERBELLY, "fiction": "A physical underbelly terminal supplies the route."},
		"aesthetic": {"layout": "wax-sealed lots orbit a surgical ledger", "palette": ["dried-blood", "vellum", "bruise-violet"], "type": "engraved ledger mono", "motion": "ownership seals turn under inspection", "reduced_motion": "front-and-back seal cards"},
		"sections": [{"heading": "NO SHIPPING. NO MIRACLES.", "body": "Ownership is an in-world record. Nothing here is money outside the game."}],
		"market_lots": [{"id": "lot_vertebra_03", "name": "Reliquary vertebra / claimed", "scarcity": "singular", "provenance": [{"kind": "found", "holder": "choir_of_marrow", "record": "quarry reliquary 03"}], "price_scrip": 430}, {"id": "lot_keyless_coat", "name": "Coat whose access key was lost", "scarcity": "five recorded", "provenance": [{"kind": "made", "holder": "unrecorded tailor", "record": "stitch-mark 9"}, {"kind": "recovered", "holder": "doctor_vanta", "record": "ash locker"}], "price_scrip": 95}],
		"links": [{"label": "the public lie about identity", "target": "celloutz_living"}, {"label": "donor weather correlation", "target": "mast_watch"}],
	},
]


static func all_sites() -> Array:
	return SITES.duplicate(true)


static func site(site_id: String) -> Dictionary:
	for entry in SITES:
		if str(entry.get("id", "")) == site_id:
			return (entry as Dictionary).duplicate(true)
	return {}


static func site_ids_for_subject(subject_id: String) -> Array[String]:
	var found: Array[String] = []
	for entry in SITES:
		if str(entry.get("owner_subject_id", "")) == subject_id:
			found.append(str(entry.id))
	return found


static func validate_links() -> Array[String]:
	var failures: Array[String] = []
	var ids: Array[String] = []
	for entry in SITES:
		ids.append(str(entry.id))
	for entry in SITES:
		for link in entry.get("links", []):
			if not ids.has(str((link as Dictionary).get("target", ""))):
				failures.append("%s -> %s" % [str(entry.id), str((link as Dictionary).get("target", ""))])
	return failures
