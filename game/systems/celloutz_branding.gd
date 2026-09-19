class_name CellOutzBranding
extends RefCounted

## K1.2. CellOutz's product language is the public face of the faction below.
##
## This keeps the connection in the places players already meet the company:
## a liability notice, the Growing Floor paperwork, and customer care. It is
## deliberately corporate first and infernal second. The company never calls
## itself a demon faction; it calls a body an asset, a debt a record, and the
## underworld an office that can close a ticket.

const FACTION_ID := "celloutz"
const CORPORATE_NAME := "CELLOUTZ CORPORATION"
const PRINCIPLE := "Ownership"
const AXIS := "DESCENT"
const COSMOLOGY := "demon faction below"
const SUPPORT_SITE_ID := "celloutz_support"

const SURFACES := {
	"warning": {
		"heading": "CELLOUTZ CORPORATION / DESCENT LIABILITY NOTICE 11-B",
		"body": """CELLOUTZ CORPORATION accepts no responsibility for the physical,
spiritual, or financial consequences of this product.

Your body entered the ledger before you did. Its organs,
debts, and recorded remains are held under the terms below.

This is a work of fiction. The company is fictional.
The ownership clause is not. You may leave; your account cannot.""",
		"footer": "BELOW OPERATIONS // ALL DISPUTES DESCEND WITH THE ACCOUNT",
	},
	"intake": {
		"header": "CELLOUTZ GROWING FLOOR // DESCENT INTAKE // ONE PER BODY",
		"body_notice": "WHAT IS UNDER THE SKIN IS COLLATERAL.",
		"handler_badge": "HANDLER / BELOW OPS",
	},
	"support": {
		"section_label": "CARE / BELOW OPERATIONS",
		"strap": "We value your continued function and recoverable material.",
		"lines": [
			"Your warranty covers the part. The part covers your debt.",
			"TICKET #77120 — CLOSED / TRANSFERRED BELOW",
			"TICKET #77121 — CLOSED / NO LIVING ORIGINAL",
			"Ownership disputes are handled after intake. Below.",
			"Was this article helpful?   [ YES ]   [ YES ]",
		],
	},
}


## A concise record for UI and simulation code that wants the faction identity
## without turning a product screen into a lore panel.
static func faction_record() -> Dictionary:
	return {
		"id": FACTION_ID,
		"name": CORPORATE_NAME,
		"principle": PRINCIPLE,
		"axis": AXIS,
		"cosmology": COSMOLOGY,
		"register": "corporate / bodily / extractive",
	}


static func copy_for(surface: String, field: String, fallback: String = "") -> String:
	var surface_copy: Dictionary = SURFACES.get(surface, {})
	return str(surface_copy.get(field, fallback))


## The array is copied so an individual web page cannot mutate the canonical
## customer-care text for every later page.
static func support_lines() -> Array:
	var surface_copy: Dictionary = SURFACES.get("support", {})
	var lines: Array = []
	for line in surface_copy.get("lines", []):
		lines.append(str(line))
	return lines
