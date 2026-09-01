export function encodeProgram(value: unknown): string {
    const bytes = new TextEncoder().encode(JSON.stringify(value));
    let binary = '';
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
export function decodeProgram(value: string): unknown {
    if (value.length > 200_000) throw new Error('This shared program is too large to open.');
    const binary = atob(value.replaceAll('-', '+').replaceAll('_', '/'));
    return JSON.parse(new TextDecoder().decode(Uint8Array.from(binary, c => c.charCodeAt(0))));
}
export function validSourcePath(path: unknown): path is string {
    return typeof path === 'string' && /^(book\/src|examples|tour)\/[\w./-]+\.yodl$/.test(path) && !path.split('/').some(part => part === '..' || part === '.');
}
export function validFiles(files: unknown): files is Record<string, string> {
    return !!files && typeof files === 'object' && !Array.isArray(files) && Object.entries(files).every(([path, source]) => validSourcePath(path) && typeof source === 'string');
}
