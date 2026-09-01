// The driver currently returns rendered diagnostics. Only use its explicit span
// header for markers; do not infer locations from the displayed source excerpt.
export function diagnosticLocation(message: string, path: string) {
    const escaped = path.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const match = message.match(new RegExp(`${escaped}:(\\d+)\\.(\\d+)-(\\d+)\\.(\\d+)`));
    if (!match) return null;
    return { startLineNumber: +match[1], startColumn: +match[2], endLineNumber: +match[3], endColumn: +match[4] };
}
