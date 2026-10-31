/* Wizards Only Fools — local dev site client.
   No framework, no build step. Everything comes from the local server. */

const $ = (sel, root = document) => root.querySelector(sel);
const el = (tag, attrs = {}, ...kids) => {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") node.className = v;
    else if (k === "html") node.innerHTML = v;
    else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
    else if (v !== null && v !== undefined) node.setAttribute(k, v);
  }
  for (const kid of kids.flat()) {
    if (kid === null || kid === undefined) continue;
    node.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  }
  return node;
};

const state = { docs: [], notes: [], art: [], inbox: [], plan: null, doc: null };

async function api(path, options) {
  const res = await fetch(path, options);
  const type = res.headers.get("content-type") || "";
  const body = type.includes("json") ? await res.json() : await res.text();
  if (!res.ok) throw new Error((body && body.error) || `request failed (${res.status})`);
  return body;
}

function toast(message) {
  const node = $("#toast");
  node.textContent = message;
  node.classList.add("on");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => node.classList.remove("on"), 2200);
}

const escapeHtml = (s) => String(s)
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#39;");

function inline(text) {
  let out = escapeHtml(text);
  out = out.replace(/`([^`]+)`/g, (_, code) => `<code>${code}</code>`);
  out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, label, href) => {
    const safe = href.replace(/"/g, "&quot;");
    return `<a href="${safe}">${label}</a>`;
  });
  out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  out = out.replace(/(^|[\s(])\*([^*\n]+)\*/g, "$1<em>$2</em>");
  return out;
}

/* Split a table row on pipes that are not inside backticks. */
function cells(line) {
  const trimmed = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  const out = [];
  let buf = "";
  let code = false;
  for (const ch of trimmed) {
    if (ch === "`") code = !code;
    if (ch === "|" && !code) { out.push(buf.trim()); buf = ""; } else buf += ch;
  }
  out.push(buf.trim());
  return out;
}

