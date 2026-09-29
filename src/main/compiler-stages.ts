export const stages = {
    write_source: { label: 'Source', short: 'Source', extension: 'yodl', language: 'yodl', description: 'Resolved source, with imported declarations available to the compiler.' },
    write_mono: { label: 'Monomorphised', short: 'Mono', extension: 'yodl', language: 'yodl', description: 'Generic modules specialised with concrete parameters.' },
    write_typed: { label: 'Typed', short: 'Typed', extension: 'yodl', language: 'yodl', description: 'Expressions annotated with their resolved types and widths.' },
    write_simplified: { label: 'Simplified', short: 'Simplified', extension: 'yodl', language: 'yodl', description: 'Core representation with loops expanded and expressions simplified.' },
    write_firrtl: { label: 'FIRRTL', short: 'FIRRTL', extension: 'fir', language: 'firrtl', description: 'Hardware represented as ports, operations, registers, and connections.' },
    write_low_firrtl: { label: 'Low FIRRTL', short: 'Low', extension: 'fir', language: 'firrtl', description: 'FIRRTL after lowering passes, ready for downstream tools.' },
    write_rtlil: { label: 'RTLIL', short: 'RTLIL', extension: 'il', language: 'rtlil', description: 'Hardware in the intermediate language used by Yosys.' },
    test: { label: 'Tests', short: 'Tests', extension: 'txt', language: 'plaintext', description: 'Run procedural testbenches and report each passing test.' },
} as const;
export type Stage = keyof typeof stages;
