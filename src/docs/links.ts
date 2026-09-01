// Shared by the book and tour; lesson IDs and chapter URLs are stable links.
export const chapterLessons: Record<string, { id: string; title: string }[]> = {
    '01_presentation': [{ id: 'gates', title: 'Your first circuit' }],
    '02_getting_started': [{ id: 'gates', title: 'Your first circuit' }, { id: 'counter', title: 'Describe the next state' }],
    '03_data_types': [{ id: 'widths', title: 'Give every bit a place' }, { id: 'records', title: 'Name a group of signals' }],
    '04_constructs': [{ id: 'modules', title: 'Connect reusable modules' }, { id: 'generics', title: 'Parameterise a design' }, { id: 'packages', title: 'Organise a design' }],
    '05_operators': [{ id: 'bits', title: 'Take signals apart' }],
    '06_control_flow': [{ id: 'selection', title: 'Choose a signal' }, { id: 'vectors', title: 'Build parallel hardware' }],
    '07_built_in_functions': [{ id: 'bits', title: 'Take signals apart' }, { id: 'counter', title: 'Describe the next state' }],
    '08_primitive_modules': [{ id: 'registers', title: 'Remember a value' }, { id: 'memory', title: 'Store a small table' }],
    '09_external_modules': [{ id: 'modules', title: 'Connect reusable modules' }],
};
