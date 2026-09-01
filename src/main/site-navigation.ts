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
