import { expect, test } from 'bun:test';

test('the main source model survives switching to an import and back', async () => {
    const previousWindow = globalThis.window;
    const previousDocument = globalThis.document;
    const model = (value: string) => ({ value, disposed: false, dispose() { this.disposed = true; } });
    // Mirror Monaco's ownership rule: setModel disposes a model implicitly
    // created by editor.create, but leaves caller-owned models alive.
    const monaco = {
        languages: { register() {}, setMonarchTokensProvider() {}, setLanguageConfiguration() {} },
        editor: {
            defineTheme() {}, setTheme() {}, createModel: model,
            create(_container: unknown, options: any) {
                let current = options.model ?? model('');
                let ownsModel = !options.model;
                return {
                    getModel: () => current,
                    setModel(next: any) {
                        if (ownsModel) current.dispose();
                        ownsModel = false;
                        current = next;
                    },
                    getValue() { if (current.disposed) throw new Error('Model disposed'); return current.value; },
                    setValue(value: string) { current.value = value; },
                };
            },
        },
    };
    const loader = Object.assign((_modules: string[], ready: () => void) => ready(), { config() {} });
    try {
        globalThis.window = { require: loader, monaco } as any;
        globalThis.document = { documentElement: { dataset: {} }, getElementById: () => ({ replaceChildren() {} }) } as any;
        const { loadEditors } = await import('../main/playground-editor.ts');
        const { input } = await loadEditors();
        input.setValue('module HelloSim() -> () {}');
        const main = input.getModel();
        const font = model('module Font() -> () {}');
        for (let i = 0; i < 3; i++) {
            input.setModel(font);
            expect(input.getValue()).toContain('Font');
            input.setModel(main);
            expect(main.disposed).toBe(false);
            expect(input.getValue()).toContain('HelloSim');
        }
    } finally {
        globalThis.window = previousWindow;
        globalThis.document = previousDocument;
    }
});
