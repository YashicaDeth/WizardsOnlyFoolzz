class_name WireBrowser
extends RefCounted

const SiteCatalog := preload("res://systems/wire_site_catalog.gd")

const STATE_VERSION := 1

var signal_grade := SiteCatalog.SURFACE
var _accounts: Dictionary = {}
var _history: Array[String] = []
var _cursor := -1
var _discovered: Dictionary = {}


func _init(grade: int = SiteCatalog.SURFACE, accounts: Dictionary = {}) -> void:
	signal_grade = grade
	reindex(accounts)


func reindex(accounts: Dictionary) -> void:
	_accounts = accounts.duplicate(true)


## Every physical subject receives a distinct online body without becoming a
## second source of character truth. The online identity points back to the
## canonical subject id and adds only Wire-native presentation hooks.
func identity_for_account(account: Dictionary) -> Dictionary:
	var subject_id := str(account.get("id", ""))
	var seed := hash(subject_id) & 0x7fffffff
	var moods := ["WANDERING", "DREAMING NEAR SIGNAL", "EATING SOMETHING HONEST", "BROADCASTING TO NOBODY", "HIDING WITH GOOD RECEPTION"]
	var shapes := ["halo", "seed", "mask", "lantern", "little_house"]
	var palettes := ["moss_jam", "cream_orange", "violet_bone", "rust_sky", "teal_candle"]
	return {
		"subject_id": subject_id,
		"profile_uri": "wire://people/%s" % subject_id.uri_encode(),
		"handle": str(account.get("handle", "@unsigned")),
		"status_phrase": moods[seed % moods.size()],
		"avatar": {"seed": seed, "shape": shapes[seed % shapes.size()], "palette": palettes[(seed / 7) % palettes.size()]},
		"site_ids": SiteCatalog.site_ids_for_subject(subject_id),
	}


