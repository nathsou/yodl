export const stages = {
    write_source: { label: 'Source', extension: 'yodl', language: 'yodl', description: 'Resolved source, with imported declarations available to the compiler.' },
    write_mono: { label: 'Monomorphised', extension: 'yodl', language: 'yodl', description: 'Generic modules specialised with concrete parameters.' },
    write_typed: { label: 'Typed', extension: 'yodl', language: 'yodl', description: 'Expressions annotated with their resolved types and widths.' },
    write_simplified: { label: 'Simplified', extension: 'yodl', language: 'yodl', description: 'Core representation with loops expanded and expressions simplified.' },
    write_firrtl: { label: 'FIRRTL', extension: 'fir', language: 'firrtl', description: 'Hardware represented as ports, operations, registers, and connections.' },
    write_low_firrtl: { label: 'Low FIRRTL', extension: 'fir', language: 'firrtl', description: 'FIRRTL after lowering passes, ready for downstream tools.' },
    write_rtlil: { label: 'RTLIL', extension: 'il', language: 'rtlil', description: 'Hardware in the intermediate language used by Yosys.' },
} as const;
export type Stage = keyof typeof stages;
