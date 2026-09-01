import { compile } from './playground-compiler.ts';
import type { CompileRequest } from './playground-compiler.ts';

self.onmessage = (event: MessageEvent<CompileRequest>) => {
    self.postMessage(compile(event.data));
};
