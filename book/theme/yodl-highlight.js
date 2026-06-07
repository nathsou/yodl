// Highlight.js language definition for yodl

hljs.registerLanguage('yodl', function (hljs) {
  return {
    name: 'yodl',
    aliases: ['yodl'],
    keywords: {
      keyword: 'declare module let match if else for in const package import',
      type: 'uint sint bool clock type Nat Type',
      literal: 'true false'
    },
    contains: [
      // Line comments (// comment)
      hljs.COMMENT('//', '$'),
      // Strings
      {
        className: 'string',
        begin: /"/,
        end: /"/,
        illegal: /\n/,
        contains: [hljs.BACKSLASH_ESCAPE]
      },
      // Characters
      {
        className: 'string',
        begin: /'/,
        end: /'/,
        illegal: /\n/,
        contains: [hljs.BACKSLASH_ESCAPE]
      },
      // Numeric constants: both integer forms and digit groups with underscores
      {
        className: 'number',
        relevance: 0,
        variants: [
          { begin: '\\b\\d+\'[bhod]?[A-Za-z0-9_]+\\b' }, // Base-specific literals like 2'b01, 16'hFF
          { begin: '\\b\\d+(?:_\\d+)*\\b' } // Regular numbers with optional underscore separators
        ]
      },
      // Sized integer types: u8, s7, u32, ...
      {
        className: 'type',
        begin: /\b[us]\d+\b/
      },
      // Built-in function calls: identifiers ending with '!'
      {
        className: 'function',
        begin: /[A-Za-z_0-9]+!/
      },
      // Attributes: identifiers preceded by '@'
      {
        className: 'meta',
        begin: /@[A-Za-z_][A-Za-z0-9_]*/
      },
      // Operators
      {
        className: 'operator',
        begin: /\b(?:and|or|not|xor|nand|nor|xnor|shl|shr|andr|orr|xorr)\b|==|!=|<=|>=|<:|>:|\+:|-:|\.\.<|\.\.=|\.\.|=>|->|::|\+|-|\*|\/|%|\?|\./
      },
      // Punctuation: commas, parentheses, semicolons, colons, braces, brackets
      {
        className: 'punctuation',
        begin: /[(){}\[\],;:]/
      },
    ]
  };
});

hljs.initHighlightingOnLoad();
