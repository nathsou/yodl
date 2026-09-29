import { themeToken } from './theme.ts';

export let monaco: any;

let loading: Promise<void> | undefined;

// One loader and language registration for every editor on a page. Failed loads
// can be retried without leaving the static documentation unreadable.
export function loadMonaco(): Promise<void> {
    if (monaco) return Promise.resolve();
    return loading ??= initialise().catch(error => { loading = undefined; throw error; });
}
// Replaced by the site build with the content-hashed editor bundle and stylesheet.
declare const __MONACO_BUNDLE__: string;
declare const __MONACO_CSS__: string;
const editorBundle = typeof __MONACO_BUNDLE__ === 'undefined' ? './monaco.js' : __MONACO_BUNDLE__;
const editorStylesheet = typeof __MONACO_CSS__ === 'undefined' ? './monaco.css' : __MONACO_CSS__;

function loadStylesheet(href: string) {
    return new Promise<void>((resolve, reject) => {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = href;
        link.onload = () => resolve();
        link.onerror = () => { link.remove(); reject(new Error('Could not load the editor styles. Reload the page to try again.')); };
        document.head.append(link);
    });
}
async function initialise() {
    // The editor ships with the site (see bundle.ts); nothing is fetched from a CDN.
    if (!(window as any).monaco) {
        let timer: ReturnType<typeof setTimeout> | undefined;
        const timeout = new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('The code editor took too long to load. Try again.')), 30_000); });
        try {
            const loaded = Promise.all([loadStylesheet(new URL(editorStylesheet, import.meta.url).href), import(/* @vite-ignore */ new URL(editorBundle, import.meta.url).href)]);
            const [, module] = await Promise.race([loaded, timeout]);
            (window as any).monaco = module.monaco;
        } finally { clearTimeout(timer); }
    }
    monaco = (window as any).monaco;
    monaco.languages.register({ id: 'yodl' });

    // Define syntax highlighting rules for yodl
    monaco.languages.setMonarchTokensProvider('yodl', {
        keywords: [
            'declare', 'module', 'test', 'let', 'match', 'if', 'else', 'for', 'in', 'const', 'package', 'import', 'true', 'false'
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

                // Capitalised identifiers (modules, packages, constants) get their own colour.
                [/[A-Z]\w*/, { cases: { '@typeKeywords': 'type', '@default': 'ident.cap' } }],

                // Identifiers and keywords
                [/[a-zA-Z_]\w*/, {
                    cases: {
                        '@keywords': 'keyword',
                        '@typeKeywords': 'type',
                        '@wordOperators': 'keyword.operator',
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

                // Symbolic operators read as punctuation; word operators are keywords.
                [/@symbols/, 'delimiter'],

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
                [/[<>=:]+/, 'delimiter'],
            ] },
        });
    }
    applyEditorTheme();
}


// Fallbacks (the light theme) keep the editor usable where computed styles are unavailable.
const fallbackTokens: Record<string, string> = {
    panel: '#fefdfc', ink: '#211c17', mute: '#69625d', line: '#e2dfdb', sunk: '#f3f1ed', bg: '#faf9f6',
    acc: '#008381', 'acc-soft': '#dbf3f1', 'k-kw': '#6b46a0', 'k-ty': '#00717f', 'k-fn': '#945a00', 'k-nm': '#2b7440', 'k-id': '#23588a',
};
const token = (name: string) => (typeof getComputedStyle === 'function' ? themeToken(name) : '') || fallbackTokens[name];
const bare = (hex: string) => hex.replace('#', '');

/** Rebuilds the Monaco theme from the page's CSS tokens, so the editor follows
 * the light/dark theme and the chosen accent. Call it after either changes. */
