// Static highlighting for the documentation and output drawers. It does not
// load Monaco, so the guide stays readable without the editor. Class names
// map to the --k-* tokens in theme.css, the same ones the Monaco themes use.
export type HighlightLanguage = 'yodl' | 'firrtl' | 'rtlil' | 'plaintext';

const escapeHTML = (value: string) => value.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);
const keywords = /^(module|declare|test|let|const|type|package|import|for|in|if|else|match|true|false)$/;
const wordOperators = /^(and|or|not|xor|nand|nor|xnor|shl|shr|andr|orr|xorr)$/;
const types = /^(u\d+|s\d+|uint|sint|bool|clock|Nat|Type)$/;
const irKeywords = /^(circuit|module|extmodule|input|output|wire|node|reg|regreset|mem|inst|of|when|else|connect|attribute|parameter|cell|end|process|sync|update|assign|public|version|intmodule|invalidate|skip|printf|stop|assert|cover|assume)$/;
const irTypes = /^(UInt|SInt|Clock|Reset|AsyncReset|Analog)$/;
const irOperations = /^(mux|add|sub|mul|div|rem|and|or|xor|not|bits|cat|pad|eq|neq|lt|leq|gt|geq|shl|shr|dshl|dshr|head|tail|andr|orr|xorr|neg|cvt|asUInt|asSInt|asClock|validif)$/;

function tokenClass(token: string, language: HighlightLanguage): string {
    if (language === 'yodl') {
        if (token.startsWith('//')) return 'comment';
        if (token.startsWith('"')) return 'string';
        if (keywords.test(token) || wordOperators.test(token)) return 'keyword';
        if (types.test(token)) return 'type';
        if (/^\w+!$/.test(token)) return 'function';
        if (/^\d/.test(token)) return 'number';
        if (/^[A-Z]/.test(token)) return 'ident';
        if (/^[=<>+\-*/%:?.&|^~!]+$/.test(token)) return 'punct';
        return '';
    }
    if (token.startsWith(language === 'firrtl' ? ';' : '#')) return 'comment';
    if (token.startsWith('"')) return 'string';
    if (irKeywords.test(token)) return 'keyword';
    if (irTypes.test(token)) return 'type';
    if (irOperations.test(token)) return 'function';
    if (/^-?\d/.test(token)) return 'number';
    if (/^[<>=:]+$/.test(token)) return 'punct';
    return '';
}

export function highlight(source: string, language: HighlightLanguage = 'yodl'): string {
    if (language === 'plaintext') return escapeHTML(source);
    const comment = language === 'rtlil' ? '#[^\\n]*' : language === 'firrtl' ? ';[^\\n]*' : '\\/\\/[^\\n]*';
    // Only the IR languages have negative literals; in Yodl `a-1` is a subtraction.
    const number = language === 'yodl' ? '\\b\\d+' : '-?\\b\\d+';
    const pattern = new RegExp(`(${comment}|"(?:[^"\\\\\\n]|\\\\.)*"|\\b\\w+!|${number}(?:'[bhod]?[\\da-fA-F_]+)?\\b|\\b[a-zA-Z_]\\w*\\b|[=<>+\\-*/%:?.&|^~!]+)`, 'g');
    return source.split(pattern).map(token => {
        const kind = tokenClass(token, language);
        return kind ? `<span class="token-${kind}">${escapeHTML(token)}</span>` : escapeHTML(token);
    }).join('');
}

/** One row per source line, with a line-number gutter. */
export function highlightLines(source: string, language: HighlightLanguage = 'yodl'): string {
    const lines = source.replace(/\n$/, '').split('\n');
    return lines.map((line, index) => `<div class="code-line"><span class="ln">${index + 1}</span><span class="lt">${highlight(line, language) || ' '}</span></div>`).join('');
}