function markdown(src) {
  const lines = String(src).replace(/\r\n/g, "\n").split("\n");
  const html = [];
  let i = 0;

  const flushParagraph = (buf) => {
    if (buf.length) html.push(`<p>${inline(buf.join(" "))}</p>`);
    buf.length = 0;
  };
  const para = [];

  while (i < lines.length) {
    const line = lines[i];

    if (/^```/.test(line)) {
      flushParagraph(para);
      const lang = line.replace(/^```/, "").trim();
      const body = [];
      i += 1;
      while (i < lines.length && !/^```/.test(lines[i])) { body.push(lines[i]); i += 1; }
      i += 1;
      html.push(`<pre${lang ? ` data-lang="${escapeHtml(lang)}"` : ""}><code>${escapeHtml(body.join("\n"))}</code></pre>`);
      continue;
    }

    if (/^\s*$/.test(line)) { flushParagraph(para); i += 1; continue; }

    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      flushParagraph(para);
      const level = Math.max(2, heading[1].length); // h1 is the page title
      html.push(`<h${level}>${inline(heading[2])}</h${level}>`);
      i += 1;
      continue;
    }

    if (/^(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) { flushParagraph(para); html.push("<hr>"); i += 1; continue; }

    if (/^>\s?/.test(line)) {
      flushParagraph(para);
      const body = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) { body.push(lines[i].replace(/^>\s?/, "")); i += 1; }
      html.push(`<blockquote>${inline(body.join(" "))}</blockquote>`);
      continue;
    }

    if (/^\|/.test(line) && i + 1 < lines.length && /^\|?[\s:|-]+\|?$/.test(lines[i + 1])) {
      flushParagraph(para);
      const head = cells(line);
      i += 2;
      const rows = [];
      while (i < lines.length && /^\|/.test(lines[i])) { rows.push(cells(lines[i])); i += 1; }
      html.push(
        "<table><thead><tr>" + head.map((c) => `<th>${inline(c)}</th>`).join("") + "</tr></thead><tbody>" +
        rows.map((r) => "<tr>" + r.map((c) => `<td>${inline(c)}</td>`).join("") + "</tr>").join("") +
        "</tbody></table>"
      );
      continue;
    }

    if (/^\s*[-*]\s+/.test(line)) {
      flushParagraph(para);
      const items = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) { items.push(lines[i].replace(/^\s*[-*]\s+/, "")); i += 1; }
      html.push("<ul>" + items.map((t) => `<li>${inline(t)}</li>`).join("") + "</ul>");
      continue;
    }

    if (/^\s*\d+\.\s+/.test(line)) {
      flushParagraph(para);
      const items = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) { items.push(lines[i].replace(/^\s*\d+\.\s+/, "")); i += 1; }
      html.push("<ol>" + items.map((t) => `<li>${inline(t)}</li>`).join("") + "</ol>");
      continue;
    }

    para.push(line.trim());
    i += 1;
  }
  flushParagraph(para);
  return html.join("\n");
}

/* The page already prints the document's title as its h1; drop the file's own
   leading heading so the same words do not appear twice in a row. */
function withoutTitle(text, title) {
  const lines = String(text).replace(/\r\n/g, "\n").split("\n");
  let i = 0;
  while (i < lines.length && !lines[i].trim()) i += 1;
  if (i < lines.length && /^#\s+/.test(lines[i]) &&
      lines[i].replace(/^#\s+/, "").trim().toLowerCase() === String(title).trim().toLowerCase()) {
    lines.splice(0, i + 1);
    return lines.join("\n");
  }
  return text;
}

/* ---------------- the plan ---------------- */

/* PROMPT_ROADMAP.md keeps every brief in a ```text block under a heading like
   `## 3. `board-screen``. Read them out rather than duplicating them here. */
function parsePlan(src) {
  const lines = String(src).replace(/\r\n/g, "\n").split("\n");
  const out = [];
  for (let i = 0; i < lines.length; i += 1) {
    const head = /^##\s+(\d+)\.\s+`([^`]+)`\s*$/.exec(lines[i]);
    if (!head) continue;
    let j = i + 1;
    while (j < lines.length && !/^```text/.test(lines[j])) j += 1;
    if (j >= lines.length) continue;
    const body = [];
    j += 1;
    while (j < lines.length && !/^```\s*$/.test(lines[j])) { body.push(lines[j]); j += 1; }
    out.push({ n: Number(head[1]), slug: head[2], brief: body.join("\n"), goal: goalOf(body) });
    i = j;
  }
  return out.sort((a, b) => a.n - b.n);
}

function goalOf(body) {
  const at = body.findIndex((l) => /^GOAL\b/.test(l));
  if (at < 0) return "";
  const parts = [body[at].replace(/^GOAL\s*/, "").trim()];
  for (let i = at + 1; i < body.length; i += 1) {
    if (!/^\s{6,}\S/.test(body[i])) break;
    parts.push(body[i].trim());
  }
  return parts.join(" ");
}

async function loadPlan() {
  if (state.plan) return state.plan;
  try {
    const data = await api(`/api/doc?p=${encodeURIComponent("DESIGN/PROMPT_ROADMAP.md")}`);
    state.plan = parsePlan(data.text);
  } catch (_) { state.plan = []; }
  return state.plan;
}

/* ---------------- rail ---------------- */

function renderRail(activePath) {
  const rail = $("#rail");
  rail.innerHTML = "";
  const groups = new Map();
  for (const doc of state.docs) {
    if (!groups.has(doc.group)) groups.set(doc.group, []);
    groups.get(doc.group).push(doc);
  }
  const order = ["Front door", "Structure", "Roadmap", "Design", "Handoff"];
  const keys = [...groups.keys()].sort((a, b) => order.indexOf(a) - order.indexOf(b));

  for (const key of keys) {
    const list = el("ul");
    for (const doc of groups.get(key)) {
      const link = el("a", { href: `#/doc/${doc.path}` }, doc.title);
      if (activePath === doc.path) link.setAttribute("aria-current", "page");
      list.append(el("li", {}, link));
    }
    rail.append(el("div", { class: "group" }, el("h2", {}, key), list));
  }
  const notes = el("a", { href: "#/notes" }, `Notes (${state.notes.length})`);
  const art = el("a", { href: "#/art" }, `Art (${state.art.length})`);
  const plan = el("a", { href: "#/plan" }, "The plan");
  const archive = el("a", { href: "#/archive" }, `Archive (${state.inbox.length})`);
  rail.append(el("div", { class: "group" }, el("h2", {}, "Kept here"),
    el("ul", {}, el("li", {}, plan), el("li", {}, notes), el("li", {}, art), el("li", {}, archive))));
}

/* ---------------- side rail ---------------- */

function renderSide(doc) {
  const side = $("#side");
  side.innerHTML = "";
  if (doc) {
    side.append(el("section", {},
      el("h2", {}, "This document"),
      el("div", { class: "meta" },
        el("div", {}, el("b", {}, doc.path)),
        el("div", {}, `${doc.size.toLocaleString()} bytes`),
        el("div", {}, new Date(doc.mtime).toLocaleString()))));
  }
  side.append(el("section", {},
    el("h2", {}, "Recent notes"),
    state.notes.length
      ? el("ul", {}, state.notes.slice(0, 6).map((n) =>
          el("li", {}, el("a", { href: `#/note/${n.path}` }, n.title))))
      : el("div", { class: "empty" }, "No notes yet. Write the first one on the Notes page.")));

  if (state.art.length) {
    const strip = el("div", { class: "strip" });
    for (const piece of state.art.slice(0, 6)) {
      strip.append(el("figure", {},
        el("img", { src: piece.url, alt: piece.file, loading: "lazy" }),
        el("figcaption", {}, piece.file)));
    }
    side.append(el("section", {}, el("h2", {}, "Latest art"), strip));
  }
}

/* ---------------- views ---------------- */

function setTabs(view) {
  for (const link of document.querySelectorAll(".tabs a")) {
    if (link.dataset.view === view) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
}

async function viewHome() {
  setTabs("home");
  renderRail(null);
  const main = $("#main");
  main.innerHTML = "";

  const structure = [
    ["THE_SPINE.md", "Every verb, its owner, its record, its object, its asset and its sound."],
    ["THE_LADDER.md", "Five bands, forty seats, seven rows, and how a seat refills."],
    ["THE_CAST.md", "What a name sounds like, and how much a person is allowed to be."],
    ["THE_SCREEN.md", "Where the board physically is."],
    ["STYLE_RULES.md", "The gate a build has to pass before it reads as authored."],
  ];

  main.append(
    el("div", { class: "kicker" }, "The working document"),
    el("h1", {}, "Wizards Only Fools"),
    el("p", { class: "docmeta" },
      el("span", {}, el("b", {}, `${state.docs.length}`), " documents"),
      el("span", {}, el("b", {}, `${state.notes.length}`), " notes"),
      el("span", {}, el("b", {}, `${state.art.length}`), " images")),
    el("p", {}, "Structure first: the shapes that art, writing and level work hang on. ",
      "Answers and open questions live in the documents; ideas and sketches live in the notes and the gallery."),
  );

  const reading = el("div", { class: "reading" });
  for (const [file, blurb] of structure) {
    const doc = state.docs.find((d) => d.path === `DESIGN/${file}`);
    if (!doc) continue;
    reading.append(el("a", { href: `#/doc/${doc.path}` },
      el("b", {}, doc.title), el("span", {}, doc.path), el("p", {}, blurb)));
  }
  main.append(el("h2", {}, "Read in this order"), reading);

  const cards = el("div", { class: "home-grid" });
  const road = state.docs.find((d) => d.path === "DESIGN/PROMPT_ROADMAP.md");
  if (road) {
    cards.append(el("a", { class: "card", href: "#/plan" },
      el("div", { class: "n" }, String(state.plan ? state.plan.length : 14)),
      el("div", { class: "l" }, "briefs, in order"),
      el("p", {}, "Click one to read it, copy it, or hand it to an agent.")));
  }
  cards.append(
    el("a", { class: "card", href: "#/notes" },
      el("div", { class: "n" }, String(state.notes.length)), el("div", { class: "l" }, "notes"),
      el("p", {}, "Ideas, story beats, decisions — written in markdown, saved as files.")),
    el("a", { class: "card", href: "#/art" },
      el("div", { class: "n" }, String(state.art.length)), el("div", { class: "l" }, "images"),
      el("p", {}, "Drop concept art in; it stays on disk next to the site.")),
    el("a", { class: "card", href: "#/archive" },
      el("div", { class: "n" }, String(state.inbox.length)), el("div", { class: "l" }, "archived chats"),
      el("p", {}, "Old GPT and Claude exports, searchable next to everything else.")));
  main.append(el("h2", {}, "The queue"), cards);

  if (state.notes.length) {
    const list = el("ul", { class: "note-list" });
    for (const note of state.notes.slice(0, 4)) {
      list.append(el("li", {}, el("a", { href: `#/note/${note.path}` },
        el("time", {}, new Date(note.mtime).toLocaleDateString()),
        el("strong", {}, note.title),
        el("p", {}, note.excerpt || ""))));
    }
    main.append(el("h2", {}, "Latest notes"), list);
  }

  if (state.art.length) {
    const strip = el("div", { class: "strip" });
    for (const piece of state.art.slice(0, 8)) {
      strip.append(el("figure", { onclick: () => openLightbox(piece) },
        el("img", { src: piece.url, alt: piece.file, loading: "lazy" }),
        el("figcaption", {}, piece.file)));
    }
    main.append(el("h2", {}, "Art"), el("p", {}, "Click to enlarge."), strip);
  }

  renderSide(null);
}

async function viewDocs() {
  setTabs("docs");
  await refreshLists();
  const main = $("#main");
  main.innerHTML = "";
  main.append(el("div", { class: "kicker" }, "Everything on disk"),
    el("h1", {}, "Documents"),
    el("p", {}, "Every markdown file the repo keeps, newest first inside each group."));
  const groups = new Map();
  for (const doc of state.docs) {
    if (!groups.has(doc.group)) groups.set(doc.group, []);
    groups.get(doc.group).push(doc);
  }
  for (const [key, docs] of groups) {
    main.append(el("h2", {}, key));
    const list = el("ul", { class: "note-list" });
    for (const doc of docs) {
      list.append(el("li", {}, el("a", { href: `#/doc/${doc.path}` },
        el("time", {}, new Date(doc.mtime).toLocaleDateString()),
        el("strong", {}, doc.title),
        el("p", {}, doc.path))));
    }
    main.append(list);
  }
  renderSide(null);
}

async function viewDoc(path) {
  setTabs("docs");
  const main = $("#main");
  main.innerHTML = el("div", { class: "empty" }, "Loading…");
  const doc = state.docs.find((d) => d.path === path) || { path, title: path, mtime: Date.now(), size: 0 };
  const data = await api(`/api/doc?p=${encodeURIComponent(path)}`);
  state.doc = doc;
  renderRail(path);
  renderSide(doc);
  main.innerHTML = "";
  main.append(
    el("div", { class: "kicker" }, doc.group || "Document"),
    el("h1", {}, doc.title),
    el("div", { class: "docmeta" },
      el("span", {}, el("b", {}, path)),
      el("span", {}, new Date(doc.mtime).toLocaleString()),
      el("span", {}, el("a", {
        href: `#/doc/${path}`,
        onclick: (event) => { event.preventDefault(); navigator.clipboard?.writeText(path); toast("path copied"); },
      }, "copy path"))),
  );
  const article = el("article", { html: markdown(withoutTitle(data.text, doc.title)) });
  main.append(article);

  // In-document links: keep #/ links, map other markdown files to the reader.
  for (const a of article.querySelectorAll("a[href]")) {
    const href = a.getAttribute("href");
    if (!href || /^https?:/i.test(href) || href.startsWith("#")) continue;
    if (href.endsWith(".md")) {
      const base = path.split("/").slice(0, -1).join("/");
      const resolved = href.startsWith("../") ? href.replace(/^\.\.\//, "") : (href.includes("/") ? href : `${base}/${href}`);
      a.setAttribute("href", `#/doc/${resolved}`);
      a.addEventListener("click", (e) => { e.preventDefault(); location.hash = `#/doc/${resolved}`; });
    }
  }
  window.scrollTo({ top: 0 });
}

async function viewNotes() {
  setTabs("notes");
  await refreshLists();
  renderSide(null);
  const main = $("#main");
  main.innerHTML = "";

  const title = el("input", { type: "text", placeholder: "What is this about", "aria-label": "Note title" });
  const body = el("textarea", { placeholder: "Write in markdown. # heading, - list, **bold**, `code`.\n\nA note is a file in devsite/content/notes/ — greppable, portable, yours.", "aria-label": "Note body" });
  const save = el("button", { type: "button", onclick: async () => {
    if (!body.value.trim() && !title.value.trim()) return toast("nothing to save");
    save.disabled = true;
    try {
      const res = await api("/api/notes", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ title: title.value, body: body.value }),
      });
      await refreshLists();
      toast("note saved");
      location.hash = `#/note/${res.path}`;
    } catch (error) { toast(error.message); save.disabled = false; }
  } }, "Save note");

  main.append(
    el("div", { class: "kicker" }, "Blog, story structure, decisions"),
    el("h1", {}, "Notes"),
    el("div", { class: "editor" }, title, body, el("div", { class: "row" }, save,
      el("button", { class: "ghost", type: "button", onclick: () => { title.value = ""; body.value = ""; title.focus(); } }, "Clear"))),
    el("h2", {}, `Written so far (${state.notes.length})`));

  if (!state.notes.length) main.append(el("div", { class: "empty" }, "Nothing yet. The first note is the one you write now."));
  const list = el("ul", { class: "note-list" });
  for (const note of state.notes) {
    list.append(el("li", {}, el("a", { href: `#/note/${note.path}` },
      el("time", {}, new Date(note.mtime).toLocaleString()),
      el("strong", {}, note.title),
      el("p", {}, note.excerpt || ""))));
  }
  main.append(list);
}

async function viewNote(notePath) {
  setTabs("notes");
  renderRail(null);
  renderSide(null);
  const main = $("#main");
  main.innerHTML = el("div", { class: "empty" }, "Loading…");
  const text = await api(`/api/note?p=${encodeURIComponent(notePath)}`)
    .then((data) => data.text || "")
    .catch(() => "");
  const meta = state.notes.find((n) => n.path === notePath);
  main.innerHTML = "";
  main.append(
    el("div", { class: "kicker" }, "Note"),
    el("h1", {}, meta ? meta.title : notePath),
    el("div", { class: "docmeta" },
      el("span", {}, el("b", {}, notePath)),
      el("span", {}, meta ? new Date(meta.mtime).toLocaleString() : ""),
      el("span", {}, el("button", { class: "ghost", type: "button", onclick: () => editNote(notePath, text) }, "Edit"))),
    el("article", { html: markdown(withoutTitle(text, meta ? meta.title : notePath)) }));
}

function editNote(notePath, text) {
  const main = $("#main");
  const body = el("textarea", { class: "" });
  body.value = text;
  main.innerHTML = "";
  main.append(
    el("div", { class: "kicker" }, "Editing"),
    el("h1", {}, notePath.split("/").pop().replace(/\.md$/, "")),
    el("div", { class: "editor" }, body,
      el("div", { class: "row" },
        el("button", { type: "button", onclick: async () => {
          await api(`/api/notes?p=${encodeURIComponent(notePath)}`, {
            method: "PUT",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ body: body.value }),
          });
          await refreshLists();
          toast("saved");
          location.hash = `#/note/${notePath}`;
        } }, "Save"),
        el("button", { class: "ghost", type: "button", onclick: () => { location.hash = `#/note/${notePath}`; } }, "Cancel"),
        el("button", { class: "danger", type: "button", onclick: async () => {
          if (!confirm("Delete this note?")) return;
          await api(`/api/notes?p=${encodeURIComponent(notePath)}`, { method: "DELETE" });
          await refreshLists();
          toast("deleted");
          location.hash = "#/notes";
        } }, "Delete"))));
}

