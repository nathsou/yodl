import { encodeProgram, decodeProgram, validFiles, validSourcePath } from './share-codec.ts';
import lessons from '../../tour/lessons.json';
import { getExampleFiles, getTourFiles } from './examples.ts' with { type: 'macro' };

export const files: Record<string, string> = { ...getExampleFiles(), ...getTourFiles() };
export const tour = lessons;
export const examples = Object.keys(files).filter(path => /^examples\/[^/]+\.yodl$/.test(path)).sort();
export { stages } from './compiler-stages.ts';
import { stages } from './compiler-stages.ts';
import type { Stage } from './compiler-stages.ts';
export type { Stage } from './compiler-stages.ts';
export type Mode = 'tour' | 'examples';
export type Selection = { mode: Mode; path: string; stage: Stage };
export type SharedProgram = Selection & { source: string; version: 1 | 2; files?: Record<string, string>; entryPath?: string; origin?: string };
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
export function encodeShare(program: Selection & { source: string; files?: Record<string, string>; entryPath?: string; origin?: string }): string {
    return encodeProgram({ ...program, version: program.entryPath ? 2 : 1 });
}
export function decodeShare(hash: string): SharedProgram | null {
    if (!hash.startsWith('#code=')) return null;
    try {
        const value = decodeProgram(hash.slice(6)) as SharedProgram;
        if (![1, 2].includes(value.version) || !validSelection(value) || typeof value.source !== 'string') throw new Error();
        if (value.version === 2 && (!validSourcePath(value.entryPath) || !validFiles(value.files) || (value.origin !== undefined && !/^[a-zA-Z0-9_-]+\.html#[a-z0-9-]+$/.test(value.origin)))) throw new Error();
        if (value.version === 1) return { version: 1, mode: value.mode, path: value.path, stage: value.stage, source: value.source };
        return value;
    } catch {
        throw new Error('This share link is invalid, too large, or uses an unsupported version.');
    }
}

export { diagnosticLocation } from './diagnostics.ts';
