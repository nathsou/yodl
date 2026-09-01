import { readdirSync, readFileSync } from "node:fs";
import { join as joinPath } from 'node:path';

function readYodlFiles(directory: string) {
    const files: Record<string, string> = {};
    
    for (const entry of readdirSync(directory, { recursive: true, withFileTypes: true })) {
        if (!entry.isDirectory() && entry.name.endsWith('.yodl')) {
            const path = joinPath(entry.parentPath, entry.name);
            files[path] = readFileSync(path, 'utf-8');
        }
    }

    return files;
}

export function getExampleFiles() {
    return readYodlFiles('./examples');
}

export function getTourFiles() {
    return readYodlFiles('./tour');
}
