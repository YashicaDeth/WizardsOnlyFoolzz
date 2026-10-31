# The dev site

One place to read the game's documents, keep the plan, blog ideas, hold concept
art and search every old chat. It runs on your machine, from this folder, with
nothing installed but Node.

```
devsite\start.cmd
```

That opens `http://127.0.0.1:4317` in your browser. Leave the black window open
while you work; close it (or press Ctrl+C) to stop. On anything that is not
Windows:

```
node devsite/server.js --open
```

`node devsite/server.js 5000` picks another port if 4317 is taken.

## What is in it

| Page | What it is | Stored as |
| --- | --- | --- |
| **Today** | Front page: the five structure documents in reading order, the queue, the newest notes and art | — |
| **Plan** | Every brief in `DESIGN/PROMPT_ROADMAP.md`, read out of that file, with a copy button | — |
| **Documents** | Every `.md` in `DESIGN/`, `HANDOFF/` and the repo root | read-only, straight from the repo |
| **Notes** | Write, edit and delete notes. Markdown. | `devsite/content/notes/*.md` |
| **Art** | Drop or choose images; click to enlarge | `devsite/content/art/` |
| **Archive** | Old GPT and Claude exports, dropped text, stray documents | `devsite/content/inbox/` |

There is a search box in the header (`/` focuses it) that covers documents,
notes **and** the archive, with line numbers.

## Notes

A note is a markdown file. The title becomes the filename and the first `#`
heading, so `2026-10-23-the-ladder.md` is both the note and its address. Nothing
is stored in a database; back them up by copying the folder, and read them in
any editor.

Write in markdown: `# heading`, `- list`, `**bold**`, `` `code` ``, `> quote`,
`| tables |`, and fenced code blocks. Links to `.md` files inside the repo work
as links between pages.

## The archive

Chat exports are the one thing worth dropping in whole. Copy
`conversations.json` from a ChatGPT export, or a Claude export, into
`devsite/content/inbox/` — the site splits it into one entry per conversation
and makes all of it searchable. The same for `.md`, `.txt` and `.html`.

Large files are fine in the folder. Dropping through the browser is capped at
24 MB per file; copying into the folder has no cap.

## What it is not

- **Not the game's public site.** That comes later: Steam page, trailer,
  roadmap, credits.
- **It never writes to `DESIGN/`.** Documents are the repo's; the site only
  reads them. Editing a design document still means editing the file.
- **It never leaves `127.0.0.1`.** No accounts, no network calls, no telemetry.
  Images and notes stay on disk.

## If something looks wrong

- **A document is missing from the rail** — it only lists `.md` files in
  `DESIGN/`, `HANDOFF/`, and the four named root files. A new top-level folder
  is not read unless it is added to `READ_DIRS` in `server.js`.
- **The Plan page is empty** — `DESIGN/PROMPT_ROADMAP.md` must keep its
  `## 3. \`brief-slug\`` headings with a ` ```text ` block under each.
- **The port is busy** — `node server.js 5000`, then open
  `http://127.0.0.1:5000`.
- **Node is not installed** — get 18 or newer from nodejs.org; `start.cmd` will
  say so rather than failing silently.