async function viewArt() {
  setTabs("art");
  await refreshLists();
  renderSide(null);
  const main = $("#main");
  main.innerHTML = "";

  const input = el("input", { type: "file", accept: "image/*", multiple: "", hidden: "" });
  const drop = el("div", { class: "drop" }, "Drop concept art here, or ", el("button", {
    class: "ghost", type: "button", onclick: () => input.click(),
  }, "choose files"), " — png, jpg, webp, gif");
  input.addEventListener("change", () => uploadArt([...input.files]));

  drop.addEventListener("dragover", (e) => { e.preventDefault(); drop.classList.add("over"); });
  drop.addEventListener("dragleave", () => drop.classList.remove("over"));
  drop.addEventListener("drop", (e) => {
    e.preventDefault();
    drop.classList.remove("over");
    uploadArt([...e.dataTransfer.files]);
  });

  main.append(
    el("div", { class: "kicker" }, "Concept art, plates, screenshots"),
    el("h1", {}, "Art"),
    el("p", {}, "Files land in ", el("code", {}, "devsite/content/art/"), " and stay there. Nothing is uploaded anywhere else."),
    drop, input,
    el("h2", {}, `Gallery (${state.art.length})`));

  if (!state.art.length) {
    main.append(el("div", { class: "empty" }, "No images yet. The first one is the one you drop in."));
    return;
  }
  const gallery = el("div", { class: "gallery" });
  for (const piece of state.art) {
    gallery.append(el("figure", { onclick: () => openLightbox(piece) },
      el("img", { src: piece.url, alt: piece.file, loading: "lazy" }),
      el("figcaption", {}, piece.file)));
  }
  main.append(gallery);
}

