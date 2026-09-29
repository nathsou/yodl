import { accents } from './theme.ts';

// One header shared by Tour, Playground and Docs; they are modes of a single page.
export const modes = [
    { id: 'tour', label: 'Tour' },
    { id: 'playground', label: 'Playground' },
    { id: 'docs', label: 'Docs' },
] as const;
export type SiteMode = typeof modes[number]['id'];

const themeSwitch = (id: string) => `<div${id ? ` id="${id}"` : ''} class="theme-switch" role="group" aria-label="Colour theme" title="Colour theme"><button type="button" data-theme-preference="system" aria-pressed="false">System</button><button type="button" data-theme-preference="light" aria-pressed="false">Light</button><button type="button" data-theme-preference="dark" aria-pressed="false">Dark</button></div>`;

export function siteHeader() {
    return `<header class="site-header">
<a class="site-brand" href="./playground.html?lesson=gates" aria-label="Yodl home"><span class="site-wordmark">yodl</span><span class="site-tagline">hardware description language</span></a>
<nav class="mode-switch" aria-label="Yodl">${modes.map(mode => `<button type="button" data-mode="${mode.id}" aria-pressed="false">${mode.label}</button>`).join('')}</nav>
<div class="site-tools">
<button type="button" id="search-open" class="search-trigger" aria-label="Search docs and lessons"><span class="search-label">Search<span class="search-more"> docs &amp; lessons</span></span><kbd id="search-shortcut">⌘K</kbd></button>
<div class="accent-picker">
<button type="button" id="accent-button" class="tool-button" aria-haspopup="true" aria-expanded="false" title="Appearance"><span class="accent-dot"></span><span class="tool-label">Accent</span></button>
<div id="accent-menu" class="popover" hidden><div class="popover-heading"><span>Accent</span><strong id="accent-label">Teal</strong></div><div class="swatches">${accents.map(accent => `<button type="button" class="swatch" data-accent="${accent.id}" title="${accent.label}" aria-label="${accent.label}" aria-pressed="false"><span></span></button>`).join('')}</div><div class="popover-theme"><div class="popover-heading"><span>Theme</span></div>${themeSwitch('')}</div></div>
</div>
${themeSwitch('theme-switch')}
<a class="site-github" href="https://github.com/nathsou/yodl">GitHub</a>
</div>
</header>`;
}
