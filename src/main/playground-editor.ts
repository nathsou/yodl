export let monaco: any;

export async function loadEditors() {
    await new Promise<void>((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('The code editor took too long to load. Check your connection and reload.')), 15_000);
        const ready = () => { clearTimeout(timeout); resolve(); };
        const failed = (error: unknown) => { clearTimeout(timeout); reject(error); };
        const loader = (window as any).require;
        if (!loader) return failed(new Error('The code editor could not load. Check your connection and reload.'));
        loader.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.56.0/min/vs' } });
        loader(['vs/editor/editor.main'], ready, failed);
    });
    monaco = (window as any).monaco;
    monaco.languages.register({ id: 'yodl' });

    // Define syntax highlighting rules for yodl
    monaco.languages.setMonarchTokensProvider('yodl', {
        keywords: [
            'declare', 'module', 'let', 'match', 'if', 'else', 'for', 'in', 'const', 'package', 'import', 'true', 'false'
        ],
        typeKeywords: [
            'uint', 'sint', 'bool', 'clock', 'type', 'Nat', 'Type'
        ],
        wordOperators: [
            'and', 'or', 'not', 'xor', 'nand', 'nor', 'xnor', 'shl', 'shr', 'andr', 'orr', 'xorr'
        ],
        operators: [
            '==', '!=', '<=', '>=', '<:', '>:', '+:', '-:', '..', '..<', '..=',
            '+', '-', '*', '/', '%', '=>', '?', ':', '.', '->', '::'
        ],
        symbols: /[=><!~?:&|+\-*/^%.]+/,
        tokenizer: {
            root: [
                // Builtin function calls: name ending with !
                [/\w+!/, 'function'],

                // Sized integer types: u8, s7, u32, ...
                // (must come before the generic identifier rule)
                [/\b[us]\d+\b/, 'type'],

                // Identifiers and keywords
                [/[a-zA-Z_]\w*/, {
                    cases: {
                        '@keywords': 'keyword',
                        '@typeKeywords': 'type',
                        '@wordOperators': 'operator',
                        '@default': 'identifier'
                    }
                }],

                // Strings
                [/"([^"\\]|\\.)*$/, 'string.invalid'], // Non-terminated string
                [/"/, { token: 'string.quote', bracket: '@open', next: '@string' }],

                // Characters
                [/'[^'\\]'/, 'string'],
                [/'\\.'/, 'string'],

                // Comments
                [/\/\/.*$/, 'comment'],

                // Numbers
                [/\b\d+'[bhod]?\w+\b/, 'number'], // Base-specific literals
                [/\b\d+(_\d+)*\b/, 'number'], // Numbers with optional underscore separators

                // Operators
                [/@symbols/, {
                    cases: {
                        '@operators': 'operator',
                        '@default': 'delimiter'
                    }
                }],

                // Delimiters and operators
                [/[(){}\[\],;]/, 'delimiter'],

                // Whitespace
                [/\s+/, 'white']
            ],

            string: [
                [/[^\\"]+/, 'string'],
                [/\\./, 'string.escape'],
                [/"/, { token: 'string.quote', bracket: '@close', next: '@pop' }]
            ]
        }
    });

    monaco.editor.defineTheme('yodl-light', {
        base: 'vs',
        inherit: true,
        rules: [
            { token: 'function', foreground: '795E26', fontStyle: 'bold' },
            { token: 'operator', foreground: '0000FF' }
        ],
        colors: { 'editor.background': '#ffffff', 'editor.foreground': '#25362b', 'editorLineNumber.foreground': '#829087', 'editor.selectionBackground': '#d9ebdf', 'editor.lineHighlightBackground': '#f7f9f6' }
    });

    monaco.editor.defineTheme('yodl-dark', {
        base: 'vs-dark',
        inherit: true,
        rules: [
            { token: 'function', foreground: 'DCDCAA', fontStyle: 'bold' },
            { token: 'operator', foreground: '569CD6' }
        ],
        colors: { 'editor.background': '#1d241f', 'editor.foreground': '#e1e9e2', 'editorLineNumber.foreground': '#73867a', 'editor.selectionBackground': '#344e3c', 'editor.lineHighlightBackground': '#242e27' }
    });

    monaco.languages.setLanguageConfiguration('yodl', {
        comments: { lineComment: '//' },
        brackets: [['{', '}'], ['[', ']'], ['(', ')']],
        autoClosingPairs: [{ open: '{', close: '}' }, { open: '[', close: ']' }, { open: '(', close: ')' }, { open: '"', close: '"' }],
    });
    for (const language of ['firrtl', 'rtlil']) {
        monaco.languages.register({ id: language });
        monaco.languages.setMonarchTokensProvider(language, {
            tokenizer: { root: [
                [language === 'firrtl' ? /;.*/ : /#.*/, 'comment'],
                [/"[^"\\]*(?:\\.[^"\\]*)*"/, 'string'],
                [/\b(?:circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign)\b/, 'keyword'],
                [/\b(?:UInt|SInt|Clock|Reset|AsyncReset)\b/, 'type'],
                [/\b(?:mux|add|sub|mul|and|or|xor|not|bits|cat|pad|eq|lt|gt)\b/, 'function'],
                [/-?\b\d+(?:'[01xzm-]+)?\b/, 'number'],
                [/[<>=:]+/, 'operator'],
            ] },
        });
    }
    const common = {
        automaticLayout: true, minimap: { enabled: false }, scrollBeyondLastLine: false,
        fontSize: 14, lineHeight: 23, fontFamily: '"SFMono-Regular", Consolas, "Liberation Mono", monospace',
        padding: { top: 20, bottom: 20 }, renderLineHighlight: 'gutter',
        scrollbar: { useShadows: false, verticalScrollbarSize: 8, horizontalScrollbarSize: 8 },
        tabSize: 4, insertSpaces: true, fixedOverflowWidgets: true,
    };
    document.getElementById('input-panel')!.replaceChildren();
    const input = monaco.editor.create(document.getElementById('input-panel'), { ...common, language: 'yodl', ariaLabel: 'Yodl source code' });
    const output = monaco.editor.create(document.getElementById('output-panel'), { ...common, readOnly: true, language: 'firrtl', ariaLabel: 'Compiled output' });
    return { input, output };
}