async function uploadArt(files) {
  const images = files.filter((f) => f.type.startsWith("image/"));
  if (!images.length) return toast("no images in that drop");
  for (const file of images) {
    const data = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
    try {
      await api("/api/art", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ name: file.name, data }),
      });
      toast(`added ${file.name}`);
    } catch (error) { toast(error.message); }
  }
  await refreshLists();
  if (location.hash.startsWith("#/art")) viewArt();
}

function openLightbox(piece) {
  $("#lightbox-img").src = piece.url;
  $("#lightbox-img").alt = piece.file;
  $("#lightbox-cap").textContent = piece.file;
  $("#lightbox").hidden = false;
}
function closeLightbox() { $("#lightbox").hidden = true; }

async function viewSearch(query) {
  setTabs("docs");
  renderRail(null);
  renderSide(null);
  const main = $("#main");
  main.innerHTML = el("div", { class: "empty" }, "Searching…");
  const hits = await api(`/api/search?q=${encodeURIComponent(query)}`);
  const linkFor = (hit) => hit.link || (hit.kind === "note" ? `#/note/${hit.path}` : `#/doc/${hit.path}`);
  main.innerHTML = "";
  main.append(el("div", { class: "kicker" }, "Search"),
    el("h1", {}, `“${query}”`),
    el("p", {}, `${hits.length} line${hits.length === 1 ? "" : "s"} across documents and notes.`));
  if (!hits.length) {
    main.append(el("div", { class: "empty" }, "Nothing matched. Try a shorter word."));
    return;
  }
  const list = el("ul", { class: "hits" });
  for (const hit of hits.slice(0, 80)) {
    const href = linkFor(hit);
    const safe = escapeHtml(hit.snippet).replace(new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "gi"), (m) => `<mark>${m}</mark>`);
    list.append(el("li", {},
      el("a", { href }, hit.title),
      el("div", { class: "where" }, `${hit.path}:${hit.line}`),
      el("div", { class: "snip", html: safe })));
  }
  main.append(list);
}

