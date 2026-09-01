// Keep the existing key so playground users retain their preference.
const key = 'yodl-playground-v2:theme';
export function setupTheme(select: HTMLSelectElement, onChange: (dark: boolean) => void) {
    const system = matchMedia('(prefers-color-scheme: dark)');
    try { select.value = localStorage.getItem(key) ?? 'system'; } catch { /* Device storage is optional. */ }
    if (!['light', 'dark', 'system'].includes(select.value)) select.value = 'system';
    const update = () => {
        const dark = select.value === 'dark' || (select.value === 'system' && system.matches);
        document.documentElement.dataset.theme = dark ? 'dark' : 'light';
        onChange(dark);
    };
    select.addEventListener('change', () => {
        try { localStorage.setItem(key, select.value); } catch { /* Still apply the theme. */ }
        update();
    });
    system.addEventListener('change', update);
    update();
    return update;
}
