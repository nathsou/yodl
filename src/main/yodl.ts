import type * as MoonBit from "../../_build/js/release/build/lib/driver/moonbit.d.ts";
export * as yodl from "../../_build/js/release/build/lib/driver/driver.js";

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

type Externals = {
    fs: FileSystem;
    println: (str: string) => void;
    get_args: () => string[];
    exit: (code: number) => void;
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

export function createInMemoryFileSystem(files: Record<string, string>): FileSystem & { root: DirectoryNode } {
    const root = createTree(files);

    return {
        root,
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

function createTree(files: Record<string, string>): DirectoryNode {
    const root: DirectoryNode = {
        type: 'dir',
        name: '<root>',
        children: new Map(),
    };

    for (const [path, content] of Object.entries(files)) {
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

export function unwrap<T>(result: MoonBit.Result<T, any>): T {
    if (result.$tag === 0) {
        throw new Error(JSON.stringify(result._0));
    }

    return result._0;
}

export const ext: Externals = {
    fs: createInMemoryFileSystem({}),
    println: str => console.log(str),
    get_args: () => [],
    exit: code => {
        throw new Error(`Exit with code ${code}`);
    },
};