/* ---------------- plan views ---------------- */

async function viewPlan() {
  setTabs("plan");
  renderRail(null);
  renderSide(null);
  const main = $("#main");
  main.innerHTML = el("div", { class: "empty" }, "Reading the roadmap…");
  const plan = await loadPlan();
  main.innerHTML = "";
  main.append(
    el("div", { class: "kicker" }, "The queue"),
    el("h1", {}, "Plan"),
    el("p", {}, "Every brief in ", el("a", { href: "#/doc/DESIGN/PROMPT_ROADMAP.md" }, "PROMPT_ROADMAP.md"),
      ", read out of the document itself. Click one to read it whole and copy it."),
  );
  if (!plan.length) {
    main.append(el("div", { class: "empty" }, "No briefs found. The roadmap heading format may have changed."));
    return;
  }
  const grid = el("div", { class: "plan-grid" });
  for (const brief of plan) {
    grid.append(el("a", { href: `#/brief/${brief.n}` },
      el("div", { class: "n" }, String(brief.n).padStart(2, "0")),
      el("div", { class: "l" }, brief.slug),
      el("p", {}, brief.goal)));
  }
  main.append(grid);
}

async function viewBrief(n) {
  setTabs("plan");
  renderRail(null);
  const main = $("#main");
  const plan = await loadPlan();
  const brief = plan.find((b) => b.n === Number(n));
  if (!brief) {
    main.innerHTML = "";
    main.append(el("div", { class: "kicker" }, "Not in the plan"),
      el("h1", {}, `Brief ${n}`),
      el("p", {}, el("a", { href: "#/plan" }, "Back to the plan")));
    return;
  }
  renderSide(null);
  main.innerHTML = "";
  const before = plan.find((b) => b.n === brief.n - 1);
  const after = plan.find((b) => b.n === brief.n + 1);
  main.append(
    el("div", { class: "kicker" }, `Brief ${brief.n} of ${plan.length}`),
    el("h1", {}, brief.slug),
    el("p", {}, brief.goal),
    el("div", { class: "row", style: "margin:0 0 18px" },
      el("button", { type: "button", onclick: () => {
        navigator.clipboard?.writeText(brief.brief).then(() => toast("brief copied"), () => toast("copy failed — select it"));
      } }, "Copy brief"),
      el("a", { class: "btn ghost", href: "#/doc/DESIGN/PROMPT_ROADMAP.md" }, "In the roadmap"),
      before ? el("a", { class: "btn ghost", href: `#/brief/${before.n}` }, `← ${before.slug}`) : null,
      after ? el("a", { class: "btn ghost", href: `#/brief/${after.n}` }, `${after.slug} →`) : null),
    el("pre", { class: "brief" }, el("code", {}, brief.brief)),
  );
  window.scrollTo({ top: 0 });
}

