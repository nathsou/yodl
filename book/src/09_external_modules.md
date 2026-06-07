# External Modules

Yodl allows you to integrate existing Verilog modules into your designs through external module declarations. This is useful for leveraging existing IP, interfacing with vendor-specific primitives, or gradually migrating from Verilog to Yodl.

## External Module Declaration

External modules are declared using the `@external` attribute followed by a module declaration:

```yodl
@external("module_name", "file.v")
@parameters({ PARAM1: 0, PARAM2: "true" })
declare module ExternalModule(
    input1: u8,
    input2: bool[4],
) -> (
    output1: bool,
    output2: u16,
)

# module Top() -> () {}
```

### Attributes

#### `@external(module_name, file_path)`

- `module_name`: The name of the Verilog module to instantiate
- `file_path`: Path to the Verilog file containing the module (relative to the generated FIRRTL output file)

#### `@parameters({ ... })` (Optional)

Parameters to pass to the Verilog module. These become `parameter` declarations in the generated Verilog.
