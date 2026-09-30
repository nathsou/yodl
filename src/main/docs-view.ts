import { CompilerClient } from './compiler-client.ts';
import { stages } from './compiler-stages.ts';
import type { Stage } from './compiler-stages.ts';
import { highlightLines } from './highlight.ts';
import { chapterLessons } from '../docs/links.ts';
import type { Example } from '../docs/content.ts';

export type ChapterData = { slug: string; title: string; html: string; headings: { id: string; title: string; level: number }[]; examples: Example[] };
export type DocsData = { version: string; revision: string; chapters: ChapterData[] };
export type DocsHost = {
    /** The reader followed a link to a chapter (and optionally a heading). */
    navigate(slug: string, anchor?: string): void;
    openLesson(id: string): void;
    /** Hand an example over to the Playground for editing. */
    openExample(chapter: ChapterData, example: Example, source: string, stage: Stage): void;
};

const element = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const pad = (value: number) => String(value).padStart(2, '0');
export const docsUrl = (slug: string, anchor?: string) => `./playground.html?mode=docs&chapter=${slug}${anchor ? `#${anchor}` : ''}`;

function el<K extends keyof HTMLElementTagNameMap>(tag: K, className?: string, text?: string) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

export function createDocs(host: DocsHost) {
    const compiler = new CompilerClient();
    let loading: Promise<DocsData> | undefined;
    let current: ChapterData | undefined;
    let observer: IntersectionObserver | undefined;
    const main = element('docs-main');
    const content = element('docs-content');
    const tooltip = el('div', 'code-tooltip');
    tooltip.id = 'docs-code-tooltip';
    tooltip.setAttribute('role', 'tooltip');
    tooltip.hidden = true;
    document.body.append(tooltip);
    let tooltipTarget: HTMLElement | undefined;
    let tooltipTimer: ReturnType<typeof setTimeout> | undefined;
    const hideTooltip = () => {
        clearTimeout(tooltipTimer);
        tooltip.hidden = true;
        tooltipTarget?.removeAttribute('aria-describedby');
        tooltipTarget = undefined;
    };
    const deferHideTooltip = () => {
        if (tooltipTarget === document.activeElement) return;
        clearTimeout(tooltipTimer);
        tooltipTimer = setTimeout(hideTooltip, 100);
    };
    const showTooltip = (target: HTMLElement) => {
        hideTooltip();
        tooltipTarget = target;
        tooltip.textContent = target.dataset.codeInfo!;
        tooltip.hidden = false;
        target.setAttribute('aria-describedby', tooltip.id);
        const rect = target.getBoundingClientRect();
        const width = tooltip.offsetWidth, height = tooltip.offsetHeight;
        tooltip.style.left = `${Math.max(8, Math.min(rect.left, innerWidth - width - 8))}px`;
        tooltip.style.top = `${Math.max(8, rect.top > height + 12 ? rect.top - height - 8 : Math.min(rect.bottom + 8, innerHeight - height - 8))}px`;
    };
    const infoTarget = (event: Event) => (event.target as Element).closest<HTMLElement>('[data-code-info]');
    content.addEventListener('pointerover', event => { const target = infoTarget(event); if (target && target !== tooltipTarget) showTooltip(target); });
    content.addEventListener('pointerout', event => { if (tooltipTarget && !tooltipTarget.contains(event.relatedTarget as Node)) deferHideTooltip(); });
    tooltip.addEventListener('pointerenter', () => clearTimeout(tooltipTimer));
    tooltip.addEventListener('pointerleave', deferHideTooltip);
    content.addEventListener('focusin', event => { const target = infoTarget(event); if (target) showTooltip(target); });
    content.addEventListener('focusout', hideTooltip);
    const tooltipKeydown = (event: KeyboardEvent) => { if (event.key === 'Escape') hideTooltip(); };
    document.addEventListener('keydown', tooltipKeydown);
    main.addEventListener('scroll', hideTooltip, { passive: true });

    function load(): Promise<DocsData> {
        return loading ??= fetch('./book/chapters.json').then(response => {
            if (!response.ok) throw new Error('The language guide could not be loaded.');
            return response.json() as Promise<DocsData>;
        }).catch(error => { loading = undefined; throw error; });
    }

    function link(slug: string, anchor: string | undefined, text: string | (string | Node)[]) {
        const anchorElement = el('a');
        anchorElement.href = docsUrl(slug, anchor);
        anchorElement.append(...(typeof text === 'string' ? [text] : text));
        anchorElement.addEventListener('click', event => {
            if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
            event.preventDefault();
            host.navigate(slug, anchor);
        });
        return anchorElement;
    }

    function renderNavigation(data: DocsData, chapter: ChapterData) {
        element('docs-chapters').replaceChildren(...data.chapters.map((item, index) => {
            const anchorElement = link(item.slug, undefined, [el('span', undefined, pad(index + 1)), item.title]);
            if (item === chapter) anchorElement.setAttribute('aria-current', 'page');
            return anchorElement;
        }));
        element('docs-version').textContent = `Yodl ${data.version} · ${data.revision}`;
        element('docs-toc').replaceChildren(...chapter.headings.filter(heading => heading.level > 1 && heading.level < 4).map(heading => {
            const anchorElement = link(chapter.slug, heading.id, heading.title);
            anchorElement.className = `toc-level-${heading.level}`;
            return anchorElement;
        }));
        observeHeadings();
    }

    function observeHeadings() {
        observer?.disconnect();
        const tocLinks = Array.from(element('docs-toc').querySelectorAll('a'));
        if (!tocLinks.length || typeof IntersectionObserver === 'undefined') return;
        observer = new IntersectionObserver(entries => {
            for (const entry of entries) if (entry.isIntersecting) for (const item of tocLinks) {
                if (item.href.endsWith(`#${entry.target.id}`)) item.setAttribute('aria-current', 'location'); else item.removeAttribute('aria-current');
            }
        }, { root: main, rootMargin: '0px 0px -70% 0px' });
        for (const heading of Array.from(content.querySelectorAll('h2[id], h3[id]'))) observer.observe(heading);
    }

    function renderArticle(data: DocsData, chapter: ChapterData) {
        hideTooltip();
        const index = data.chapters.indexOf(chapter);
        const meta = el('p', 'docs-meta', `Chapter ${pad(index + 1)} of ${pad(data.chapters.length)}`);
        const article = el('article');
        article.innerHTML = chapter.html;
        const parts: Node[] = [meta, article];
        const lessons = chapterLessons[chapter.slug] ?? [];
        if (lessons.length) {
            const practice = el('section', 'practice');
            practice.append(el('p', 'section-label', 'Practice in the tour'));
            for (const lesson of lessons) {
                const row = el('button');
                row.type = 'button';
                row.append(el('strong', undefined, lesson.title), el('span', undefined, '→'));
                row.addEventListener('click', () => host.openLesson(lesson.id));
                practice.append(row);
            }
            parts.push(practice);
        }
        const previous = data.chapters[index - 1], next = data.chapters[index + 1];
        const pager = el('nav', 'page-navigation');
        pager.setAttribute('aria-label', 'Previous and next chapters');
        const pagerLink = (target: ChapterData | undefined, label: string) => target ? link(target.slug, undefined, [el('small', undefined, label), target.title]) : el('span');
        pager.append(pagerLink(previous, '← Previous'), pagerLink(next, 'Next →'));
        const footer = el('footer', 'article-footer');
        const edit = el('a', undefined, 'Edit this page ↗');
        edit.href = `https://github.com/nathsou/yodl/edit/main/book/src/${chapter.slug}.md`;
        footer.append(edit, el('span', undefined, 'Examples compile locally in your browser.'));
        parts.push(pager, footer);
        content.replaceChildren(...parts);
        content.className = 'docs-content';
        wireLinks(data, chapter);
        for (const example of chapter.examples) wireExample(chapter, example);
    }

    // Headings and cross-chapter links are followed inside the page.
    function wireLinks(data: DocsData, chapter: ChapterData) {
        for (const anchorElement of Array.from(content.querySelectorAll<HTMLAnchorElement>('article a[href]'))) {
            const href = anchorElement.getAttribute('href')!;
            const local = /^#(.+)$/.exec(href);
            const chapterLink = /^\.?\/?([\w-]+)\.html(?:#(.+))?$/.exec(href);
            const target = chapterLink && data.chapters.find(item => item.slug === chapterLink[1]);
            if (!local && !target) continue;
            const slug = local ? chapter.slug : target!.slug;
            const anchor = local ? local[1] : chapterLink![2];
            anchorElement.href = docsUrl(slug, anchor);
            anchorElement.addEventListener('click', event => {
                if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
                event.preventDefault();
                host.navigate(slug, anchor);
            });
        }
    }

    function wireExample(chapter: ChapterData, example: Example) {
        const card = content.querySelector<HTMLElement>(`#${CSS.escape(example.id)}`);
        if (!card || !example.live) return;
        const compile = card.querySelector<HTMLButtonElement>('[data-action="compile"]')!;
        card.querySelector<HTMLButtonElement>('[data-action="playground"]')!.onclick = () => host.openExample(chapter, example, example.source, drawerStage(card) ?? example.stage);
        const run = async (stage: Stage) => {
            const drawer = openDrawer(card, example, stage, run);
            const status = drawer.querySelector<HTMLElement>('.example-status')!;
            status.dataset.state = '';
            status.firstChild!.textContent = '● Compiling · ';
            compile.disabled = true;
            const result = await compiler.compile(example.id, { source: example.source, path: example.path, files: example.files, stage });
            compile.disabled = false;
            if (!result || !card.isConnected) return;
            const body = drawer.querySelector<HTMLElement>('.example-output-body')!;
            if (result.error !== undefined) {
                const expected = example.expect === 'error';
                status.dataset.state = expected ? 'expected' : 'error';
                status.firstChild!.textContent = expected ? '● Expected compiler error · ' : '● Compilation failed · ';
                const diagnostic = el('pre', 'diagnostic', result.error);
                diagnostic.tabIndex = 0;
                body.replaceChildren(diagnostic);
            } else {
                status.dataset.state = 'success';
                status.firstChild!.textContent = '● Compiled · ';
                status.title = `${Math.round(result.duration)} ms · Yodl ${currentVersion}`;
                const lines = el('div', 'code-lines');
                lines.tabIndex = 0;
                lines.innerHTML = highlightLines(result.output ?? '', stages[stage].language);
                body.replaceChildren(lines);
            }
        };
        compile.onclick = () => void run(drawerStage(card) ?? example.stage);
    }
    let currentVersion = '';
    const drawerStage = (card: HTMLElement) => card.querySelector<HTMLSelectElement>('.example-output select')?.value as Stage | undefined;

    function openDrawer(card: HTMLElement, example: Example, stage: Stage, run: (stage: Stage) => Promise<void>) {
        let drawer = card.querySelector<HTMLElement>('.example-output');
        if (drawer) { drawer.hidden = false; return drawer; }
        drawer = el('div', 'example-output');
        const header = el('div', 'example-output-header');
        const status = el('span', 'example-status');
        status.append(document.createTextNode('● Compiled · '));
        const picker = el('select');
        picker.setAttribute('aria-label', 'Compiler output stage');
        for (const [value, definition] of Object.entries(stages)) {
            if (value === 'test' && example.stage !== 'test') continue;
            const option = new Option(definition.label, value);
            option.disabled = example.unsupported.includes(value as Stage);
            if (option.disabled) option.text += ' (unavailable)';
            picker.add(option);
        }
        picker.value = stage;
        picker.title = stages[stage].description;
        picker.onchange = () => { picker.title = stages[picker.value as Stage].description; void run(picker.value as Stage); };
        const pickerBox = el('span', 'stage-select');
        pickerBox.append(picker);
        status.append(pickerBox);
        const hide = el('button', undefined, 'Hide');
        hide.type = 'button';
        hide.onclick = () => { drawer!.hidden = true; };
        header.append(status, hide);
        drawer.append(header, el('div', 'example-output-body'));
        card.append(drawer);
        return drawer;
    }

    function scrollToAnchor(anchor?: string) {
        const target = anchor ? content.querySelector<HTMLElement>(`#${CSS.escape(anchor)}`) : null;
        if (target) {
            target.scrollIntoView();
            if (target.hasAttribute('data-code-info')) target.focus({ preventScroll: true });
        } else main.scrollTop = 0;
    }

    return {
        load,
        /** Renders a chapter (the first when the slug is unknown) and scrolls to an anchor. */
        async show(slug?: string, anchor?: string) {
            const loadingNotice = element('docs-loading');
            let data: DocsData;
            try {
                loadingNotice.hidden = false;
                loadingNotice.textContent = 'Loading the language guide…';
                data = await load();
            } catch (error) {
                loadingNotice.textContent = `${(error as Error).message} Check your connection and reload the page.`;
                return undefined;
            }
            loadingNotice.hidden = true;
            currentVersion = data.version;
            const chapter = data.chapters.find(item => item.slug === slug) ?? data.chapters[0];
            const changed = chapter !== current;
            if (changed) {
                if (current) for (const example of current.examples) compiler.cancel(example.id);
                current = chapter;
                renderNavigation(data, chapter);
                renderArticle(data, chapter);
                document.title = `${chapter.title} · Yodl`;
                element('docs-current').textContent = `${pad(data.chapters.indexOf(chapter) + 1)} · ${chapter.title}`;
                if (matchMedia('(max-width: 820px)').matches) element<HTMLDetailsElement>('chapter-menu').open = false;
            }
            if (changed || anchor) scrollToAnchor(anchor);
            return chapter;
        },
        get current() { return current; },
        dispose() { hideTooltip(); document.removeEventListener('keydown', tooltipKeydown); tooltip.remove(); compiler.dispose(); },
    };
}
export type Docs = ReturnType<typeof createDocs>;
