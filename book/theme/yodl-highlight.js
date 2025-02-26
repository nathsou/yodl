// Highlight.js language definition for yodl
// Highlight.js language definition for yodl
hljs.registerLanguage('yodl', function(hljs) {
  return {
    name: 'yodl',
    aliases: ['yodl'],
    keywords: {
      keyword: 'declare module let match if else for in const package import',
      type: 'uint sint bool clock type',
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

      // Numeric constants: both integer forms and digit groups with underscores
      {
        className: 'number',
        // Matches either: a simple number with optional underscores OR a number with a base suffix (e.g. 123'b...)
        begin: /\b\d+(?:_\d+)*\b|\b\d+'[bhod]?[A-Za-z0-9_]+\b/
      },

      // Function names: identifiers starting with a '$'
      {
        className: 'function',
        begin: /\$[A-Za-z_0-9]+/
      },

      // Attributes: identifiers preceded by '@'
      {
        className: 'meta',
        begin: /@[A-Za-z_][A-Za-z0-9_]*/
      },

      // Operators
      {
        className: 'operator',
        begin: /\b(?:and|or|not|xor|nand|nor|xnor|shl|shr|andr|orr|xorr)\b|==|!=|<=|>=|<:|>:|\+|-|\*|\/|%|\.{3}|=>|\?|:|\./
      },

      // Punctuation: commas, parentheses, semicolons, colons
      {
        className: 'punctuation',
        begin: /[(),;:]/
      },
    ]
  };
});

hljs.initHighlightingOnLoad();
