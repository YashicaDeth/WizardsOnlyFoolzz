# The Wire — device, internet and social layer

## Why this exists

Three problems collapse into one solution.

1. The interface is not seamless. The World Index (`Tab`), Living Map (`M`),
   Character Tree (`T`) and Allusions artwork (`J`) are four unrelated
   fullscreen panels bound to four keys. Nothing connects them.
2. The desolate internet (Master Codex §13) is specified but barely built — one
   reactive CellOutz Wire headline.
3. The Hunt System needs a transmission channel for grudges, and a way for the
   player to act on rivals without physically finding them.

All three are answered by putting the interface *inside the world* as an
object the character physically holds.

## The device

A salvaged handheld. Pip-Boy in role — a diegetic screen you raise and look at,
which does not pause the world — but not in look: this is post-Reset junk,
cracked casing, someone else's stickers, a cable-tied battery, a screen with
dead pixels in a fixed pattern. Nearer to a Gmod tool gun in feel than a
polished military device: a thing with modes, held at arm's length.

Raising it is a physical action with cost. The world keeps running. You are
holding a glowing screen in a dark wasteland, which is exactly as safe as it
sounds. Being attacked while reading should be a real risk, and that risk is
what makes the device interesting rather than a menu with a skin.

It replaces the four panels with modes on one object:

| Mode | Replaces | Adds |
| --- | --- | --- |
| INDEX | World Index | Searchable, incomplete, sometimes wrong |
| MAP | Living Map | Territory, rumours, last-known positions |
| TREE | Character Tree | The Ascent/Limbo/Descent axis as navigation |
| WIRE | — | The surviving internet |
| CARRY | — | Inventory, currently only a `WorldHistory` subject |
| ALLUSIONS | Artwork | The living art archive |

Hardware condition matters. A damaged device shows a damaged interface:
cracked-screen occlusion over map regions, dead scanlines eating text, a failing
battery that closes a mode mid-read. Repairs and upgrades are economy items,
which gives the scrapyard something to sell that is not a car part.

## The Wire — visual register

The surviving internet looks like **paranoid collage**: dense, garish,
hand-assembled political cut-and-paste in the David Dees register — 5G masts
bristling over a suburb, chemical rain, a surveillance eye pasted over a
smiling family, arrows and exclamation marks annotating things that are and are
not connected. Saturated, ugly, badly kerned, made in anger by someone with more
conviction than layout skill.

This is a satirical target, not an endorsement. In a world that actually had an
apocalypse, the conspiracy poster is *sometimes right*, and that ambiguity is
the joke and the horror at once. Some of it is nonsense. Some of it describes
the Choir of Marrow accurately. The player cannot tell which from the page
alone, which is the entire pillar of §13: information is partial, late,
manipulated or false.

Content types: dead forums with the last post four years old, automated shops
still taking orders nobody fills, bots arguing with bots, broken image hosts,
archived arguments between people who are now dead, a business with no surviving
employees, and rare live humans. A dormant profile showing "last online two
minutes ago" should be genuinely unsettling.

Reached through the world, not only the menu: a 5G mast is a physical
landmark that extends coverage, a terminal in a shop is a fixed access point,
and connectivity is a property of *place*. No signal in the caves.

## The social layer

The Wire is where the Hunt System becomes playable at range. Every significant
subject already carries identity, faction, relations, wounds, grudges and Tree
alignment. The social layer exposes that as an account.

Actions against a rival, each with a real cost:

- **Observe.** Read their posts, their network, their movements. Passive,
  cheap, and how you find someone you cannot physically locate.
- **Contact.** Talk. Threaten. Negotiate. Apologise. A grudge can be *lowered*
  here, which makes the Wire the only non-violent route out of a vendetta.
- **Expose.** Publish something true about them. Damages their standing inside
  their own faction — which can get them demoted, or killed by their own side.
