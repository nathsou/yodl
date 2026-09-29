// Keep the existing key so playground users retain their preference.
const themeKey = 'yodl-playground-v2:theme';
const accentKey = 'yodl-playground-v2:accent';
export const accents = [
    { id: 'teal', label: 'Teal' }, { id: 'cobalt', label: 'Cobalt' }, { id: 'moss', label: 'Moss' }, { id: 'plum', label: 'Plum' },
    { id: 'ochre', label: 'Ochre' }, { id: 'signal', label: 'Signal' }, { id: 'ember', label: 'Ember' },
] as const;
export type ThemePreference = 'system' | 'light' | 'dark';
export const defaultAccent = 'teal';

/** Reads a design token (a hex colour) so Monaco can follow the page theme. */
export function themeToken(name: string): string {
    return getComputedStyle(document.documentElement).getPropertyValue(`--${name}`).trim();
}

function read(key: string) {
    try { return localStorage.getItem(key); } catch { return null; }
}
function write(key: string, value: string) {
    try { localStorage.setItem(key, value); } catch { /* Still apply the choice for this visit. */ }
}

/** Wires the System / Light / Dark segmented control in the shared header. */
export function setupTheme(container: HTMLElement, onChange: (dark: boolean) => void) {
    const system = matchMedia('(prefers-color-scheme: dark)');
    const buttons = Array.from(container.querySelectorAll<HTMLButtonElement>('[data-theme-preference]'));
    const stored = read(themeKey);
    let preference: ThemePreference = stored === 'light' || stored === 'dark' ? stored : 'system';
    const update = () => {
        const dark = preference === 'dark' || (preference === 'system' && system.matches);
        document.documentElement.dataset.theme = dark ? 'dark' : 'light';
        for (const button of buttons) button.setAttribute('aria-pressed', String(button.dataset.themePreference === preference));
        onChange(dark);
    };
    for (const button of buttons) button.addEventListener('click', () => {
        preference = button.dataset.themePreference as ThemePreference;
        write(themeKey, preference);
        update();
    });
    system.addEventListener('change', update);
    update();
    return update;
}

/** Wires the accent popover. Accent is applied as `data-accent` on <html>. */
export function setupAccent(container: HTMLElement, onChange: () => void) {
    const trigger = container.querySelector<HTMLButtonElement>('#accent-button')!;
    const menu = container.querySelector<HTMLElement>('#accent-menu')!;
    const label = container.querySelector<HTMLElement>('#accent-label')!;
    const swatches = Array.from(container.querySelectorAll<HTMLButtonElement>('.swatch'));
    const stored = read(accentKey);
    let accent: string = accents.some(a => a.id === stored) ? stored! : defaultAccent;
    const apply = () => {
        document.documentElement.dataset.accent = accent;
        label.textContent = accents.find(a => a.id === accent)!.label;
        for (const swatch of swatches) swatch.setAttribute('aria-pressed', String(swatch.dataset.accent === accent));
    };
    const setOpen = (open: boolean) => {
        menu.hidden = !open;
        trigger.setAttribute('aria-expanded', String(open));
    };
    trigger.addEventListener('click', () => setOpen(menu.hidden === true));
    for (const swatch of swatches) swatch.addEventListener('click', () => {
        accent = swatch.dataset.accent!;
        write(accentKey, accent);
        apply();
        onChange();
    });
    document.addEventListener('pointerdown', event => { if (!menu.hidden && !container.contains(event.target as Node)) setOpen(false); });
    container.addEventListener('keydown', event => { if (event.key === 'Escape' && !menu.hidden) { setOpen(false); trigger.focus(); } });
    apply();
    return apply;
}
