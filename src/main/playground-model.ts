import lessons from '../../tour/lessons.json';
import { getExampleFiles, getTourFiles } from './examples.ts' with { type: 'macro' };

export const files: Record<string, string> = { ...getExampleFiles(), ...getTourFiles() };
export const tour = lessons;
export const examples = Object.keys(files).filter(path => /^examples\/[^/]+\.yodl$/.test(path)).sort();
export const stages = {
    write_source: { label: 'Source', extension: 'yodl', language: 'yodl', description: 'Resolved source, with imported declarations available to the compiler.' },
    write_mono: { label: 'Monomorphised', extension: 'yodl', language: 'yodl', description: 'Generic modules specialised with concrete parameters.' },
    write_typed: { label: 'Typed', extension: 'yodl', language: 'yodl', description: 'Expressions annotated with their resolved types and widths.' },
    write_simplified: { label: 'Simplified', extension: 'yodl', language: 'yodl', description: 'Core representation with loops expanded and expressions simplified.' },
    write_firrtl: { label: 'FIRRTL', extension: 'fir', language: 'firrtl', description: 'Hardware represented as ports, operations, registers, and connections.' },
    write_low_firrtl: { label: 'Low FIRRTL', extension: 'fir', language: 'firrtl', description: 'FIRRTL after lowering passes, ready for downstream tools.' },
    write_rtlil: { label: 'RTLIL', extension: 'il', language: 'rtlil', description: 'Hardware in the intermediate language used by Yosys.' },
} as const;
export type Stage = keyof typeof stages;
export type Mode = 'tour' | 'examples';
export type Selection = { mode: Mode; path: string; stage: Stage };
export type SharedProgram = Selection & { source: string; version: 1 };
export const blankPath = 'examples/Playground.yodl';
export const initialSelection: Selection = { mode: 'tour', path: `tour/${tour[0].file}`, stage: 'write_firrtl' };
export function validSelection(value: unknown): value is Selection {
    if (!value || typeof value !== 'object') return false;
    const v = value as Selection;
    return Object.hasOwn(stages, v.stage) && (
        v.mode === 'tour' ? tour.some(lesson => `tour/${lesson.file}` === v.path) :
        v.mode === 'examples' && (examples.includes(v.path) || v.path === blankPath)
    );
}
export function encodeShare(program: Selection & { source: string }): string {
    const bytes = new TextEncoder().encode(JSON.stringify({ ...program, version: 1 }));
    let binary = '';
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
export function decodeShare(hash: string): SharedProgram | null {
    if (!hash.startsWith('#code=')) return null;
    if (hash.length > 200_000) throw new Error('This shared program is too large to open.');
    try {
        const binary = atob(hash.slice(6).replaceAll('-', '+').replaceAll('_', '/'));
        const value = JSON.parse(new TextDecoder().decode(Uint8Array.from(binary, c => c.charCodeAt(0))));
        if (value.version !== 1 || !validSelection(value) || typeof value.source !== 'string') throw new Error();
        return value;
    } catch {
        throw new Error('This share link is invalid or uses an unsupported version.');
    }
}

// The driver currently returns rendered diagnostics. Only use its explicit span
// header for markers; do not infer locations from the displayed source excerpt.
export function diagnosticLocation(message: string, path: string) {
    const escaped = path.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = message.match(new RegExp(`${escaped}:(\\d+)\\.(\\d+)-(\\d+)\\.(\\d+)`));
    if (!match) return null;
    return { startLineNumber: +match[1], startColumn: +match[2], endLineNumber: +match[3], endColumn: +match[4] };
}
