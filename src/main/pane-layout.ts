export const paneIds = ['source', 'output', 'simulation'] as const;
export type PaneId = typeof paneIds[number];
export type PaneLayout = {
    order: PaneId[]; visible: PaneId[]; weights: Record<PaneId, number>;
    axis: 'auto' | 'horizontal' | 'vertical'; sidebarPosition: 'left' | 'right'; sidebarWidth: number;
};
export const defaultLayout = (): PaneLayout => ({ order: [...paneIds], visible: ['source', 'output'], weights: { source: 1, output: 1, simulation: 1 }, axis: 'auto', sidebarPosition: 'left', sidebarWidth: 340 });
const clamp = (value: number, low: number, high: number) => Math.min(high, Math.max(low, value));
export function readLayout(value: string | null): PaneLayout {
    const fallback = defaultLayout();
    try {
        const saved = JSON.parse(value ?? 'null');
        if (!saved || !Array.isArray(saved.order) || saved.order.length !== paneIds.length || new Set(saved.order).size !== paneIds.length || saved.order.some((id: any) => !paneIds.includes(id))) return fallback;
        if (!Array.isArray(saved.visible) || saved.visible.some((id: any) => !paneIds.includes(id)) || new Set(saved.visible).size !== saved.visible.length) return fallback;
        if (!['auto', 'horizontal', 'vertical'].includes(saved.axis) || !['left', 'right'].includes(saved.sidebarPosition)) return fallback;
        if (!Number.isFinite(saved.sidebarWidth) || paneIds.some(id => !Number.isFinite(saved.weights?.[id]) || saved.weights[id] <= 0)) return fallback;
        return { order: saved.order, visible: saved.visible, axis: saved.axis, sidebarPosition: saved.sidebarPosition, sidebarWidth: clamp(saved.sidebarWidth, 200, 600), weights: Object.fromEntries(paneIds.map(id => [id, clamp(saved.weights[id], .1, 10)])) as Record<PaneId, number> };
    } catch { return fallback; }
}
export function movePane(layout: PaneLayout, pane: PaneId, target: PaneId): PaneLayout {
    const order = layout.order.filter(id => id !== pane);
    order.splice(layout.order.indexOf(target), 0, pane);
    return { ...layout, order };
}
/** Resize only the adjacent pair; the rest of the layout retains its size. */
export function resizePair(layout: PaneLayout, first: PaneId, second: PaneId, fraction: number): PaneLayout {
    const total = layout.weights[first] + layout.weights[second];
    const ratio = clamp(fraction, .1, .9);
    return { ...layout, weights: { ...layout.weights, [first]: total * ratio, [second]: total * (1 - ratio) } };
}