export function applyEditorTheme() {
    if (!monaco) return;
    const dark = document.documentElement.dataset.theme === 'dark';
    monaco.editor.defineTheme('yodl', {
        base: dark ? 'vs-dark' : 'vs',
        inherit: true,
        rules: [
            { token: '', foreground: bare(token('ink')) },
            { token: 'keyword', foreground: bare(token('k-kw')) },
            { token: 'keyword.operator', foreground: bare(token('k-kw')) },
            { token: 'identifier', foreground: bare(token('ink')) },
            { token: 'operator', foreground: bare(token('mute')) },
            { token: 'type.identifier', foreground: bare(token('k-ty')) },
            { token: 'type', foreground: bare(token('k-ty')) },
            { token: 'function', foreground: bare(token('k-fn')) },
            { token: 'number', foreground: bare(token('k-nm')) },
            { token: 'string', foreground: bare(token('k-nm')) },
            { token: 'ident.cap', foreground: bare(token('k-id')) },
            { token: 'comment', foreground: bare(token('mute')) },
            { token: 'delimiter', foreground: bare(token('mute')) },
        ],
        colors: {
            'editor.background': token('panel'), 'editor.foreground': token('ink'),
            'editorLineNumber.foreground': token('mute') + '99', 'editorLineNumber.activeForeground': token('ink'),
            'editor.selectionBackground': token('acc-soft'), 'editor.inactiveSelectionBackground': token('sunk'),
            'editor.lineHighlightBackground': token('sunk') + '00', 'editor.lineHighlightBorder': token('sunk') + '00',
            'editorCursor.foreground': token('acc'), 'editorIndentGuide.background1': token('line'),
            // Brackets are punctuation, not a rainbow: keep them on the muted token colour.
            ...Object.fromEntries([1, 2, 3, 4, 5, 6].map(level => [`editorBracketHighlight.foreground${level}`, token('mute')])), 'editorBracketHighlight.unexpectedBracket.foreground': token('mute'),
            'editorWidget.background': token('panel'), 'editorWidget.border': token('line'),
            'scrollbarSlider.background': token('line') + 'aa', 'scrollbarSlider.hoverBackground': token('mute') + '66',
        },
    });
    monaco.editor.setTheme('yodl');
}

// Monaco measures glyphs once, so wait (briefly) for the web font before creating editors.
async function editorFontReady() {
    const fonts = (typeof document !== 'undefined' ? (document as any).fonts : undefined) as FontFaceSet | undefined;
    if (!fonts) return;
    try { await Promise.race([fonts.load('13.5px "IBM Plex Mono"'), new Promise(resolve => setTimeout(resolve, 1500))]); } catch { /* Fall back to the system monospace font. */ }
    fonts.ready.then(() => monaco?.editor.remeasureFonts?.());
}

export async function createEditor(container: HTMLElement, options: Record<string, unknown> = {}) {
    await loadMonaco();
    await editorFontReady();
    const common =  {
        automaticLayout: true, minimap: { enabled: false }, scrollBeyondLastLine: false,
        fontSize: 13.5, lineHeight: 23, fontFamily: '"IBM Plex Mono", ui-monospace, SFMono-Regular, Consolas, monospace',
        padding: { top: 18, bottom: 18 }, renderLineHighlight: 'none',
        glyphMargin: false, folding: true, lineNumbersMinChars: 3, lineDecorationsWidth: 18, overviewRulerLanes: 0,
        'semanticHighlighting.enabled': true,
        hideCursorInOverviewRuler: true, overviewRulerBorder: false,
        bracketPairColorization: { enabled: false }, guides: { indentation: false, bracketPairs: false }, matchBrackets: 'never',
        scrollbar: { useShadows: false, verticalScrollbarSize: 8, horizontalScrollbarSize: 8 },
        tabSize: 4, insertSpaces: true, fixedOverflowWidgets: true,
    };
    container.replaceChildren();
    return monaco.editor.create(container, { ...common, language: 'yodl', ariaLabel: 'Yodl source code', ...options });
}

export async function loadEditors() {
    // Explicitly own the source model: Monaco disposes an implicitly created
    // model when setModel detaches it, which breaks returning to the main tab.
    await loadMonaco();
    const model = monaco.editor.createModel('', 'yodl');
    const input = await createEditor(document.getElementById('input-panel')!, { model });
    const output = await createEditor(document.getElementById('output-panel')!, { readOnly: true, language: 'firrtl', ariaLabel: 'Compiled output' });
    return { input, output };
}
