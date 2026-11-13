#!/usr/bin/env node
// tools/docsite.mjs -- render docs/*.md into a static site for Vercel previews.
//
// Deliberately dependency free: CI runs it with the Node runtime that the
// runner already provides, so a docs preview never depends on the npm
// registry, a framework preset or a Vercel build image.
//
//   node tools/docsite.mjs docs site
//
// The renderer covers the subset of Markdown that this repository actually
// uses: headings, paragraphs, fenced code, indented code, block quotes,
// ordered/unordered lists, tables, horizontal rules, and inline code/bold/
// italic/links/images. Everything is HTML-escaped first, so documentation
// cannot inject markup into the published site.

import { mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";
import { pathToFileURL } from "node:url";

export function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function escapeAttr(value) {
  return escapeHtml(value).replaceAll("'", "&#39;");
}

// Only relative links and absolute https URLs survive: a docs page must not
// pull arbitrary schemes (javascript:, data:) into the preview origin.
export function safeHref(href) {
  const trimmed = href.trim();
  if (trimmed === "") return "";
  if (trimmed.startsWith("#")) return trimmed;
  if (trimmed.startsWith("./") || trimmed.startsWith("../")) return trimmed;
  if (/^https:\/\/[^\s]+$/i.test(trimmed)) return trimmed;
  if (/^[a-zA-Z0-9._/-]+$/.test(trimmed) && !trimmed.includes("://")) return trimmed;
  return "";
}

function renderInline(text) {
  // Placeholders keep code spans literal while the rest is still escaped.
  const codes = [];
  let out = escapeHtml(text).replace(/`([^`]+)`/g, (_match, code) => {
    codes.push(code);
    return `\u0000${codes.length - 1}\u0000`;
  });

  out = out.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, (match, alt, src) => {
    const safe = safeHref(src);
    if (safe === "") return escapeHtml(alt);
    return `<img src="${escapeAttr(safe)}" alt="${escapeAttr(alt)}">`;
  });

  out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (match, label, href) => {
    const safe = safeHref(href);
    if (safe === "") return label;
    return `<a href="${escapeAttr(safe)}">${label}</a>`;
  });

  out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  out = out.replace(/(^|[\s(])\*([^*\n]+)\*/g, "$1<em>$2</em>");
  out = out.replace(/(^|[\s(])_([^_\n]+)_/g, "$1<em>$2</em>");

  return out.replace(/\u0000(\d+)\u0000/g, (_match, index) => `<code>${codes[Number(index)]}</code>`);
}

function splitTableRow(line) {
  const trimmed = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  return trimmed.split("|").map((cell) => cell.trim());
}

function isTableDivider(line) {
  return /^\s*\|?[\s:-]*-[-\s:|]*$/.test(line) && line.includes("-");
}

export function renderMarkdown(source) {
  const lines = source.replaceAll("\r\n", "\n").split("\n");
  const html = [];
  let index = 0;

  const startList = (ordered) => {
    const items = [];
    while (index < lines.length) {
      const line = lines[index];
      const match = ordered ? /^\s*\d+\.\s+(.*)$/.exec(line) : /^\s*[-*+]\s+(.*)$/.exec(line);
      if (!match) break;
      items.push(`<li>${renderInline(match[1])}</li>`);
      index += 1;
      // Continuation lines indented under the item stay in the same item.
      while (index < lines.length && /^\s{2,}\S/.test(lines[index]) && !/^\s*([-*+]|\d+\.)\s+/.test(lines[index])) {
        const extra = renderInline(lines[index].trim());
        items[items.length - 1] = items[items.length - 1].replace(/<\/li>$/, ` ${extra}</li>`);
        index += 1;
      }
    }
    html.push(ordered ? `<ol>\n${items.join("\n")}\n</ol>` : `<ul>\n${items.join("\n")}\n</ul>`);
  };

  while (index < lines.length) {
    const line = lines[index];

    if (/^\s*$/.test(line)) {
      index += 1;
      continue;
    }

    if (/^\s*```/.test(line)) {
      index += 1;
      const body = [];
      while (index < lines.length && !/^\s*```/.test(lines[index])) {
        body.push(lines[index]);
        index += 1;
      }
      index += 1;
      html.push(`<pre><code>${escapeHtml(body.join("\n"))}</code></pre>`);
      continue;
    }

    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      const level = heading[1].length;
      html.push(`<h${level}>${renderInline(heading[2].trim())}</h${level}>`);
      index += 1;
      continue;
    }

    if (/^\s*([-*_])\s*\1\s*\1[\s\-*_]*$/.test(line)) {
      html.push("<hr>");
      index += 1;
      continue;
    }

    if (/^\s*>/.test(line)) {
      const body = [];
      while (index < lines.length && /^\s*>/.test(lines[index])) {
        body.push(lines[index].replace(/^\s*>\s?/, ""));
        index += 1;
      }
      html.push(`<blockquote>${renderMarkdown(body.join("\n"))}</blockquote>`);
      continue;
    }

    if (line.includes("|") && index + 1 < lines.length && isTableDivider(lines[index + 1])) {
      const head = splitTableRow(line);
      index += 2;
      const rows = [];
      while (index < lines.length && lines[index].includes("|") && !/^\s*$/.test(lines[index])) {
        rows.push(splitTableRow(lines[index]));
        index += 1;
      }
      const headHtml = head.map((cell) => `<th>${renderInline(cell)}</th>`).join("");
      const rowsHtml = rows
        .map((row) => `<tr>${row.map((cell) => `<td>${renderInline(cell)}</td>`).join("")}</tr>`)
        .join("\n");
      html.push(`<table>\n<thead><tr>${headHtml}</tr></thead>\n<tbody>\n${rowsHtml}\n</tbody>\n</table>`);
      continue;
    }

    if (/^\s*\d+\.\s+/.test(line)) {
      startList(true);
      continue;
    }

    if (/^\s*[-*+]\s+/.test(line)) {
      startList(false);
      continue;
    }

    if (/^\s{4}\S/.test(line)) {
      const body = [];
      while (index < lines.length && (/^\s{4}/.test(lines[index]) || /^\s*$/.test(lines[index]))) {
        body.push(lines[index].replace(/^ {4}/, ""));
        index += 1;
      }
      html.push(`<pre><code>${escapeHtml(body.join("\n").replace(/\n+$/, ""))}</code></pre>`);
      continue;
    }

    const paragraph = [];
    while (
      index < lines.length &&
      !/^\s*$/.test(lines[index]) &&
      !/^(#{1,6})\s+/.test(lines[index]) &&
      !/^\s*```/.test(lines[index]) &&
      !/^\s*>/.test(lines[index]) &&
      !/^\s*([-*+]|\d+\.)\s+/.test(lines[index])
    ) {
      paragraph.push(lines[index].trim());
      index += 1;
    }
    html.push(`<p>${renderInline(paragraph.join(" "))}</p>`);
  }

  return html.join("\n");
}