- **Fabricate.** Publish something false. Works, until it is disproven, and
  then it rebounds onto your own reputation harder than the truth would have.
- **Trace.** Establish their pattern and predict where they will physically be.
  This is how a Wire investigation turns into an ambush.
- **Swarm.** Turn a faction's own followers onto one of their own.

**Everything here is reciprocal.** The player has an account, a reputation and
a location that can be inferred. Doxxing works in both directions; a rival who
survives an exposure campaign can run one back, and NPCs can trace the player's
own posting pattern to a physical place and arrive there. The satire only
functions if the player is inside the system rather than operating on it from
outside — a consequence-free harassment toy would be both worse design and a
worse joke.

Costs and traces: every action leaves a record with an author. Posts can be
timestamped, attributed, screenshotted and archived by third parties. Deleting
does not remove what was already propagated — the distortion rules in
`DESIGN/HUNT_SYSTEM.md` apply to Wire content, so the version that spreads is
often not the version you published.

## Clout is rank

Follower and like counts are the public, visible, *unreliable* face of the
influence dimension the Codex already separates from combat skill (§7). A
terrifying fighter can have almost no reach. A physically weak broker can have
enormous reach. The number is not power — it is the world's *estimate* of
power, and it can be wrong, bought or manufactured.

Access is gated by standing, and this is the point:

- **High-clout accounts do not answer.** DMs go unread. Mentions vanish into a
  mention feed nobody reviews. A Chief with a large account is *less* reachable
  than a nobody, not more.
- Reaching them therefore requires something other than messaging them: an
  intermediary who is already inside their network, leverage worth their
  attention, or enough standing of your own that ignoring you is a cost.
- The player's own account grows through what the world witnesses. Clout is
  earned by being *reported on*, which loops back through the Wire's coverage
  of derby results, killings and betrayals.
- Being noticed by the wrong large account is a threat, not a reward. A swarm
  can arrive at a physical location.

This makes the social hierarchy a second progression ladder running parallel to
combat, and it gives a non-violent player route into the Hunt System.

## The feed is hostile

The platform is not neutral. It is an evil Instagram: an endless scroll of
gore, atrocity footage, doom headlines, wellness-adjacent frequency and energy
mysticism, conspiracy collage, engagement bait and the confident wrong
explanation of every recent catastrophe — all interleaved with someone's lunch.
Nothing is sorted for the reader's benefit. The design should feel like being
farmed.

Mechanically, that hostility should have teeth rather than being set dressing.
Extended scrolling has a cost the anatomy component can already carry: the
device drains attention the way a wound drains blood. Doomscrolling in a cave
while bleeding is a decision with consequences, and the game should let the
player make it badly. Balance this carefully — the cost must be real enough to
feel and mild enough that the Wire stays usable.

The joke and the horror arrive together, per `ART-DIRECTION.md`: the feed is
funny, and it is also the most accurate portrait of the post-Reset world
available to the player, and both of those are true at once.

## Implementation order

1. **The device shell.** One handheld with modes, replacing the four key-bound
   panels. Pure UI consolidation, no new simulation, immediate seamlessness win.
2. **CARRY.** Surface the inventory subject that already exists.
3. **WIRE, read-only.** Generated feed reacting to real world history: derby
   results, deaths, faction shifts. The reactive headline already proves it.
4. **Accounts.** Bind Wire identities to existing `WorldHistory` subjects.
5. **Observe and Contact.** The passive half. Ties into the Hunt System's
   witness/propagation pass.
6. **Expose, Fabricate, Trace, Swarm.** The active half, with reciprocity and
   reputation consequences landing at the same time — never ship these before
   the costs work, or the system reads as a toy.
7. **Physical connectivity.** Masts, terminals, dead zones, hardware condition.

## Boundary

Reproduce no real platform's branding, interface or identity, and target no
real person. The satire aims at platforms, media and institutions as systems —
which is the register set in `ART-DIRECTION.md` — and the fictional world
carries it.
