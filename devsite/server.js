// Wizards Only Fools — local dev site.
//
// Zero dependencies. Serves the design documents out of the repo, keeps notes,
// concept art and old chat exports as plain files next to itself, and never
// leaves 127.0.0.1.
//
//   node devsite/server.js            -> http://127.0.0.1:4317
//   node devsite/server.js 5000       -> another port
//   node devsite/server.js --open     -> and open a browser
//
// Everything it keeps lives in devsite/content/, so the site's own content is
// git-friendly, greppable and portable:
//
//   content/notes/   one .md per note, written in the browser
//   content/art/     concept art as the original image files
//   content/inbox/   dropped chat exports and stray text, read-only
//
// Nothing here writes to the design documents. They are the repo's, and the
// site only reads them.

const http = require("http");
const fs = require("fs");
const fsp = fs.promises;
const path = require("path");

const HERE = __dirname;
const ROOT = path.resolve(HERE, "..");
const CONTENT = path.join(HERE, "content");
const NOTES = path.join(CONTENT, "notes");
const ART = path.join(CONTENT, "art");
const INBOX = path.join(CONTENT, "inbox");
const PUBLIC = path.join(HERE, "public");
const PORT = Number(process.argv.find((a) => /^\d+$/.test(a)) || process.env.WOF_PORT || 4317);

const READ_DIRS = ["DESIGN", "HANDOFF"];
const READ_ROOT_FILES = ["START_HERE.md", "DESIGN.md", "OVERNIGHT_GOALS.md", "CHECKLIST.md"];
const IMAGE_EXT = new Set([".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif"]);
const TEXT_EXT = new Set([".md", ".markdown", ".txt", ".text", ".html", ".htm", ".json"]);

for (const dir of [CONTENT, NOTES, ART, INBOX]) fs.mkdirSync(dir, { recursive: true });

function json(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "content-length": Buffer.byteLength(body),
  });
  res.end(body);
}

function fail(res, code, message) {
  json(res, code, { error: message });
}

async function readBody(req, limit = 24 * 1024 * 1024) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limit) throw new Error("body too large");
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString("utf8");
  return raw ? JSON.parse(raw) : {};
}

