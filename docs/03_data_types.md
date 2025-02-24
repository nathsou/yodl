# Data Types

## Integer types

Yodl supports two integer types which require a width specifier.

### Unsigned Integers

```yodl
// a 16-bit unsigned integer
let a: uint<16>;
a = 16'd1721;
```

### Signed Integers

```yodl
// a 7-bit signed ingeger
let b: sint<7> = -6'd8;
let c: sint<32> = sint(32'd11);
```
