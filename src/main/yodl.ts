import type * as MoonBit from "../../target/js/release/build/lib/driver/moonbit";
import * as yodl from "../../target/js/release/build/lib/driver/driver";

type Result<T> = MoonBit.Result<T, string>;

function Ok<T>(value: T): Result<T> {
    return { $tag: 1, _0: value };
}

function Err(message: string): Result<any> {
    return { $tag: 0, _0: message };
}

type FileSystem = {
    path_exists: (path: string) => boolean;
    create_dir: (path: string) => Result<void>;
    write_string_to_file: (path: string, content: string) => Result<void>;
    read_dir: (path: string) => Result<string[]>;
    is_dir: (path: string) => Result<boolean>;
    read_file_to_string: (path: string) => Result<string>;
};

type FileNode = {
    type: 'file';
    name: string;
    content: string;
};

type DirectoryNode = {
    type: 'dir';
    name: string
    children: Map<string, DirectoryNode | FileNode>;
};

const PATH_SEPARATOR = '/';

type TreeNode = FileNode | DirectoryNode;

function parsePath(path: string): string[] {
    const components: string[] = [];

    for (const part of path.split(PATH_SEPARATOR)) {
        if (part === '..') {
            components.pop();
        } else if (part === '.') {
            // ignore
        } else if (part.length > 0) {
            components.push(part);
        }
    }

    return components;
}

function resolvePath(root: TreeNode, path: string): TreeNode | null {
    let node = root;

    for (const part of parsePath(path)) {
        if (node.type === 'file') {
            break;
        }

        const child = node.children.get(part);

        if (child === undefined) {
            return null;
        }

        node = child;
    }

    return node;
}

function resolveParentDirectory(root: TreeNode, path: string): DirectoryNode | null {
    const components = parsePath(path);
    components.pop();
    const parent = resolvePath(root, components.join(PATH_SEPARATOR)) ?? root;

    if (parent?.type === 'dir') {
        return parent; 
    }

    return null;
}

function dirName(path: string): string | undefined {
    return parsePath(path).at(-1);
}

function createInMemoryFileSystem(root: TreeNode): FileSystem {
    return {
        path_exists: (path: string) => {
            return resolvePath(root, path) !== null;
        },
        create_dir: (path: string) => {
            const parent = resolveParentDirectory(root, path);
            const dir = dirName(path);

            if (dir !== undefined) {
                parent?.children.set(dir, {
                    type: 'dir',
                    name: dir,
                    children: new Map(),
                });
            }

            return Ok(undefined);
        },
        write_string_to_file: (path: string, content: string) => {
            const parent = resolveParentDirectory(root, path);
            const fileName = parsePath(path).at(-1);

            if (fileName !== undefined) {
                parent?.children.set(fileName, {
                    type: 'file',
                    name: fileName,
                    content,
                });
            }

            return Ok(undefined);
        },
        read_dir: (path: string) => {
            const node = resolvePath(root, path);

            if (node === null || node.type === 'file') {
                return Err(`Directory does not exist for path '${path}'`);
            }

            return Ok([...node.children.keys()]);
        },
        is_dir: (path: string) => {
            const node = resolvePath(root, path);
            return Ok(node?.type === 'dir');
        },
        read_file_to_string: (path: string) => {
            const node = resolvePath(root, path);

            if (node === null || node.type === 'dir') {
                return Err(`File does not exist for path '${path}'`);
            }

            return Ok(node.content);
        },
    };
}

function createTree(files: Record<string, string>): TreeNode {
    const root: DirectoryNode = {
        type: 'dir',
        name: '<root>',
        children: new Map(),
    };

    for (const [path, content] of Object.entries(files)) {
        const parent = resolveParentDirectory(root, path);
        const parts = parsePath(path);
        let node: TreeNode = root;

        for (const part of parts.slice(0, -1)) {
            if (node.type === 'file') {
                throw new Error(`Invalid path '${path}'`);
            }

            let child = node.children.get(part);

            if (child === undefined) {
                child = {
                    type: 'dir',
                    name: part,
                    children: new Map(),
                };

                node.children.set(part, child);
            }

            node = child;
        }

        const fileName = parts.at(-1);

        if (fileName === undefined || node.type === 'file') {
            throw new Error(`Invalid path '${path}'`);
        }

        node.children.set(fileName, {
            type: 'file',
            name: fileName,
            content,
        });
    }

    return root;
}

const tree = createTree({
    'examples/Timing.yodl': `
        module Counter<N: uint>(clk: clock, rst: bool) -> (q: uint<N>) {
            let counter = Reg<uint<N>>(clk, rst, q);
            counter.d = counter.q + 1'd1;
        }
    `,
    'examples/Yolo.yodl': `
        import Timing

        module Yolo(clk: clock, rst: bool) -> (leds: uint<8>) {
            leds = Timing::Counter<25>(clk, rst).q[24-:8];
        }
    `,
});

function unwrap<T>(result: MoonBit.Result<T, any>): T {
    if (result.$tag === 0) {
        throw new Error(JSON.stringify(result._0));
    }

    return result._0;
}

const fs = createInMemoryFileSystem(tree);

const commands = unwrap(yodl.parse_commands("write_firrtl output/Yolo.fir"));
unwrap(yodl.run('examples/Yolo.yodl', commands, fs));

console.log(unwrap(fs.read_file_to_string('output/Yolo.fir')));