export function documentTitle(source, fallback) {
  const heading = /^#\s+(.+)$/m.exec(source);
  if (heading) return heading[1].trim();
  return fallback;
}

function page(title, body, { home = false } = {}) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<link rel="stylesheet" href="${home ? "" : "../"}assets/docsite.css">
</head>
<body>
<header class="docsite-header">
<a class="docsite-brand" href="${home ? "index.html" : "../index.html"}">Sayanox</a>
<nav><a href="${home ? "" : "../"}index.html#documents">All documents</a></nav>
</header>
<main class="docsite-main">
${body}
</main>
<footer class="docsite-footer">Generated from the repository documentation by <code>tools/docsite.mjs</code>.</footer>
</body>
</html>
`;
}

const STYLESHEET = `:root {
  color-scheme: light dark;
  --bg: #ffffff;
  --fg: #1c1e21;
  --muted: #5c6470;
  --line: #e3e6ea;
  --code: #f4f6f8;
  --accent: #0b6b53;
}
@media (prefers-color-scheme: dark) {
  :root { --bg: #14171a; --fg: #e8eaed; --muted: #9aa4b0; --line: #2a2f35; --code: #1d2126; --accent: #6fd3b4; }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}
.docsite-header {
  display: flex;
  gap: 1.5rem;
  align-items: baseline;
  padding: 0.9rem 1.25rem;
  border-bottom: 1px solid var(--line);
  position: sticky;
  top: 0;
  background: var(--bg);
}
.docsite-brand { font-weight: 700; color: var(--accent); text-decoration: none; letter-spacing: 0.02em; }
.docsite-header nav a { color: var(--muted); text-decoration: none; font-size: 0.9rem; }
.docsite-main { max-width: 60rem; margin: 0 auto; padding: 2rem 1.25rem 4rem; }
.docsite-footer { border-top: 1px solid var(--line); color: var(--muted); font-size: 0.85rem; padding: 1.25rem; text-align: center; }
h1, h2, h3, h4 { line-height: 1.25; margin: 2rem 0 0.75rem; }
h1 { margin-top: 0; font-size: 2rem; }
h2 { font-size: 1.45rem; border-bottom: 1px solid var(--line); padding-bottom: 0.35rem; }
h3 { font-size: 1.15rem; }
a { color: var(--accent); }
code { background: var(--code); padding: 0.1rem 0.35rem; border-radius: 4px; font-size: 0.88em; }
pre { background: var(--code); padding: 1rem; border-radius: 8px; overflow-x: auto; }
pre code { background: none; padding: 0; }
blockquote { margin: 1rem 0; padding: 0.25rem 1rem; border-left: 3px solid var(--accent); color: var(--muted); }
table { border-collapse: collapse; width: 100%; margin: 1rem 0; display: block; overflow-x: auto; }
th, td { border: 1px solid var(--line); padding: 0.45rem 0.7rem; text-align: left; vertical-align: top; }
hr { border: 0; border-top: 1px solid var(--line); margin: 2rem 0; }
ul, ol { padding-left: 1.4rem; }
img { max-width: 100%; }
.docindex { list-style: none; padding: 0; display: grid; gap: 0.5rem; }
.docindex li a { display: block; padding: 0.7rem 0.9rem; border: 1px solid var(--line); border-radius: 8px; text-decoration: none; }
.docindex li a:hover { border-color: var(--accent); }
.docindex .docname { display: block; font-weight: 600; }
.docindex .docdesc { display: block; color: var(--muted); font-size: 0.85rem; }
`;

export async function buildSite(sourceDir, outDir) {
  const entries = await readdir(sourceDir, { withFileTypes: true });
  const documents = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));

  if (documents.length === 0) {
    throw new Error(`no Markdown documents found in ${sourceDir}`);
  }

  await rm(outDir, { recursive: true, force: true });
  await mkdir(join(outDir, "assets"), { recursive: true });
  await mkdir(join(outDir, "docs"), { recursive: true });
  await writeFile(join(outDir, "assets", "docsite.css"), STYLESHEET);

  const index = [];
  for (const name of documents) {
    const source = await readFile(join(sourceDir, name), "utf8");
    const title = documentTitle(source, basename(name, ".md"));
    const slug = basename(name, ".md").toLowerCase().replace(/[^a-z0-9._-]+/g, "-");
    index.push({ title, slug, name });
  }

  // Cross-document links are written as ``NAME.md`` in the sources; inside the
  // generated site they must point at the rendered page instead.
  const pages = new Map(index.map((doc) => [basename(doc.name, ".md").toLowerCase(), `${doc.slug}.html`]));
  const linkToPage = (html) =>
    html.replace(/href="([^"#]+?)\.md(#[^"]*)?"/g, (match, target, fragment = "") => {
      const page = pages.get(basename(target).toLowerCase());
      return page === undefined ? match : `href="${page}${fragment}"`;
    });

  for (const doc of index) {
    const source = await readFile(join(sourceDir, doc.name), "utf8");
    const body = linkToPage(renderMarkdown(source));
    await writeFile(join(outDir, "docs", `${doc.slug}.html`), page(doc.title, body));
  }

  const items = index
    .map(
      (doc) =>
        `  <li><a href="docs/${escapeAttr(doc.slug)}.html"><span class="docname">${escapeHtml(
          doc.title,
        )}</span><span class="docdesc">docs/${escapeHtml(doc.name)}</span></a></li>`,
    )
    .join("\n");

  const home = `<h1>Sayanox documentation</h1>
<p>A self-hosting compiler and toolchain. Every document below is generated from
<code>docs/*.md</code> in this repository at build time.</p>
<ul class="docindex" id="documents">
${items}
</ul>`;

  await writeFile(join(outDir, "index.html"), page("Sayanox documentation", home, { home: true }));
  return index.length;
}

async function main(argv) {
  const [sourceDir = "docs", outDir = "site"] = argv;
  const count = await buildSite(sourceDir, outDir);
  console.log(`[OK] documentation site: ${count} document(s) -> ${outDir}`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(`docsite: ${error.message}`);
    process.exit(1);
  });
}
