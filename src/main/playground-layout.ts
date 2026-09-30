import { defaultLayout, paneIds, readLayout, movePane, resizePair, type PaneId, type PaneLayout } from './pane-layout.ts';

const labels = { source: 'Source', output: 'Output', simulation: 'Simulation', sidebar: 'Sidebar' };
const node = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const makeButton = (label: string, text: string, action: () => void) => {
    const button = document.createElement('button');
    button.type = 'button'; button.title = label; button.setAttribute('aria-label', label); button.textContent = text;
    button.onclick = action;
    return button;
};

export function createPaneLayout(host: { read(key: string): string | null; save(key: string, value: string): void; sidebarHidden(): boolean; showSidebar(show: boolean): void; changed(): void }) {
    let state = readLayout(host.read('panes'));
    let active: PaneId = 'source';
    let focused: PaneId | 'sidebar' | undefined;
    let drag: PaneId | undefined;
    let restoreInert: [HTMLElement, boolean][] = [];
    let restoreFocus: HTMLElement | null = null;
    const phone = matchMedia('(max-width: 639px)');
    const stacked = matchMedia('(max-width: 1199px)');
    const narrow = matchMedia('(max-width: 819px)');
    const root = node('editors');
    const frame = node('editor-view');
    const panes = { source: node('source-pane'), output: node('output-pane'), simulation: node('simulation-pane'), sidebar: node('sidebar') };
    panes.source.append(node('compile-status').closest('footer')!);
    const empty = document.createElement('p');
    empty.className = 'panes-empty'; empty.textContent = 'All panes are hidden. Use Layout to show a pane or reset the arrangement.';
    const menu = node<HTMLDetailsElement>('layout-menu');
    const axis = node<HTMLSelectElement>('layout-axis');
    const side = node<HTMLSelectElement>('sidebar-position');
    const toggles = new Map<string, HTMLInputElement>();
    const controls = new Map<string, HTMLElement>();
    const separators: HTMLElement[] = [];
    const vertical = () => state.axis === 'vertical' || (state.axis === 'auto' && stacked.matches);
    const save = () => host.save('panes', JSON.stringify(state));
    const visible = () => state.order.filter(id => state.visible.includes(id));
    const change = (next: PaneLayout) => { state = next; save(); render(); };

    function exitFullscreen() {
        if (!focused) return;
        panes[focused].classList.remove('pane-fullscreen');
        for (const [element, wasInert] of restoreInert) element.inert = wasInert;
        restoreInert = [];
        focused = undefined;
        render();
        if (restoreFocus?.isConnected && restoreFocus.getClientRects().length) restoreFocus.focus();
    }
    function fullscreen(id: PaneId | 'sidebar') {
        if (focused === id) { exitFullscreen(); return; }
        exitFullscreen();
        menu.open = false;
        if (id === 'sidebar') host.showSidebar(true); else activate(id);
        restoreFocus = document.activeElement as HTMLElement;
        focused = id;
        panes[id].classList.add('pane-fullscreen');
        restoreInert.push([panes[id], panes[id].inert]);
        panes[id].inert = false;
        let child: HTMLElement = panes[id];
        while (child.parentElement) {
            for (const sibling of child.parentElement.children) if (sibling !== child && sibling instanceof HTMLElement) {
                restoreInert.push([sibling, sibling.inert]); sibling.inert = true;
            }
            child = child.parentElement;
            if (child === document.body) break;
        }
        updateControls();
        controls.get(id)!.querySelector<HTMLButtonElement>('[data-action="fullscreen"]')!.focus();
        host.changed();
    }
    function toggle(id: PaneId, show: boolean) {
        if (focused === id && !show) exitFullscreen();
        change({ ...state, visible: show ? [...new Set([...state.visible, id])] : state.visible.filter(p => p !== id) });
    }
    function activate(id: PaneId) {
        if (focused && focused !== id) exitFullscreen();
        active = id;
        if (!state.visible.includes(id)) toggle(id, true); else render();
    }
    function reveal(id: PaneId) {
        if (phone.matches && !focused) activate(id);
        else if (!state.visible.includes(id)) toggle(id, true);
    }
    function updateControls() {
        for (const id of [...paneIds, 'sidebar'] as const) {
            const group = controls.get(id)!;
            const full = group.querySelector<HTMLButtonElement>('[data-action="fullscreen"]')!;
            full.textContent = focused === id ? '↙' : '⛶';
            full.title = `${focused === id ? 'Restore' : 'Full screen'} ${labels[id]}`;
            full.setAttribute('aria-label', full.title);
            full.setAttribute('aria-pressed', String(focused === id));
            const moved = group.querySelector<HTMLButtonElement>('[data-action="move"]')!;
            moved.textContent = id === 'sidebar' ? (state.sidebarPosition === 'left' ? '→' : '←') : '←';
            moved.disabled = id !== 'sidebar' && visible().indexOf(id) <= 0;
            if (id !== 'sidebar') group.querySelector<HTMLButtonElement>('[data-action="later"]')!.disabled = visible().indexOf(id) === visible().length - 1;
        }
    }
    function paneControls(id: PaneId | 'sidebar', header: HTMLElement) {
        const group = document.createElement('div'); group.className = 'pane-controls'; group.setAttribute('aria-label', `${labels[id]} pane controls`);
        const move = makeButton(id === 'sidebar' ? 'Move sidebar to the other side' : `Move ${labels[id]} earlier`, '←', () => {
            if (id === 'sidebar') change({ ...state, sidebarPosition: state.sidebarPosition === 'left' ? 'right' : 'left' });
            else { const list = visible(); const index = list.indexOf(id); if (index > 0) change(movePane(state, id, list[index - 1])); }
        });
        move.dataset.action = 'move'; group.append(move);
        if (id !== 'sidebar') {
            const later = makeButton(`Move ${labels[id]} later`, '→', () => { const list = visible(); const index = list.indexOf(id); if (index < list.length - 1) change(movePane(state, id, list[index + 1])); });
            later.dataset.action = 'later'; group.append(later);
            const grip = makeButton(`Drag to move ${labels[id]}`, '⠿', () => {});
            grip.className = 'pane-grip'; grip.draggable = true;
            grip.ondragstart = event => { drag = id; event.dataTransfer!.effectAllowed = 'move'; event.dataTransfer!.setData('text/plain', id); };
            grip.ondragend = () => { drag = undefined; panes[id].classList.remove('pane-drop'); };
            group.prepend(grip);
            header.ondragover = event => { if (drag && drag !== id) { event.preventDefault(); event.dataTransfer!.dropEffect = 'move'; panes[id].classList.add('pane-drop'); } };
            header.ondragleave = () => panes[id].classList.remove('pane-drop');
            header.ondrop = event => { event.preventDefault(); panes[id].classList.remove('pane-drop'); if (drag && drag !== id) change(movePane(state, drag, id)); drag = undefined; };
        }
        const full = makeButton(`Full screen ${labels[id]}`, '⛶', () => fullscreen(id)); full.dataset.action = 'fullscreen';
        group.append(full, makeButton(`Hide ${labels[id]}`, '×', () => { if (id === 'sidebar') { exitFullscreen(); host.showSidebar(false); render(); } else toggle(id, false); }));
        header.append(group); controls.set(id, group);
    }
    for (const id of ['source', 'output'] as const) {
        const header = document.createElement('div'); header.className = 'pane-heading'; header.textContent = labels[id];
        panes[id].prepend(header); paneControls(id, header);
    }
    paneControls('simulation', panes.simulation.querySelector('.panel-header')!);
    const sidebarHeader = document.createElement('div'); sidebarHeader.className = 'pane-heading'; sidebarHeader.textContent = 'Sidebar'; panes.sidebar.prepend(sidebarHeader);
    paneControls('sidebar', sidebarHeader);

    function separator(first: PaneId, second: PaneId) {
        const handle = document.createElement('div'); handle.className = 'pane-resizer'; handle.tabIndex = 0; handle.setAttribute('role', 'separator');
        handle.inert = focused !== undefined;
        handle.setAttribute('aria-label', `Resize ${labels[first]} and ${labels[second]}`);
        handle.setAttribute('aria-orientation', vertical() ? 'horizontal' : 'vertical');
        handle.setAttribute('aria-valuemin', '10'); handle.setAttribute('aria-valuemax', '90');
        const ratio = () => state.weights[first] / (state.weights[first] + state.weights[second]);
        const resize = (fraction: number) => { state = resizePair(state, first, second, fraction); tracks(); handle.setAttribute('aria-valuenow', String(Math.round(ratio() * 100))); host.changed(); };
        resize(ratio());
        let origin = 0, initial = 0, extent = 1;
        handle.onpointerdown = event => {
            const a = panes[first].getBoundingClientRect(), b = panes[second].getBoundingClientRect();
            origin = vertical() ? event.clientY : event.clientX; initial = ratio(); extent = Math.max(1, vertical() ? a.height + b.height : a.width + b.width);
            handle.setPointerCapture(event.pointerId); handle.classList.add('dragging'); event.preventDefault();
        };
        handle.onpointermove = event => { if (handle.hasPointerCapture(event.pointerId)) resize(initial + ((vertical() ? event.clientY : event.clientX) - origin) / extent); };
        const finish = () => { handle.classList.remove('dragging'); save(); };
        handle.onlostpointercapture = finish;
        handle.onpointerup = event => { if (handle.hasPointerCapture(event.pointerId)) handle.releasePointerCapture(event.pointerId); };
        handle.onkeydown = event => {
            const minus = vertical() ? 'ArrowUp' : 'ArrowLeft', plus = vertical() ? 'ArrowDown' : 'ArrowRight';
            if (![minus, plus, 'Home', 'End'].includes(event.key)) return;
            event.preventDefault(); resize(event.key === 'Home' ? .1 : event.key === 'End' ? .9 : ratio() + (event.key === minus ? -.05 : .05)); save();
        };
        return handle;
    }
    function tracks() {
        const list = visible();
        const sizes = list.flatMap((id, index) => [...(index ? ['6px'] : []), `minmax(0, ${state.weights[id]}fr)`]).join(' ') || '1fr';
        root.style.gridTemplateColumns = vertical() ? 'minmax(0, 1fr)' : sizes;
        root.style.gridTemplateRows = vertical() ? sizes : 'minmax(0, 1fr)';
    }
    function render() {
        const currentFocus = document.activeElement as HTMLElement | null;
        if (!state.visible.includes(active)) active = visible()[0] ?? 'source';
        for (const handle of separators) handle.remove(); separators.length = 0;
        const list = visible();
        for (const id of state.order) {
            const index = list.indexOf(id);
            panes[id].hidden = index < 0 || (phone.matches && id !== active);
            root.append(panes[id]);
            if (index >= 0 && index < list.length - 1) { const handle = separator(id, list[index + 1]); root.append(handle); separators.push(handle); }
        }
        root.append(empty); empty.hidden = list.length > 0;
        root.dataset.axis = vertical() ? 'vertical' : 'horizontal';
        root.dataset.view = active;
        frame.dataset.sidebarPosition = state.sidebarPosition;
        frame.style.setProperty('--sidebar-width', `${state.sidebarWidth}px`);
        tracks();
        axis.value = state.axis; side.value = state.sidebarPosition;
        for (const [id, checkbox] of toggles) checkbox.checked = id === 'sidebar' ? !host.sidebarHidden() : state.visible.includes(id as PaneId);
        for (const id of paneIds) node(`${id === 'simulation' ? 'simulation' : id}-tab`).setAttribute('aria-pressed', String(active === id));
        node('view-output').setAttribute('aria-pressed', String(state.visible.includes('output')));
        node('view-simulate').setAttribute('aria-pressed', String(state.visible.includes('simulation')));
        updateControls(); host.changed();
        if (currentFocus?.isConnected && !currentFocus.inert && currentFocus.getClientRects().length) currentFocus.focus({ preventScroll: true });
    }
    for (const id of [...paneIds, 'sidebar'] as const) {
        const checkbox = node<HTMLInputElement>(`show-${id}`); toggles.set(id, checkbox);
        checkbox.onchange = () => { if (id === 'sidebar') { host.showSidebar(checkbox.checked); render(); } else toggle(id, checkbox.checked); };
    }
    axis.onchange = () => change({ ...state, axis: axis.value as PaneLayout['axis'] });
    side.onchange = () => change({ ...state, sidebarPosition: side.value as PaneLayout['sidebarPosition'] });
    node('reset-layout').onclick = () => { exitFullscreen(); host.showSidebar(true); change(defaultLayout()); menu.open = false; };
    document.addEventListener('pointerdown', event => { if (!menu.contains(event.target as Node)) menu.open = false; });
    document.addEventListener('keydown', event => { if (event.key === 'Escape') { if (focused) { event.preventDefault(); event.stopImmediatePropagation(); exitFullscreen(); } menu.open = false; } }, true);
    for (const media of [phone, stacked, narrow]) media.addEventListener('change', () => { exitFullscreen(); render(); });
    const sidebarHandle = node('sidebar-resizer');
    const resizeSidebar = (width: number) => { state = { ...state, sidebarWidth: Math.max(200, Math.min(600, width)) }; frame.style.setProperty('--sidebar-width', `${state.sidebarWidth}px`); sidebarHandle.setAttribute('aria-valuenow', String(state.sidebarWidth)); host.changed(); };
    let sidebarStart = 0, sidebarWidth = 340;
    sidebarHandle.onpointerdown = event => { sidebarStart = event.clientX; sidebarWidth = state.sidebarWidth; sidebarHandle.setPointerCapture(event.pointerId); event.preventDefault(); };
    sidebarHandle.onpointermove = event => { if (sidebarHandle.hasPointerCapture(event.pointerId)) resizeSidebar(sidebarWidth + (event.clientX - sidebarStart) * (state.sidebarPosition === 'left' ? 1 : -1)); };
    sidebarHandle.onpointerup = event => { if (sidebarHandle.hasPointerCapture(event.pointerId)) sidebarHandle.releasePointerCapture(event.pointerId); };
    sidebarHandle.onlostpointercapture = save;
    sidebarHandle.onkeydown = event => { if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return; event.preventDefault(); resizeSidebar(event.key === 'Home' ? 200 : event.key === 'End' ? 600 : state.sidebarWidth + (event.key === 'ArrowLeft' ? -20 : 20) * (state.sidebarPosition === 'left' ? 1 : -1)); save(); };
    resizeSidebar(state.sidebarWidth); render();
    return { activate, reveal, sync: render, exitFullscreen };
}