/* ---------------- archive ---------------- */

async function viewArchive() {
  setTabs("archive");
  // The folder can change while the page is open — files copied in by hand —
  // so read it again rather than trusting what boot saw.
  await refreshLists();
  renderSide(null);
  const main = $("#main");
  main.innerHTML = "";

  const input = el("input", { type: "file", accept: ".md,.txt,.json,.html,.htm", multiple: "", hidden: "" });
  const drop = el("div", { class: "drop" },
    "Drop chat exports here — .json from ChatGPT or Claude, or .md/.txt/.html. Or ",
    el("button", { class: "ghost", type: "button", onclick: () => input.click() }, "choose files"),
    el("div", { class: "fine" }, "They are copied into devsite/content/inbox/ and read here. Search covers them."));
  input.addEventListener("change", () => addToInbox([...input.files]));
  drop.addEventListener("dragover", (e) => { e.preventDefault(); drop.classList.add("over"); });
  drop.addEventListener("dragleave", () => drop.classList.remove("over"));
  drop.addEventListener("drop", (e) => { e.preventDefault(); drop.classList.remove("over"); addToInbox([...e.dataTransfer.files]); });

  main.append(
    el("div", { class: "kicker" }, "Old chats, stray text, other people's ideas"),
    el("h1", {}, "Archive"),
    el("p", {}, "Everything dropped in ", el("code", {}, "devsite/content/inbox/"),
      " — including conversations pulled out of a ChatGPT or Claude export. Nothing leaves this machine."),
    drop, input,
    el("h2", {}, `Held (${state.inbox.length})`));

  if (!state.inbox.length) {
    main.append(el("div", { class: "empty" }, "Nothing archived yet. Drop a file in, or copy one into devsite/content/inbox/ by hand."));
    return;
  }
  const list = el("ul", { class: "note-list" });
  for (const item of state.inbox) {
    list.append(el("li", {}, el("a", { href: `#/archive/${encodeURIComponent(item.id)}` },
      el("time", {}, `${item.file} · ${item.words.toLocaleString()} words · ${new Date(item.mtime).toLocaleDateString()}`),
      el("strong", {}, item.title))));
  }
  main.append(list);
}

