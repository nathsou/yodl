// Both reading and editing use the same navigation within one static site.
export function siteNavigation(page: 'docs' | 'playground') {
    const base = page === 'docs' ? '../' : './';
    return `<nav class="site-navigation" aria-label="Yodl">
<a href="${base}book/"${page === 'docs' ? ' aria-current="page"' : ''}>Docs</a>
${page === 'docs'
    ? `<a href="${base}playground.html?lesson=gates">Tour</a><a href="${base}playground.html?mode=examples">Playground</a>`
    : '<button id="tour-mode" aria-pressed="true">Tour</button><button id="examples-mode" aria-pressed="false">Playground</button>'}
</nav>`;
}

export function siteHeader(page: 'docs' | 'playground') {
    const base = page === 'docs' ? '../' : './';
    return `<header class="site-header">
<a class="site-brand" href="${base}book/" aria-label="Yodl home">yodl<span class="site-brand-divider">/</span><span class="site-section" id="site-section">${page === 'docs' ? 'documentation' : 'playground'}</span></a>
${siteNavigation(page)}
<label class="site-theme"><span class="sr-only">Color theme</span><select id="theme-select" title="Color theme"><option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option></select></label>
</header>`;
}
