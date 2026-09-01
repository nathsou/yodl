import { expect, test } from 'bun:test';
import { decodeShare, encodeShare, blankPath } from '../main/playground-model.ts';
import { encodeProgram } from '../main/share-codec.ts';

test('existing playground links remain compatible and ignore v2-only fields', () => {
    const program = { mode: 'examples' as const, path: blankPath, stage: 'write_firrtl' as const, source: '// λ\nmodule Top() -> () {}' };
    expect(decodeShare(`#code=${encodeShare(program)}`)).toEqual({ ...program, version: 1 });
    expect(decodeShare(`#code=${encodeProgram({ ...program, version: 1, files: 'not-files', entryPath: '../unsafe', origin: 'bad' })}`)).toEqual({ ...program, version: 1 });
});

test('documentation handoff preserves entry path, files, stage and backlink', () => {
    const program = { mode: 'examples' as const, path: blankPath, stage: 'write_typed' as const, source: 'module Top() -> () {}', entryPath: 'book/src/ex-test.yodl', files: {}, origin: '03_data_types.html#ex-width' };
    expect(decodeShare(`#code=${encodeShare(program)}`)).toEqual({ ...program, version: 2 });
    expect(() => decodeShare(`#code=${encodeProgram({ ...program, version: 2, entryPath: '../secret.yodl' })}`)).toThrow();
    expect(() => decodeShare(`#code=${encodeProgram({ ...program, version: 2, origin: 'https://other.example/' })}`)).toThrow();
});