async function viewArchiveEntry(id) {
  setTabs("archive");
  renderRail(null);
  renderSide(null);
  const main = $("#main");
  main.innerHTML = el("div", { class: "empty" }, "Loading…");
  const data = await api(`/api/inbox?id=${encodeURIComponent(id)}`);
  main.innerHTML = "";
  main.append(
    el("div", { class: "kicker" }, "Archive"),
    el("h1", {}, data.title),
    el("div", { class: "docmeta" },
      el("span", {}, el("b", {}, `content/inbox/${data.file}`)),
      el("span", {}, el("a", { href: "#/archive" }, "back to the archive"))),
    el("article", { html: markdown(withoutTitle(data.text, data.title)) }));
  window.scrollTo({ top: 0 });
}

async function addToInbox(files) {
  const usable = files.filter((f) => /\.(md|markdown|txt|text|json|html|htm)$/i.test(f.name));
  if (!usable.length) return toast("markdown, text, html or json only");
  for (const file of usable) {
    try {
      const text = await file.text();
      await api("/api/inbox", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ name: file.name, text }),
      });
      toast(`archived ${file.name}`);
    } catch (error) { toast(`${file.name}: ${error.message}`); }
  }
  await refreshLists();
  if (location.hash.startsWith("#/archive")) viewArchive();
}

