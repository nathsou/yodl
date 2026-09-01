import { mkdir, cp, readFile, writeFile, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { loadChapters, escapeHTML as e, plainText } from './content.ts';
import type { Chapter } from './content.ts';
import { chapterLessons } from './links.ts';

const root = resolve(import.meta.dir, '../..');
const destination = resolve(root, process.argv[2] ?? 'dist');
if (destination !== resolve(root, 'dist')) throw new Error('The site build writes only to dist/');
const chapters = loadChapters(root);
const version = JSON.parse(await readFile(resolve(root, 'moon.mod.json'), 'utf8')).version;
const revision = process.env.YODL_REVISION?.slice(0, 7) || Bun.spawnSync(['git', 'rev-parse', '--short', 'HEAD'], { cwd: root }).stdout.toString().trim() || 'local';
await rm(destination, { recursive: true, force: true });
await mkdir(`${destination}/book`, { recursive: true });
await mkdir(`${destination}/bundle`, { recursive: true });

function page(chapter: Chapter, index: number) {
    const description = `${chapter.title} in Yodl. Learn the language with editable examples and inspect the hardware compiler output.`;
    const nav = chapters.map((c, i) => `<a href="./${c.slug}.html" ${i === index ? 'aria-current="page"' : ''}><span>${String(i + 1).padStart(2, '0')}</span>${e(c.title)}</a>`).join('');
    const toc = chapter.headings.filter(h => h.level > 1 && h.level < 4).map(h => `<a href="#${e(h.id)}" class="toc-level-${h.level}">${e(h.title)}</a>`).join('');
    const previous = chapters[index - 1], next = chapters[index + 1];
    const lessons = chapterLessons[chapter.slug] ?? [];
    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${e(chapter.title)} · Yodl</title><meta name="description" content="${e(description)}"><meta property="og:title" content="${e(chapter.title)} · Yodl"><meta property="og:description" content="${e(description)}"><meta property="og:type" content="article"><meta name="color-scheme" content="light dark"><link rel="stylesheet" href="../docs.css"><script>document.documentElement.classList.add('js');try{const t=localStorage.getItem('yodl-playground-v2:theme');document.documentElement.dataset.theme=t==='dark'||(t!=='light'&&matchMedia('(prefers-color-scheme: dark)').matches)?'dark':'light'}catch{}</script></head>
<body><a class="skip-link" href="#content">Skip to content</a>
<header class="site-header"><a class="brand" href="./index.html">yodl<span>/</span><small>documentation</small></a><nav class="top-nav" aria-label="Yodl"><a href="./index.html" aria-current="page">Docs</a><a href="../playground.html">Tour</a><a href="../playground.html?mode=examples">Playground ↗</a></nav><label class="theme-label js-only"><span class="sr-only">Color theme</span><select id="theme-select"><option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option></select></label></header>
<div class="docs-layout"><aside class="sidebar"><details class="chapter-menu" open><summary>Chapters</summary><div class="sidebar-inner"><button id="search-open" class="search-trigger js-only">Search documentation <kbd>/</kbd></button><p class="eyebrow">THE LANGUAGE</p><nav aria-label="Chapters">${nav}</nav><div class="sidebar-footer"><a href="https://github.com/nathsou/yodl">GitHub ↗</a><span>Yodl ${e(version)} · ${e(revision)}</span></div></div></details></aside>
<main id="content" tabindex="-1"><div class="chapter-meta"><span class="eyebrow">LANGUAGE GUIDE</span><span>${String(index + 1).padStart(2, '0')} / ${String(chapters.length).padStart(2, '0')}</span></div><article>${chapter.html}</article>
${lessons.length ? `<section class="related-lessons"><p class="eyebrow">PUT IT INTO PRACTICE</p><h2>Explore in the guided tour</h2>${lessons.map(l => `<a href="../playground.html?lesson=${l.id}">${e(l.title)} <span>→</span></a>`).join('')}</section>` : ''}
<nav class="page-navigation" aria-label="Previous and next chapters">${previous ? `<a href="./${previous.slug}.html"><small>← Previous</small>${e(previous.title)}</a>` : '<span></span>'}${next ? `<a href="./${next.slug}.html"><small>Next →</small>${e(next.title)}</a>` : '<span></span>'}</nav><footer class="article-footer"><a href="https://github.com/nathsou/yodl/edit/main/book/src/${chapter.slug}.md">Edit this page ↗</a><span>Examples compile locally in your browser.</span></footer></main>
<aside class="page-toc"><p class="eyebrow">ON THIS PAGE</p><nav aria-label="On this page">${toc}</nav><a class="back-top" href="#content">Back to top ↑</a></aside></div>
<dialog id="search-dialog"><div class="search-header"><label for="search-input" class="sr-only">Search documentation</label><input id="search-input" type="search" placeholder="Search concepts, syntax, and examples…" autocomplete="off"><button id="search-close" aria-label="Close search">Esc</button></div><p id="search-status" role="status">Type to search all chapters.</p><div id="search-results"></div></dialog>
<dialog id="confirm-dialog"><h2 id="confirm-title">Reset this example?</h2><p id="confirm-message">Your local edits will be replaced by the original source.</p><form method="dialog"><button value="cancel">Keep edits</button><button value="reset" class="primary">Reset source</button></form></dialog>
<dialog id="share-dialog"><h2>Share this example</h2><p>The link includes your edits and selected compiler stage. It uses the deployed compiler version.</p><input id="share-url" aria-label="Share URL" readonly><form method="dialog"><button>Close</button><button type="button" id="share-copy" class="primary">Copy link</button></form></dialog>
<script id="chapter-data" type="application/json">${JSON.stringify({ slug: chapter.slug, version, revision, examples: chapter.examples }).replaceAll('<', '\\u003c')}</script><script type="module" src="../bundle/docs.js"></script></body></html>`;
}
for (let i = 0; i < chapters.length; i++) await writeFile(`${destination}/book/${chapters[i].slug}.html`, page(chapters[i], i));
await writeFile(`${destination}/book/index.html`, page(chapters[0], 0));
await writeFile(`${destination}/index.html`, '<!doctype html><html lang="en"><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=./book/"><title>Yodl</title><a href="./book/">Yodl documentation</a></html>');
const search = chapters.flatMap(chapter => {
    const searchable = chapter.html.replace(/<div class="example-header">[\s\S]*?<\/div><\/div>/g, '');
    const sections = searchable.split(/(?=<h[1-6] id=")/);
    return sections.filter(section => /<h[1-6]/.test(section)).map(section => {
        const heading = /<h[1-6] id="([^"]+)">([\s\S]*?)<\/h[1-6]>/.exec(section)!;
        return { title: plainText(heading[2]), chapter: chapter.title, url: `${chapter.slug}.html#${heading[1]}`, text: plainText(section).replace(/\s+/g, ' ') };
    });
});
await writeFile(`${destination}/book/search.json`, JSON.stringify(search));
await writeFile(`${destination}/book/examples.json`, JSON.stringify(chapters.flatMap(c => c.examples.map(ex => ({ chapter: c.slug, ...ex })))));
const result = await Bun.build({ entrypoints: [`${root}/src/main/playground.ts`, `${root}/src/main/playground-worker.ts`, `${root}/src/docs/docs.ts`], outdir: `${destination}/bundle`, naming: '[name].[ext]', splitting: true, minify: true, target: 'browser' });
if (!result.success) throw new AggregateError(result.logs, 'Browser build failed');
for (const name of ['playground.html', 'playground.css', 'theme.css']) await cp(`${root}/src/main/${name}`, `${destination}/${name}`);
await cp(`${root}/src/docs/docs.css`, `${destination}/docs.css`);
console.log(`Built ${chapters.length} chapters and ${chapters.reduce((n, c) => n + c.examples.length, 0)} examples in dist/`);