func sites_for_subject(subject_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for site_id in SiteCatalog.site_ids_for_subject(subject_id):
		found.append(SiteCatalog.site(site_id))
	return found


func search(query: String, limit: int = 12) -> Dictionary:
	var terms := _terms(query)
	var results: Array = []
	for site in SiteCatalog.all_sites():
		if int(site.get("band", SiteCatalog.SURFACE)) > signal_grade:
			continue
		var score := _score(site, terms)
		if terms.is_empty() or score > 0:
			results.append(_result(site, score, []))
	for subject_id in _accounts:
		var account: Dictionary = _accounts[subject_id]
		if int(account.get("band", SiteCatalog.SURFACE)) > signal_grade:
			continue
		var profile := _profile_site(account)
		var score := _score(profile, terms)
		if terms.is_empty() or score > 0:
			results.append(_result(profile, score, ["character", "online body"]))
	results.sort_custom(func(a, b): return int(a.score) > int(b.score) if int(a.score) != int(b.score) else str(a.title) < str(b.title))
	if results.size() > limit:
		results.resize(limit)
	return {"query": query, "terms": terms, "results": results, "count": results.size(), "signal_grade": signal_grade}


func open(site_id: String, record_history: bool = true) -> Dictionary:
	var page := _resolve(site_id)
	if page.is_empty():
		return {"ok": false, "reason": "ADDRESS NOT FOUND", "site_id": site_id}
	if int(page.get("band", SiteCatalog.SURFACE)) > signal_grade:
		return {"ok": false, "reason": "NO ROUTE FROM HERE", "site_id": site_id, "gate": page.get("gate", {"kind": "signal_grade", "minimum": SiteCatalog.UNDERBELLY})}
	if record_history:
		if _cursor < _history.size() - 1:
			_history.resize(_cursor + 1)
		_history.append(str(page.id))
		_cursor = _history.size() - 1
	_discovered[str(page.id)] = true
	return {"ok": true, "page": page, "route": {"kind": "site", "id": str(page.id), "root": "wire"}, "navigation": navigation_state()}


func follow_link(from_site_id: String, link_index: int) -> Dictionary:
	var source := _resolve(from_site_id)
	var links: Array = source.get("links", [])
	if link_index < 0 or link_index >= links.size():
		return {"ok": false, "reason": "LINK ROTTED", "site_id": from_site_id}
	return open(str((links[link_index] as Dictionary).get("target", "")))


func back() -> Dictionary:
	if _cursor <= 0:
		return {"ok": false, "reason": "START OF TRAIL", "navigation": navigation_state()}
	_cursor -= 1
	return open(_history[_cursor], false)


func forward() -> Dictionary:
	if _cursor < 0 or _cursor >= _history.size() - 1:
		return {"ok": false, "reason": "END OF TRAIL", "navigation": navigation_state()}
	_cursor += 1
	return open(_history[_cursor], false)


func navigation_state() -> Dictionary:
	return {
		"current": _history[_cursor] if _cursor >= 0 and _cursor < _history.size() else "",
		"can_back": _cursor > 0,
		"can_forward": _cursor >= 0 and _cursor < _history.size() - 1,
		"trail": _history.duplicate(),
		"cursor": _cursor,
		"discovered": _discovered.keys(),
	}


## Additive state has its own version and forgiving defaults. Existing saves
## have no `wire_browser` member and restore to an empty trail.
func snapshot() -> Dictionary:
	return {"version": STATE_VERSION, "history": _history.duplicate(), "cursor": _cursor, "discovered": _discovered.keys()}


func restore(saved: Dictionary) -> void:
	_history.clear()
	_discovered.clear()
	for site_id in saved.get("history", []):
		if not _resolve(str(site_id)).is_empty():
			_history.append(str(site_id))
	_cursor = clampi(int(saved.get("cursor", _history.size() - 1)), -1, _history.size() - 1)
	for site_id in saved.get("discovered", []):
		if not _resolve(str(site_id)).is_empty():
			_discovered[str(site_id)] = true


func _resolve(site_id: String) -> Dictionary:
	var authored := SiteCatalog.site(site_id)
	if not authored.is_empty():
		return authored
	if site_id.begins_with("profile:"):
		var subject_id := site_id.trim_prefix("profile:")
		if _accounts.has(subject_id):
			return _profile_site(_accounts[subject_id])
	return {}


func _profile_site(account: Dictionary) -> Dictionary:
	var online := identity_for_account(account)
	var links: Array = []
	for site_id in online.site_ids:
		links.append({"label": "their authored corner of the Wire", "target": site_id})
	links.append({"label": "search their name", "target": "morrow_find"})
	return {
		"id": "profile:%s" % str(account.get("id", "")),
		"uri": str(online.profile_uri), "title": str(account.get("name", "UNSIGNED")),
		"kind": "character_profile", "band": int(account.get("band", SiteCatalog.SURFACE)),
		"owner_subject_id": str(account.get("id", "")),
		"summary": "%s // %s // %s" % [str(account.get("role", "unindexed")), str(account.get("faction", "Unbound")), str(online.status_phrase)],
		"keywords": [str(account.get("name", "")), str(account.get("handle", "")), str(account.get("role", "")), str(account.get("faction", ""))],
		"aesthetic": {"layout": "identity channel", "palette": [str(online.avatar.palette), "bone", "signal"], "type": "rounded social terminal", "motion": "avatar idles according to status", "reduced_motion": "status caption"},
		"online_identity": online, "links": links,
	}


func _score(site: Dictionary, terms: Array[String]) -> int:
	if terms.is_empty():
		return 1
	var title := str(site.get("title", "")).to_lower()
	var summary := str(site.get("summary", "")).to_lower()
	var uri := str(site.get("uri", "")).to_lower()
	var keywords := " ".join(site.get("keywords", [])).to_lower()
	var score := 0
	for term in terms:
		if title.contains(term):
			score += 8
		if keywords.contains(term):
			score += 5
		if summary.contains(term):
			score += 3
		if uri.contains(term):
			score += 2
	return score


func _result(site: Dictionary, score: int, extra_hooks: Array) -> Dictionary:
	var hooks: Array = extra_hooks.duplicate()
	if str(site.get("owner_subject_id", "")) != "":
		hooks.append("subject:%s" % str(site.owner_subject_id))
	var route_kind := "account" if str(site.kind) == "character_profile" else "site"
	return {"site_id": str(site.id), "uri": str(site.uri), "title": str(site.title), "snippet": str(site.summary), "kind": str(site.kind), "score": score, "hooks": hooks, "route": {"kind": route_kind, "id": str(site.id), "root": "wire"}, "aesthetic": site.get("aesthetic", {}).duplicate(true)}


func _terms(query: String) -> Array[String]:
	var normal := query.to_lower()
	for mark in ["/", "\\", ".", ",", ":", ";", "?", "!", "@", "#", "(", ")"]:
		normal = normal.replace(mark, " ")
	var terms: Array[String] = []
	for piece in normal.split(" ", false):
		if piece.length() > 1 and not terms.has(piece):
			terms.append(piece)
	return terms