/* ---------------- boot ---------------- */

async function refreshLists() {
  const [docs, notes, art, inbox] = await Promise.all([
    api("/api/docs"), api("/api/notes"), api("/api/art"), api("/api/inbox"),
  ]);
  state.docs = docs; state.notes = notes; state.art = art; state.inbox = inbox;
  renderRail(state.doc ? state.doc.path : null);
}

async function route() {
  const hash = location.hash || "#/";
  const [pathPart, queryPart] = hash.slice(2).split("?");
  const query = queryPart ? new URLSearchParams(queryPart).get("q") : "";

  try {
    if (pathPart.startsWith("doc/")) return viewDoc(decodeURIComponent(pathPart.slice(4)));
    if (pathPart.startsWith("note/")) return viewNote(decodeURIComponent(pathPart.slice(5)));
    if (pathPart.startsWith("archive/")) return viewArchiveEntry(decodeURIComponent(pathPart.slice(8)));
    if (pathPart.startsWith("brief/")) return viewBrief(decodeURIComponent(pathPart.slice(6)));
    if (pathPart === "plan") return viewPlan();
    if (pathPart === "archive") return viewArchive();
    if (pathPart === "notes") return viewNotes();
    if (pathPart === "art") return viewArt();
    if (pathPart === "docs") return viewDocs();
    if (pathPart === "search") return viewSearch(query || "");
    return viewHome();
  } catch (error) {
    $("#main").innerHTML = "";
    $("#main").append(el("div", { class: "kicker" }, "Something failed"),
      el("h1", {}, "Not found"),
      el("p", {}, error.message),
      el("p", {}, el("a", { href: "#/" }, "Back to the front")));
  }
}

$("#find").addEventListener("submit", (e) => {
  e.preventDefault();
  const q = $("#q").value.trim();
  if (q) location.hash = `#/search?q=${encodeURIComponent(q)}`;
});

document.addEventListener("keydown", (e) => {
  if (e.key === "/" && document.activeElement?.tagName !== "INPUT" && document.activeElement?.tagName !== "TEXTAREA") {
    e.preventDefault();
    $("#q").focus();
  }
  if (e.key === "Escape") { closeLightbox(); }
});

$("#lightbox").addEventListener("click", (e) => { if (e.target.id === "lightbox") closeLightbox(); });
$("#lightbox-close").addEventListener("click", closeLightbox);

window.addEventListener("hashchange", route);

(async function start() {
  try {
    await refreshLists();
  } catch (error) {
    $("#main").append(el("div", { class: "empty" }, `Could not reach the local server: ${error.message}`));
    return;
  }
  route();
})();
