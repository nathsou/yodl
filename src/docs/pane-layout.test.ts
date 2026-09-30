import { expect, test } from 'bun:test';
import { defaultLayout, readLayout, movePane, resizePair } from '../main/pane-layout.ts';

test('saved arrangements round-trip with order, hidden panes, orientation and sizes', () => {
    const layout = { ...defaultLayout(), order: ['simulation', 'output', 'source'] as const, visible: ['simulation'], axis: 'vertical', sidebarPosition: 'right', sidebarWidth: 420, weights: { source: .6, output: 1.4, simulation: 2 } };
    expect(readLayout(JSON.stringify(layout))).toEqual(layout);
    expect(readLayout(JSON.stringify({ ...defaultLayout(), visible: [] })).visible).toEqual([]);
});

test('invalid or old saved arrangements recover to the default', () => {
    for (const saved of [null, '', 'not JSON', '{}', JSON.stringify({ ...defaultLayout(), order: ['source', 'output', 'output'] }), JSON.stringify({ ...defaultLayout(), visible: ['unknown'] }), JSON.stringify({ ...defaultLayout(), axis: 'diagonal' }), JSON.stringify({ ...defaultLayout(), sidebarPosition: 'top' }), JSON.stringify({ ...defaultLayout(), weights: { source: 0, output: 1, simulation: 1 } }), JSON.stringify({ ...defaultLayout(), sidebarWidth: null })]) expect(readLayout(saved)).toEqual(defaultLayout());
});

test('moving earlier and later retains all panes, visibility, and relative sizes', () => {
    const layout = defaultLayout();
    expect(movePane(layout, 'output', 'source').order).toEqual(['output', 'source', 'simulation']);
    expect(movePane(layout, 'source', 'output').order).toEqual(['output', 'source', 'simulation']);
    const moved = movePane(layout, 'simulation', 'source');
    expect(moved.order).toEqual(['simulation', 'source', 'output']);
    expect(moved.visible).toEqual(layout.visible);
    expect(moved.weights).toEqual(layout.weights);
    expect(layout.order).toEqual(['source', 'output', 'simulation']);
});

test('resizing preserves the adjacent pair total and leaves other panes alone', () => {
    const layout = defaultLayout();
    const resized = resizePair(layout, 'source', 'output', .7);
    expect(resized.weights).toEqual({ source: 1.4, output: .6000000000000001, simulation: 1 });
    expect(resized.weights.source + resized.weights.output).toBe(2);
    expect(resizePair(layout, 'source', 'output', -5).weights.source).toBe(.2);
    expect(resizePair(layout, 'source', 'output', 5).weights.output).toBeCloseTo(.2);
    expect(layout.weights).toEqual({ source: 1, output: 1, simulation: 1 });
});

test('stored sizes are bounded without losing an otherwise valid arrangement', () => {
    const layout = readLayout(JSON.stringify({ ...defaultLayout(), sidebarWidth: 10000, weights: { source: .01, output: 1000, simulation: 1 } }));
    expect(layout.sidebarWidth).toBe(600);
    expect(layout.weights).toEqual({ source: .1, output: 10, simulation: 1 });
});
