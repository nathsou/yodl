// One search over the language guide and the tour lessons (⌘K, or / outside editors).
export type LessonEntry = { id: string; title: string; topic: string; intro: string; concepts: string[]; observe: string; challenge: string };
type DocEntry = { title: string; chapter: string; slug: string; id: string; text: string };
export type SearchHost = {
    lessons: LessonEntry[];
    openLesson(id: string): void;
    openDoc(slug: string, anchor: string): void;
};
type Result = { title: string; where: string; excerpt: string; text: string; go: () => void };

const element = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;

export function createSearch(host: SearchHost) {
    const dialog = element<HTMLDialogElement>('search-dialog');
    const input = element<HTMLInputElement>('search-input');
    const results = element('search-results');
    const status = element('search-status');
    let docs: DocEntry[] | undefined;
    let loading: Promise<void> | undefined;
    const lessons: Result[] = host.lessons.map((lesson, index) => ({
        title: lesson.title, where: `Tour · Lesson ${String(index + 1).padStart(2, '0')}`, excerpt: lesson.intro,
        text: [lesson.title, lesson.topic, lesson.intro, ...lesson.concepts, lesson.observe, lesson.challenge].join(' '),
        go: () => host.openLesson(lesson.id),
    }));

    async function ensureDocs() {
        if (docs) return true;
        try {
            await (loading ??= fetch('./book/search.json').then(response => {
                if (!response.ok) throw new Error('Search unavailable');
                return response.json();
            }).then(value => { docs = value; }).finally(() => { loading = undefined; }));
            return true;
        } catch { return false; }
    }

    async function search() {
        const query = input.value.toLowerCase().trim();
        status.textContent = query ? 'Searching…' : 'Type to search the guide and the tour.';
        const loaded = await ensureDocs();
        if (input.value.toLowerCase().trim() !== query) return;
        results.replaceChildren();
        if (!query) return;
        const words = query.split(/\s+/);
        const guide: Result[] = (docs ?? []).map(entry => ({
            title: entry.title, where: `Docs · ${entry.chapter}`, excerpt: entry.text, text: `${entry.title} ${entry.text}`,
            go: () => host.openDoc(entry.slug, entry.id),
        }));
        const matches = [...lessons, ...guide].filter(result => words.every(word => result.text.toLowerCase().includes(word)))
            .sort((a, b) => Number(b.title.toLowerCase().includes(query)) - Number(a.title.toLowerCase().includes(query))).slice(0, 30);
        const note = loaded ? '' : ' The guide index could not load; showing lessons only.';
        status.textContent = (matches.length ? `${matches.length} result${matches.length === 1 ? '' : 's'}` : 'No results. Try a concept, operator, or built-in name.') + note;
        for (const result of matches) {
            const link = document.createElement('a');
            link.href = '#';
            link.addEventListener('click', event => { event.preventDefault(); dialog.close(); result.go(); });
            const heading = document.createElement('strong'); heading.textContent = result.title;
            const where = document.createElement('small'); where.textContent = result.where;
            const excerpt = document.createElement('span');
            const start = Math.max(0, result.excerpt.toLowerCase().indexOf(words[0]) - 50);
            excerpt.textContent = `${start ? '…' : ''}${result.excerpt.slice(start, start + 160)}${result.excerpt.length > start + 160 ? '…' : ''}`;
            link.append(heading, where, excerpt);
            results.append(link);
        }
    }

    const open = () => { if (!dialog.open) dialog.showModal(); input.focus(); input.select(); void search(); };
    element('search-open').addEventListener('click', open);
    element('search-close').addEventListener('click', () => dialog.close());
    input.addEventListener('input', () => void search());
    dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
    dialog.addEventListener('keydown', event => {
        const links = Array.from(results.querySelectorAll('a'));
        const index = links.indexOf(document.activeElement as HTMLAnchorElement);
        if (event.key === 'ArrowDown') { event.preventDefault(); links[Math.min(links.length - 1, index + 1)]?.focus(); }
        if (event.key === 'ArrowUp') { event.preventDefault(); if (index <= 0) input.focus(); else links[index - 1].focus(); }
        if (event.key === 'Enter' && document.activeElement === input) links[0]?.click();
    });
    const mac = /Mac|iPhone|iPad/.test(navigator.platform);
    element('search-shortcut').textContent = mac ? '⌘K' : 'Ctrl K';
    document.addEventListener('keydown', event => {
        const target = event.target as HTMLElement;
        if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); open(); return; }
        if (event.key === '/' && !event.metaKey && !event.ctrlKey && !target.closest('input, textarea, select, [contenteditable="true"], .monaco-editor') && !document.querySelector('dialog[open]')) { event.preventDefault(); open(); }
    });
    return { open };
}