function firstHeading(text, fallback) {
  const line = text.split(/\r?\n/).find((l) => /^#\s+/.test(l));
  return line ? line.replace(/^#\s+/, "").trim() : fallback;
}

// Only documents the repo already tracks, and never outside the allowlist.
function resolveDoc(rel) {
  const clean = String(rel || "").replace(/\\/g, "/").replace(/^\/+/, "");
  if (clean.includes("..")) return null;
  const absolute = path.resolve(ROOT, clean);
  if (!absolute.startsWith(ROOT + path.sep)) return null;
  const inDir = READ_DIRS.some((d) => absolute.startsWith(path.join(ROOT, d) + path.sep));
  const inRoot = READ_ROOT_FILES.includes(clean);
  if (!inDir && !inRoot) return null;
  if (!absolute.toLowerCase().endsWith(".md")) return null;
  return absolute;
}

function notePath(rel) {
  const base = path.basename(String(rel || ""));
  if (!base.endsWith(".md") || base.includes("..")) return null;
  return path.join(NOTES, base);
}

function inboxPath(name) {
  const base = path.basename(String(name || ""));
  if (base.includes("..")) return null;
  if (!TEXT_EXT.has(path.extname(base).toLowerCase())) return null;
  return path.join(INBOX, base);
}

function slugify(text) {
  return String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60) || "note";
}

function noteTitle(text, fallback) {
  const line = text.split(/\r?\n/).find((l) => /^#\s+/.test(l));
  return line ? line.replace(/^#\s+/, "").trim() : fallback;
}

function groupFor(rel) {
  if (rel === "START_HERE.md") return "Front door";
  if (/^DESIGN\/(THE_SPINE|THE_LADDER|THE_CAST|THE_SCREEN|STYLE_RULES)\.md$/.test(rel)) return "Structure";
  if (rel === "DESIGN/PROMPT_ROADMAP.md") return "Roadmap";
  if (rel.startsWith("HANDOFF/")) return "Handoff";
  return "Design";
}

async function listDocs() {
  const out = [];
  for (const rel of READ_ROOT_FILES) {
    const absolute = path.join(ROOT, rel);
    try {
      const st = await fsp.stat(absolute);
      const text = await fsp.readFile(absolute, "utf8");
      out.push({ path: rel, title: firstHeading(text, rel), group: groupFor(rel), mtime: st.mtimeMs, size: text.length });
    } catch (_) { /* not present in this checkout */ }
  }
  for (const dir of READ_DIRS) {
    const absoluteDir = path.join(ROOT, dir);
    let entries = [];
    try { entries = await fsp.readdir(absoluteDir, { withFileTypes: true }); } catch (_) { continue; }
    for (const entry of entries) {
      if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
      const rel = `${dir}/${entry.name}`;
      const absolute = path.join(absoluteDir, entry.name);
      try {
        const st = await fsp.stat(absolute);
        const text = await fsp.readFile(absolute, "utf8");
        out.push({ path: rel, title: firstHeading(text, entry.name), group: groupFor(rel), mtime: st.mtimeMs, size: text.length });
      } catch (_) { /* skip unreadable */ }
    }
  }
  return out.sort((a, b) => a.group.localeCompare(b.group) || b.mtime - a.mtime);
}

async function listNotes() {
  let entries = [];
  try { entries = await fsp.readdir(NOTES, { withFileTypes: true }); } catch (_) { return []; }
  const out = [];
  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    const absolute = path.join(NOTES, entry.name);
    const st = await fsp.stat(absolute);
    const text = await fsp.readFile(absolute, "utf8");
    out.push({
      path: `content/notes/${entry.name}`,
      title: noteTitle(text, entry.name.replace(/\.md$/, "")),
      mtime: st.mtimeMs,
      size: text.length,
      excerpt: text.split(/\r?\n/).filter((l) => l.trim() && !l.startsWith("#")).slice(0, 2).join(" ").slice(0, 180),
    });
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}

async function listArt() {
  let entries = [];
  try { entries = await fsp.readdir(ART, { withFileTypes: true }); } catch (_) { return []; }
  const out = [];
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (!IMAGE_EXT.has(path.extname(entry.name).toLowerCase())) continue;
    const st = await fsp.stat(path.join(ART, entry.name));
    out.push({ file: entry.name, url: `/art/${encodeURIComponent(entry.name)}`, mtime: st.mtimeMs, bytes: st.size });
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}

/* ---------------- inbox: old chats, stray text ---------------- */

function htmlToText(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|li|h[1-6]|tr)>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// A ChatGPT export is `conversations.json`: an array of conversations whose
// `mapping` holds the tree of messages. A Claude export is an array of
// conversations with `chat_messages`. Both flatten to the same shape.
function flattenChatGpt(conv) {
  const mapping = conv.mapping || {};
  const rows = [];
  for (const node of Object.values(mapping)) {
    const message = node && node.message;
    if (!message) continue;
    const role = message.author && message.author.role;
    if (role !== "user" && role !== "assistant" && role !== "system") continue;
    const parts = (message.content && message.content.parts) || [];
    const text = parts.map((p) => (typeof p === "string" ? p : p && p.text ? p.text : "")).join("\n").trim();
    if (!text) continue;
    rows.push({ at: message.create_time || 0, text: `**${role}:**\n${text}` });
  }
  rows.sort((a, b) => a.at - b.at);
  return rows.map((r) => r.text).join("\n\n");
}

function flattenClaude(conv) {
  const rows = (conv.chat_messages || []).map((m) => {
    const who = m.sender === "human" ? "user" : "assistant";
    const text = (m.text || "").trim();
    return text ? `**${who}:**\n${text}` : "";
  }).filter(Boolean);
  return rows.join("\n\n");
}

function fromJson(raw, file) {
  let parsed;
  try { parsed = JSON.parse(raw); } catch (_) { return [{ index: 0, title: file, text: raw.slice(0, 400000) }]; }
  const conversations = Array.isArray(parsed) ? parsed
    : Array.isArray(parsed && parsed.conversations) ? parsed.conversations
    : null;
  if (!conversations) {
    const text = parsed.chat_messages ? flattenClaude(parsed) : "";
    if (text) return [{ index: 0, title: parsed.name || parsed.title || file, text }];
    return [{ index: 0, title: file, text: JSON.stringify(parsed, null, 2).slice(0, 400000) }];
  }
  return conversations.map((conv, index) => {
    const text = conv.mapping ? flattenChatGpt(conv) : flattenClaude(conv);
    const title = conv.title || conv.name || `Conversation ${index + 1}`;
    return { index, title, text: text || "(no readable messages)" };
  }).filter((c) => c.text.length > 0);
}

async function readInboxFile(name) {
  const absolute = inboxPath(name);
  if (!absolute) return [];
  const ext = path.extname(absolute).toLowerCase();
  const raw = await fsp.readFile(absolute, "utf8");
  if (ext === ".json") return fromJson(raw, name).map((c) => ({ ...c, file: path.basename(name) }));
  const text = ext === ".html" || ext === ".htm" ? htmlToText(raw) : raw;
  return [{ index: 0, file: path.basename(name), title: firstHeading(text, path.basename(name)), text }];
}

async function listInbox() {
  let entries = [];
  try { entries = await fsp.readdir(INBOX, { withFileTypes: true }); } catch (_) { return []; }
  const out = [];
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    const absolute = path.join(INBOX, entry.name);
    if (!TEXT_EXT.has(path.extname(entry.name).toLowerCase())) continue;
    const st = await fsp.stat(absolute);
    let items = [];
    try { items = await readInboxFile(entry.name); } catch (_) { continue; }
    for (const item of items) {
      out.push({
        id: `${entry.name}::${item.index}`,
        file: entry.name,
        title: item.title,
        bytes: st.size,
        words: item.text.split(/\s+/).filter(Boolean).length,
        mtime: st.mtimeMs,
      });
    }
  }
  return out.sort((a, b) => b.mtime - a.mtime || a.title.localeCompare(b.title));
}

async function readInboxEntry(id) {
  const [file, indexRaw] = String(id || "").split("::");
  const items = await readInboxFile(file);
  const index = Number(indexRaw || 0);
  const item = items[index] || items[0];
  if (!item) throw new Error("nothing in that file");
  return { id, file: item.file, title: item.title, text: item.text };
}

/* ---------------- search ---------------- */

async function search(q) {
  const needle = String(q || "").toLowerCase().trim();
  if (needle.length < 2) return [];
  const hits = [];
  const push = (docPath, title, text, kind, link) => {
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length; i += 1) {
      const at = lines[i].toLowerCase().indexOf(needle);
      if (at === -1) continue;
      const start = Math.max(0, at - 60);
      hits.push({
        path: docPath,
        kind,
        title,
        link,
        line: i + 1,
        snippet: (start > 0 ? "…" : "") + lines[i].slice(start, start + 180),
      });
      if (hits.length > 140) return;
    }
  };
  for (const doc of await listDocs()) {
    const absolute = resolveDoc(doc.path);
    if (!absolute) continue;
    push(doc.path, doc.title, await fsp.readFile(absolute, "utf8"), "doc", `#/doc/${doc.path}`);
  }
  for (const note of await listNotes()) {
    const absolute = notePath(note.path);
    push(note.path, note.title, await fsp.readFile(absolute, "utf8"), "note", `#/note/${note.path}`);
  }
  for (const item of await listInbox()) {
    try {
      const entry = await readInboxEntry(item.id);
      push(`content/inbox/${entry.file}`, entry.title, entry.text, "archive", `#/archive/${encodeURIComponent(item.id)}`);
    } catch (_) { /* unreadable, skip */ }
  }
  return hits;
}

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".gif": "image/gif",
  ".avif": "image/avif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

async function serveStatic(res, absolute) {
  try {
    const data = await fsp.readFile(absolute);
    const ext = path.extname(absolute).toLowerCase();
    res.writeHead(200, {
      "content-type": MIME[ext] || "application/octet-stream",
      // The site is edited while it runs; a browser that keeps app.js in memory
      // would show yesterday's behaviour and call it a bug in the server.
      "cache-control": ext === ".js" || ext === ".css" ? "no-store" : "no-cache",
      "content-length": data.length,
    });
    res.end(data);
  } catch (_) {
    fail(res, 404, "not found");
  }
}

const server = http.createServer(async (req, res) => {
  const parsed = new URL(req.url || "/", "http://127.0.0.1");
  const pathname = decodeURIComponent(parsed.pathname || "/");
  const params = parsed.searchParams;
  try {
    if (pathname === "/api/docs" && req.method === "GET") return json(res, 200, await listDocs());

    if (pathname === "/api/doc" && req.method === "GET") {
      const absolute = resolveDoc(params.get("p"));
      if (!absolute) return fail(res, 400, "not an allowed document");
      const text = await fsp.readFile(absolute, "utf8");
      return json(res, 200, { path: params.get("p"), text });
    }

    if (pathname === "/api/note" && req.method === "GET") {
      const target = notePath(params.get("p"));
      if (!target) return fail(res, 400, "not a note");
      const text = await fsp.readFile(target, "utf8");
      return json(res, 200, { path: params.get("p"), text });
    }

    if (pathname === "/api/notes" && req.method === "GET") return json(res, 200, await listNotes());

    if (pathname === "/api/notes" && req.method === "POST") {
      const body = await readBody(req);
      const title = String(body.title || "").trim() || "Untitled";
      const text = String(body.body || "");
      const stamp = new Date().toISOString().slice(0, 10);
      let file = `${stamp}-${slugify(title)}.md`;
      let n = 2;
      while (fs.existsSync(path.join(NOTES, file))) file = `${stamp}-${slugify(title)}-${n++}.md`;
      // The title you typed is the note's title and its filename; a body that
      // happens to open with a different heading must not rename the note.
      const content = text.startsWith(`# ${title}`) ? text : `# ${title}\n\n${text}`;
      await fsp.writeFile(path.join(NOTES, file), content, "utf8");
      return json(res, 201, { path: `content/notes/${file}` });
    }

    if (pathname === "/api/notes" && (req.method === "PUT" || req.method === "DELETE")) {
      const target = notePath(params.get("p"));
      if (!target) return fail(res, 400, "not a note");
      if (req.method === "DELETE") {
        await fsp.unlink(target).catch(() => {});
        return json(res, 200, { ok: true });
      }
      const body = await readBody(req);
      await fsp.writeFile(target, String(body.body || ""), "utf8");
      return json(res, 200, { ok: true });
    }

    if (pathname === "/api/art" && req.method === "GET") return json(res, 200, await listArt());

    if (pathname === "/api/art" && req.method === "POST") {
      const body = await readBody(req);
      const match = /^data:image\/([a-z+]+);base64,(.+)$/i.exec(String(body.data || ""));
      if (!match) return fail(res, 400, "expected a base64 image");
      const ext = match[1] === "jpeg" ? "jpg" : match[1].replace("+xml", "");
      if (!IMAGE_EXT.has(`.${ext}`)) return fail(res, 400, "unsupported image type");
      const given = String(body.name || "art").replace(/\.[^.]+$/, "");
      const file = `${slugify(given)}-${Date.now().toString(36)}.${ext}`;
      await fsp.writeFile(path.join(ART, file), Buffer.from(match[2], "base64"));
      return json(res, 201, { url: `/art/${encodeURIComponent(file)}`, file });
    }

    if (pathname === "/api/inbox" && req.method === "GET") {
      if (params.get("id")) return json(res, 200, await readInboxEntry(params.get("id")));
      return json(res, 200, await listInbox());
    }

    if (pathname === "/api/inbox" && req.method === "POST") {
      const body = await readBody(req);
      const given = path.basename(String(body.name || "chat.txt"));
      const ext = path.extname(given).toLowerCase();
      if (!TEXT_EXT.has(ext)) return fail(res, 400, "markdown, text, html or json only");
      let file = slugify(given.replace(/\.[^.]+$/, "")) + ext;
      let n = 2;
      while (fs.existsSync(path.join(INBOX, file))) file = `${slugify(given.replace(/\.[^.]+$/, ""))}-${n++}${ext}`;
      const text = String(body.text || "");
      if (!text.trim()) return fail(res, 400, "nothing in that file");
      await fsp.writeFile(path.join(INBOX, file), text, "utf8");
      return json(res, 201, { file });
    }

    if (pathname === "/api/search" && req.method === "GET") return json(res, 200, await search(params.get("q")));

    if (pathname === "/api/state" && req.method === "GET") {
      const [docs, notes, art, inbox] = await Promise.all([listDocs(), listNotes(), listArt(), listInbox()]);
      return json(res, 200, {
        docs: docs.length,
        notes: notes.length,
        art: art.length,
        inbox: inbox.length,
        recentNotes: notes.slice(0, 5),
        recentArt: art.slice(0, 8),
        root: ROOT,
      });
    }

    if (pathname.startsWith("/art/")) {
      const file = path.basename(pathname);
      if (!IMAGE_EXT.has(path.extname(file).toLowerCase())) return fail(res, 404, "not found");
      return serveStatic(res, path.join(ART, file));
    }

    const relative = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
    const absolute = path.resolve(PUBLIC, relative);
    if (!absolute.startsWith(PUBLIC + path.sep) && absolute !== path.join(PUBLIC, "index.html")) {
      return fail(res, 403, "forbidden");
    }
    return serveStatic(res, absolute);
  } catch (error) {
    if (String(error.message).includes("body too large")) return fail(res, 413, "body too large");
    if (String(error.message).includes("JSON")) return fail(res, 400, "bad json");
    if (error && error.code === "ENOENT") return fail(res, 404, "not found");
    console.error(error);
    return fail(res, 500, "server error");
  }
});

server.listen(PORT, "127.0.0.1", () => {
  const address = `http://127.0.0.1:${PORT}`;
  console.log(`Wizards Only Fools dev site -> ${address}`);
  console.log(`repo:    ${ROOT}`);
  console.log(`notes:   ${NOTES}`);
  console.log(`art:     ${ART}`);
  console.log(`inbox:   ${INBOX}`);
  console.log("Ctrl+C to stop.");

  if (process.argv.includes("--open")) {
    const { spawn } = require("child_process");
    const [cmd, args] = process.platform === "win32" ? ["cmd", ["/c", "start", "", address]]
      : process.platform === "darwin" ? ["open", [address]]
      : ["xdg-open", [address]];
    try { spawn(cmd, args, { detached: true, stdio: "ignore" }).unref(); } catch (_) { /* the URL is on screen */ }
  }
});
