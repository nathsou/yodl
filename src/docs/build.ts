import { buildBrowserAssets } from './bundle.ts';
import { siteHeader } from '../main/site-navigation.ts';
import { mkdir, cp, readFile, writeFile, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { loadChapters, escapeHTML as e, plainText } from './content.ts';
import type { Chapter } from './content.ts';

const root = resolve(import.meta.dir, '../..');
const destination = resolve(root, process.argv[2] ?? 'dist');
if (destination !== resolve(root, 'dist')) throw new Error('The site build writes only to dist/');
const chapters = loadChapters(root);
const version = JSON.parse(await readFile(resolve(root, 'moon.mod.json'), 'utf8')).version;
const revision = process.env.YODL_REVISION?.slice(0, 7) || Bun.spawnSync(['git', 'rev-parse', '--short', 'HEAD'], { cwd: root }).stdout.toString().trim() || 'local';
await rm(destination, { recursive: true, force: true });
await mkdir(`${destination}/book`, { recursive: true });
await mkdir(`${destination}/bundle`, { recursive: true });
const assets = await buildBrowserAssets(root, `${destination}/bundle`);

// The guide is a mode of the playground page. Published chapter URLs
// (book/<slug>.html#anchor) stay valid: they forward to the page, keeping the
// fragment. Readers without JavaScript still get the chapter text.
function legacyPage(chapter: Chapter) {
    const target = `../playground.html?mode=docs&chapter=${chapter.slug}`;
    const description = `${chapter.title} in Yodl. Learn the language with editable examples and inspect the hardware compiler output.`;
    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${e(chapter.title)} · Yodl</title><meta name="description" content="${e(description)}"><link rel="canonical" href="${target}"><script>location.replace(${JSON.stringify(target)}+location.hash)</script><style>body{font:16px/1.7 system-ui,sans-serif;max-width:760px;margin:0 auto;padding:24px}pre{overflow:auto}</style></head>
<body><p><a href="${target}">Open ${e(chapter.title)} in the Yodl guide</a></p><noscript><article>${chapter.html}</article></noscript></body></html>`;
}
for (const chapter of chapters) await writeFile(`${destination}/book/${chapter.slug}.html`, legacyPage(chapter));
await writeFile(`${destination}/book/index.html`, legacyPage(chapters[0]));
await writeFile(`${destination}/index.html`, '<!doctype html><html lang="en"><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=./playground.html"><title>Yodl</title><a href="./playground.html">Yodl</a></html>');
await writeFile(`${destination}/book/chapters.json`, JSON.stringify({ version, revision, chapters: chapters.map(({ slug, title, html, headings, examples }) => ({ slug, title, html, headings, examples })) }));

const search = chapters.flatMap(chapter => {
    // Index prose and code, not the example chrome or its line-number gutter.
    const searchable = chapter.html.replace(/<div class="example-header">[\s\S]*?<\/span><\/div>/g, '').replace(/<span class="ln">\d+<\/span>/g, '');
    const sections = searchable.split(/(?=<h[1-6] id=")/);
    return sections.filter(section => /<h[1-6]/.test(section)).map(section => {
        const heading = /<h[1-6] id="([^"]+)">([\s\S]*?)<\/h[1-6]>/.exec(section)!;
        return { title: plainText(heading[2]), chapter: chapter.title, slug: chapter.slug, id: heading[1], text: plainText(section).replace(/\s+/g, ' ') };
    });
});
await writeFile(`${destination}/book/search.json`, JSON.stringify(search));
await writeFile(`${destination}/book/examples.json`, JSON.stringify(chapters.flatMap(c => c.examples.map(ex => ({ chapter: c.slug, ...ex })))));
for (const name of ['playground.css', 'theme.css', 'site-navigation.css']) await cp(`${root}/src/main/${name}`, `${destination}/${name}`);
const playground = await readFile(`${root}/src/main/playground.html`, 'utf8');
await writeFile(`${destination}/playground.html`, playground.replace('<!-- site-header -->', siteHeader()).replace('./bundle/playground.js', `./bundle/${assets.playground}`));
console.log(`Built ${chapters.length} chapters and ${chapters.reduce((n, c) => n + c.examples.length, 0)} examples in dist/`);
