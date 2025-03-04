import { readdirSync, readFileSync } from "node:fs";
import { join as joinPath } from 'node:path';

const EXAMPLES_PATH = "./examples";

export function getExampleFiles() {
    const files: Record<string, string> = {};
    
    for (const entry of readdirSync(EXAMPLES_PATH, { recursive: true, withFileTypes: true })) {
        if (!entry.isDirectory() && entry.name.endsWith('.yodl')) {
            const path = joinPath(entry.parentPath, entry.name);
            files[path] = readFileSync(path, 'utf-8');
        }
    }

    return files;
}
