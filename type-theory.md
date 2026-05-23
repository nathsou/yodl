# Type Theory for Yodl

This document explains, from first principles, what kind of type theory best fits Yodl, why that theory matches the language better than the main alternatives, and how to implement it cleanly in the current compiler.

The short version is:

> **Yodl should be based on a phase-separated, bidirectional indexed type theory.**

In practical terms, that means:

- a **small compile-time language** for sizes, lengths, and static parameters,
- a **runtime circuit language** for signals and hardware expressions,
- **types indexed by compile-time values** such as widths and lengths,
- **monomorphization as specialization plus erasure**,
- and **type equality by normalizing static expressions**.

This is close to the style used in **Dependent ML**, **ATS**, and other languages with lightweight dependent indexing. It is **not** full Martin-Lof type theory, and that is a good thing: Yodl needs the expressive power of indexed types, not the full complexity of arbitrary dependency between runtime terms and types.

---

## 1. What a type theory does

A type theory gives a precise account of:

1. **What kinds of expressions exist**
2. **What kinds of types exist**
3. **How expressions are assigned types**
4. **When two types count as equal**

For a language like Yodl, the type theory is not just a mathematical gloss. It directly shapes:

- the AST,
- the parser,
- the resolver,
- the constant evaluator,
- the type checker,
- the monomorphizer,
- and the lowering pipeline.

So the question is not "what is the strongest possible type theory?" but rather:

> **What is the smallest, cleanest formal core that naturally explains Yodl's real features?**

---

## 2. The main families of type systems

Before discussing Yodl specifically, it helps to separate a few common approaches.

### 2.1 Simple types

The simplest typed languages have types like:

- `bool`
- `int`
- pairs
- functions

and rules like:

- if `a : int` and `b : int`, then `a + b : int`
- if `x : A` and `y : B`, then `(x, y) : A * B`

This is too weak for Yodl, because Yodl needs to express information like:

- integer width,
- vector length,
- memory depth,
- port shapes,
- and type families such as `MemoryMask<T>`.

### 2.2 Parametric polymorphism

Parametric polymorphism introduces type variables:

```text
id : forall T. T -> T
```

This is useful for `Reg<T>` and `Memory<T, ...>`, but by itself it does not explain:

- `uint<N>`
- `bool[N]`
- `uint<clog2!(Depth)>`

Those require types to depend on **compile-time data**, not just other types.

### 2.3 Dependent types

In a fully dependent type theory, types can depend on ordinary terms:

```text
Vec(A, n)
```

where `n` is itself a term.

This is very expressive, but it comes with major implementation costs:

- normalization of general terms,
- termination concerns,
- universe machinery,
- harder equality checking,
- heavier error reporting,
- and pressure to support proofs or theorem-like reasoning.

Yodl does not need that much power.

### 2.4 Indexed type systems

Indexed type systems occupy the middle ground.

They allow types to depend on a **restricted static language**, usually a small first-order language of:

- naturals,
- booleans,
- type parameters,
- and total compile-time functions.

This is exactly the shape Yodl wants.

Examples:

- `UInt(N)`
- `SInt(N)`
- `Vec(T, N)`
- `Mask(T)`

The index expressions are not arbitrary runtime terms. They belong to a separate compile-time world.

That gives most of the practical benefits of dependent types without most of the complexity.

---

## 3. What Yodl actually needs

Yodl's interesting typing problems are not about higher-rank polymorphism, effects, or theorem proving. They are mainly about **shape**.

Examples already present in the language and repository:

- `uint<N>`
- `sint<N>`
- `T[Len]`
- `uint<clog2!(Depth)>`
- `Char[cdiv!(Bits, 4)]`
- `Reg<T>`
- `Memory<T, Depth, ReadPorts, WritePorts, ...>`
- `MemoryMask<T>`
- compile-time `for` loops
- monomorphized parameterized modules

These are all naturally described as:

> **runtime terms with types indexed by compile-time information**

That means Yodl needs:

1. **Type parameters**, such as `T: type`
2. **Natural-number parameters**, such as `N: uint`
3. **Compile-time arithmetic**, such as `clog2`, `cdiv`, `N + 1`
4. **Normalization of static expressions**
5. **Erasure/monomorphization of static arguments before or during lowering**

Yodl does **not** need:

- arbitrary term-level dependency in types,
- proof objects,
- higher-kinded polymorphism,
- or a general theorem prover in the type checker.

---

## 4. The recommended theory

The best fit is:

## **Phase-separated, bidirectional indexed type theory**

This name matters because each part captures something important.

### 4.1 Phase-separated

There are two distinct worlds:

#### Static world

This is the compile-time world:

- widths,
- lengths,
- type parameters,
- module parameters,
- compile-time constants,
- and static functions like `clog2`.

Call its context `Δ`.

#### Dynamic world

This is the runtime circuit-expression world:

- identifiers,
- arithmetic on signals,
- muxes,
- instances,
- indexing,
- field access,
- assignments,
- and expressions that lower to FIRRTL/RTLIL.

Call its context `Γ`.

The critical design rule is:

> **Dynamic terms do not appear inside types.**

Types may depend on static expressions, but not on arbitrary runtime expressions.

This rule is the main source of simplicity.

### 4.2 Indexed

Types can be indexed by compile-time data:

- `UInt(n)`
- `SInt(n)`
- `Vec(A, n)`
- `Mask(A)`

Those indices live in the static language.

### 4.3 Bidirectional

The type checker should support two complementary judgments:

- **synthesis**: infer the type of an expression
- **checking**: verify that an expression matches an expected type

This is especially useful for Yodl because expected types matter in many places:

- unsized integer literals,
- vectors,
- structs,
- assignments,
- branches,
- port connections,
- and instance construction.

Pure global inference is not the right tool here. Local bidirectional checking is simpler and gives better errors.

---

## 5. The core formal structure

## 5.1 Static sorts

At minimum, Yodl needs the following static sorts:

```text
s ::= Nat | Type
```

Optional future extensions could add:

```text
Str
Bool
```

but `Nat` and `Type` are enough for the current language.

### Meaning

- `Nat` classifies compile-time natural-number expressions
- `Type` classifies runtime types

Examples:

- `N : Nat`
- `Depth : Nat`
- `T : Type`

This is cleaner than encoding natural-number parameters as if they had a runtime type like `uint`.

Surface syntax can still use:

```yodl
N: uint
T: type
```

but internally that should elaborate to:

```text
N : Nat
T : Type
```

---

## 5.2 Static index language

Instead of representing widths and lengths with ordinary runtime expressions, Yodl should have a dedicated AST for static index expressions.

For example:

```text
i, j ::= n
      | x
      | i + j
      | i - j
      | i * j
      | clog2(i)
      | cdiv(i, j)
      | ...
```

This is the single most important structural improvement to the current implementation.

### Why this helps

At the moment, the type layer uses general expressions for some static quantities. That forces later passes to keep asking:

- Is this expression actually compile-time?
- Can it be partially evaluated?
- Did substitution make it concrete?
- Is it safe to lower yet?

A dedicated `IndexExpr` answers those questions structurally. If something is in an index position, it is already in the compile-time language.

### Suggested builtins for the index language

- `+`
- `-`
- `*`
- `clog2`
- `cdiv`
- maybe `pow`

Every static builtin should be:

- total,
- deterministic,
- side-effect free,
- and easy to normalize.

---

## 5.3 Runtime type language

The runtime type language should look roughly like this:

```text
A, B ::= UInt(i)
      | SInt(i)
      | Clock
      | Vec(A, i)
      | Struct{ l1 : A1, ..., ln : An }
      | Inst(M, σ, ρ)
      | String(i)
```

where:

- `i` is a static index expression,
- `σ` is a list or map of static arguments,
- `ρ` optionally represents instance-port usage information.

Notes for Yodl:

- `bool` is sugar for `UInt(1)`
- tuples can remain sugar for structs with numeric field labels
- strings can remain sugar for `Vec(UInt(8), n)`

That already matches current Yodl fairly closely.

---

## 5.4 Static parameters and arguments

Module and type parameters should be explicitly sorted.

### Parameters

```text
p ::= x : Nat
    | X : Type
```

### Arguments

```text
a ::= NatArg(i)
    | TypeArg(A)
```

Examples:

- `Adder<32>` gives `NatArg(32)`
- `Reg<uint<32>>` gives `TypeArg(UInt(32))`

This is cleaner than the current combination of:

- unresolved vs resolved parameters,
- const-vs-type distinctions,
- and `ModuleParameterAnnotation::Type(Type)` vs `AnyType`.

The theory only needs two classes of static arguments:

- natural indices
- types

That is enough for the current design.

---

## 6. Judgments

The type theory naturally splits into three main judgments.

## 6.1 Static well-formedness

These judgments ensure that static expressions and types make sense:

```text
Δ ⊢ i : Nat
Δ ⊢ A : Type
```

Examples:

```text
N : Nat ∈ Δ
-----------
Δ ⊢ N : Nat
```

```text
Δ ⊢ T : Type    Δ ⊢ N : Nat
----------------------------
Δ ⊢ Vec(T, N) : Type
```

```text
Δ ⊢ Depth : Nat
-----------------------
Δ ⊢ clog2(Depth) : Nat
```

These checks should happen early, before the runtime term checker.

---

## 6.2 Runtime term typing

Use bidirectional judgments:

```text
Δ ; Γ ⊢ e ⇒ A
Δ ; Γ ⊢ e ⇐ A
```

Read them as:

- `e ⇒ A`: expression `e` synthesizes type `A`
- `e ⇐ A`: expression `e` checks against type `A`

This is especially valuable for literals and aggregates.

Examples:

- identifiers synthesize
- field accesses synthesize
- indexing synthesizes
- vector literals are usually checked
- struct literals are usually checked
- RHS of assignments is checked against the LHS type

---

## 6.3 Definitional equality

Type equality should be based on structural equality after normalizing static expressions:

```text
Δ ⊢ A ≡ B
```

Examples:

```text
UInt(clog2(8)) ≡ UInt(3)
Vec(UInt(8), cdiv(Bits, 4)) ≡ Vec(UInt(8), Len)
```

if `Len` normalizes to `cdiv(Bits, 4)` or vice versa.

The important point is that equality is determined by:

1. expanding relevant type aliases,
2. substituting static arguments,
3. normalizing static expressions,
4. and then comparing structurally.

This is much simpler than trying to unify arbitrary general expressions stored inside types.

---

## 7. Why Yodl should not use full dependent types

It is tempting to say "Yodl has types depending on values, so use dependent type theory." That is true in a loose sense, but misleading as an implementation strategy.

The real issue is that Yodl's types depend on **static indices**, not on ordinary runtime terms.

The full dependent approach would allow types to mention arbitrary expressions from the runtime language. That would complicate:

- equality checking,
- elaboration order,
- constant folding,
- error reporting,
- and lowering invariants.

Yodl does not benefit enough from that extra power.

What Yodl needs is:

> **dependency on a restricted static language**

That is precisely what indexed type theory provides.

---

## 8. Concrete applications to Yodl

This section maps the theory directly onto Yodl constructs.

## 8.1 Unsigned and signed integers

Yodl:

```yodl
uint<8>
sint<N>
```

Theory:

```text
UInt(8)
SInt(N)
```

where `8` and `N` are static index expressions.

Typing rule:

```text
Δ ⊢ i : Nat
------------
Δ ⊢ UInt(i) : Type
```

and similarly for `SInt`.

---

## 8.2 Booleans

Yodl:

```yodl
bool
```

Theory:

```text
UInt(1)
```

No new core constructor is needed.

---

## 8.3 Vectors

Yodl:

```yodl
bool[8]
uint<16>[4]
T[N]
```

Theory:

```text
Vec(UInt(1), 8)
Vec(UInt(16), 4)
Vec(T, N)
```

This is one of the strongest arguments for indexed types: vector length belongs naturally in the type.

---

## 8.4 Strings

Yodl currently treats strings as fixed-length vectors of ASCII bytes.

Theory options:

1. Keep `String(n)` as a surface/runtime type constructor
2. Elaborate it away immediately to `Vec(UInt(8), n)`

The second option is simpler as a core language design.

---

## 8.5 Structs and tuples

Yodl is already essentially structural for ordinary aggregates.

Theory:

```text
Struct{ a : UInt(16), b : UInt(1) }
```

Tuples can remain sugar:

```text
(A, B, C)  ≡  Struct{ "0" : A, "1" : B, "2" : C }
```

This matches the current implementation approach well.

---

## 8.6 Type aliases

Yodl surface syntax:

```yodl
type Triplet<T> = (T, T, T)
```

In the theory, a type alias is not a primitive type former. It is:

- a surface declaration,
- checked in the static/type layer,
- then expanded during elaboration.

One important cleanup is that alias parameters should be internally sorted:

```text
Triplet<T : Type>
```

and not just recorded as raw names.

Aliases with natural parameters should also be first-class:

```yodl
type Word<N: uint> = uint<N>
```

Even if the old syntax is preserved as sugar, the elaborated representation should know the sort of each alias parameter.

---

## 8.7 Parameterized modules

Yodl:

```yodl
module Adder<N: uint>(
    a: uint<N>,
    b: uint<N>,
    carry_in: bool,
) -> (
    sum: uint<N>,
    carry_out: bool,
) { ... }
```

Theory:

- static context: `Δ = N : Nat`
- runtime context: `Γ = a : UInt(N), b : UInt(N), carry_in : UInt(1)`

The module is a first-order functor from static arguments to a runtime signature/body.

This is not higher-order module theory. It is just:

> a parameterized generator whose static arguments are resolved before lowering.

That fits monomorphization perfectly.

---

## 8.8 `Reg<T>`

Builtin declaration in Yodl:

```yodl
declare module Reg<T: type>(...)
```

Theory:

- `T : Type`
- `Reg` is parameterized by a type

Instantiation:

```yodl
Reg<uint<32>>(clk)
```

becomes a static application with:

```text
T := UInt(32)
```

This is simple first-order polymorphism over types.

---

## 8.9 `Memory<T, Depth, ...>`

Builtin declaration:

```yodl
declare module Memory<
  T: type,
  Depth: uint,
  ReadPorts: uint,
  WritePorts: uint,
  ReadLatency: uint,
  WriteLatency: uint,
>(...)
```

This is a textbook fit for sorted static parameters:

- `T : Type`
- `Depth : Nat`
- `ReadPorts : Nat`
- `WritePorts : Nat`
- `ReadLatency : Nat`
- `WriteLatency : Nat`

Port types can then depend on those parameters:

```text
addr : UInt(clog2(Depth))
q    : Vec(T, ReadPorts)
```

This is exactly the kind of dependency indexed type theory was designed to express.

---

## 8.10 `MemoryMask<T>`

This is best understood as a closed type-level function:

```text
Mask(UInt(n))           = UInt(1)
Mask(SInt(n))           = UInt(1)
Mask(Vec(A, n))         = Vec(Mask(A), n)
Mask(Struct{l:A,...})   = Struct{l:Mask(A), ...}
```

This is dependent-like behavior, but it is still small and decidable because it is defined by structural recursion over types.

It should remain part of the static elaboration layer, not the runtime checker.

---

## 8.11 Compile-time loops

Yodl's `for` loops are elaborative: they are unrolled at compile time.

That means the loop bounds belong to the static language.

Example:

```yodl
for i in 0..<Bits {
    ...
}
```

Theory:

- `Bits : Nat` in the static context
- loop elaboration duplicates the body for each static index

The loop variable itself is therefore a static natural, not a runtime signal.

This is another strong sign that Yodl wants a two-level system.

---

## 8.12 Concrete repository examples

The examples in the repository already line up with this theory:

- `Adder<N: uint>` in the docs and examples
- `Hex<Bits: uint>` returning `Char[cdiv!(Bits, 4)]`
- `Grid<Rows: uint, Cols: uint>` in `examples/Life.yodl`
- `Memory<T, Depth, ...>` in builtin declarations

All of these are easiest to explain as:

- static natural parameters,
- runtime circuit terms,
- indexed types connecting the two.

---

## 9. Why bidirectional typing is the right checking discipline

Bidirectional typing is not just a formal nicety. It directly improves implementation.

## 9.1 Synthesis is good for obvious cases

Examples:

- identifiers,
- field access,
- indexing,
- instance creation,
- arithmetic on typed operands.

These naturally produce a type.

## 9.2 Checking is good when the expected type matters

Examples:

- unsized integer literals,
- vector literals,
- struct literals,
- branch results,
- assignments,
- port arguments.

For example, the literal `5` should often be checked against an expected type:

```text
Δ ; Γ ⊢ 5 ⇐ UInt(N)
```

and accepted if `5` fits in width `N`.

This is more direct than inventing a general-purpose runtime type constructor to represent literal flexibility everywhere.

### Note on the current `Nat(MinWidth)` approach

Yodl currently uses a `Nat(MinWidth)` runtime type for unsized naturals. That is a useful implementation trick, but conceptually it is mixing two ideas:

- static naturals used as indices
- literal fit constraints used during term typing

Those should be separated in the theory, even if the implementation keeps a transitional form for a while.

---

## 10. Equality and normalization

One of the central design choices is:

> **Type equality should depend on normalized static expressions.**

That means the compiler needs a normalizer for the static index language.

## 10.1 What normalization should do

- substitute static variables with arguments,
- evaluate closed arithmetic,
- simplify builtin static functions,
- and rebuild a canonical residual form for open terms.

Examples:

```text
clog2(8)      ↦ 3
cdiv(16, 4)   ↦ 4
(N + 1) + 2   ↦ N + 3
```

If `N` is unknown, normalization should still produce a stable form.

## 10.2 What normalization should not try to do

It should not become a full algebraic theorem prover.

For example, unless explicitly supported by rewrite rules, it does not need to prove:

```text
cdiv(N, 4) ≡ (N + 3) / 4
```

Simple canonicalization is enough for Yodl.

## 10.3 Type equality algorithm

To compare two types:

1. expand aliases if needed,
2. substitute static arguments,
3. normalize embedded index expressions,
4. compare the resulting type ASTs structurally.

This is far cleaner than comparing arbitrary expression trees embedded in types.

---

## 11. Why the current compiler already points this way

The current codebase already contains most of the structure needed for this design.

## 11.1 The pipeline is already two-level

In `src/lib/driver/driver.mbt`, the compiler does:

```text
parse
→ monomorphize
→ typecheck
→ simplify
→ lower
```

This already suggests:

- a compile-time elaboration phase,
- then runtime term typing,
- then lowering once types are stable.

That is exactly the right high-level architecture.

## 11.2 Builtins already distinguish type vs nat parameters

In `src/lib/simplify/resolve.mbt`, builtin modules include declarations such as:

```yodl
declare module Reg<T: type>(...)
declare module Memory<T: type, Depth: uint, ...>(...)
```

This is already the surface version of sorted static parameters.

## 11.3 The main problem is representation, not intent

The current implementation uses several structures that encode the right ideas indirectly:

- `IntParam::Fixed | Dynamic`
- general `Expr` values inside some type positions
- `ResolvedParam::ConstParam | TypeParam`
- `ModuleParameterAnnotation::Type(Type) | AnyType`

Those work, but they make the compiler carry compile-time and runtime concepts in the same syntax trees longer than necessary.

The recommended theory simplifies this by making the split explicit.

---

## 12. Implementation guide

This section gives a practical roadmap for adapting the current compiler.

## 12.1 Guiding invariants

The implementation should maintain these invariants:

1. **Static index syntax is distinct from runtime expression syntax**
2. **Every static parameter has an explicit sort**
3. **All type-level arithmetic is normalized before lowering**
4. **The typed runtime core contains no unresolved dynamic widths or lengths**
5. **Monomorphization only handles static arguments, never arbitrary runtime expressions**

If these invariants hold, many downstream functions get simpler automatically.

---

## 12.2 Step 1: introduce a dedicated static AST

### Files

- `src/lib/parse/ast.mbt`
- `src/lib/parse/parse.mbt`

### Add

- `IndexExpr`
- `ParamSort`
- `StaticArg`

Suggested internal shapes:

```text
enum ParamSort {
  NatSort
  TypeSort
}

enum IndexExpr {
  Lit(Int)
  Var(String)
  Add(IndexExpr, IndexExpr)
  Sub(IndexExpr, IndexExpr)
  Mul(IndexExpr, IndexExpr)
  Clog2(IndexExpr)
  CDiv(IndexExpr, IndexExpr)
}

enum StaticArg {
  NatArg(IndexExpr)
  TypeArg(Type)
}
```

### Replace

- `IntParam::Dynamic(Expr)` with `IndexExpr`
- `ModuleParameterAnnotation` with `ParamSort`
- parameter-resolution structures with `StaticArg`

### Benefit

The compiler will no longer need to repeatedly discover whether an expression inside a type is "really static."

---

## 12.3 Step 2: parse static expressions in static positions

Whenever the parser is reading:

- `uint<...>`
- `sint<...>`
- vector lengths `[...]`
- static module arguments
- type-level builtins like `clog2!(...)`

it should parse an `IndexExpr`, not a general runtime `Expr`.

That means `parse_type` and parameter parsing should branch on context:

- **type/index context** → parse static syntax
- **runtime expression context** → parse ordinary expressions

Surface syntax can stay familiar. The elaborated AST is what matters.

---

## 12.4 Step 3: make parameter sorts explicit

### Module parameters

Current surface forms:

```yodl
T: type
N: uint
```

should elaborate to:

```text
T : TypeSort
N : NatSort
```

### Type alias parameters

Current aliases are stored too loosely. They should also carry sorts internally.

For example:

```yodl
type Triplet<T> = (T, T, T)
type Word<N: uint> = uint<N>
```

should elaborate to sorted parameters, even if the surface syntax remains backward compatible.

This makes alias substitution much more reliable and self-describing.

---

## 12.5 Step 4: separate namespaces more clearly

The resolver should conceptually distinguish:

- term names,
- static natural names,
- type names and type aliases,
- module names.

The current implementation often resolves a path and then decides afterward whether it was:

- a const,
- a type alias,
- a parameter,
- or a module.

That works, but it makes elaboration logic branchy and fragile.

Even if the underlying symbol table remains shared, the elaborated entries should carry enough information to make the role explicit.

---

## 12.6 Step 5: add a static normalizer

Create a normalizer for `IndexExpr`.

It should:

- substitute static variables,
- constant-fold closed expressions,
- evaluate static builtins,
- rebuild a canonical residual form.

Examples:

```text
normalize(8) = 8
normalize(clog2(8)) = 3
normalize(cdiv(Bits, 4)) = cdiv(Bits, 4)
normalize((N + 1) + 2) = N + 3
```

The result need not always be a literal. It just needs to be stable and canonical enough for equality comparison.

---

## 12.7 Step 6: split type checking into well-formedness and term checking

### Static/type well-formedness

Before checking expressions, ensure that:

- type constructors are applied correctly,
- index expressions are well-sorted,
- type alias applications have the right sorts and arities,
- module arguments match parameter sorts.

### Runtime term typing

Then check runtime expressions under the already-validated static context.

This split reduces the amount of error recovery each phase has to do.

---

## 12.8 Step 7: use bidirectional typing in the checker

### Synthesize

Use synthesis for:

- identifiers,
- field accesses,
- indexing,
- slices,
- module instances,
- operators with determined operand types.

### Check

Use checking for:

- assignments,
- explicit type annotations,
- vector and struct literals,
- branch results,
- port bindings,
- unsized literals.

This especially helps with Yodl's aggregates and hardware-oriented literals.

---

## 12.9 Step 8: treat unsized literals separately from static naturals

Current Yodl uses `Nat(MinWidth)` during runtime term checking.

That is understandable, but conceptually it conflates:

- static naturals used in type indices
- runtime literal flexibility

The cleaner long-term design is:

- `Nat` belongs only to the static layer
- integer literals use literal-fitting rules in the term checker

For example:

```text
k ⇐ UInt(n)   if width_unsigned(k) <= normalize(n)
k ⇐ SInt(n)   if width_signed(k) <= normalize(n)
```

This produces a cleaner conceptual model and better control over error messages.

---

## 12.10 Step 9: reinterpret monomorphization as static elaboration

### Files

- `src/lib/simplify/monomorphize.mbt`

This pass should become the home of:

- static argument substitution,
- index normalization,
- type family evaluation,
- module specialization,
- and erasure of static arguments from runtime terms where appropriate.

Its job should no longer be to decide whether arbitrary runtime expressions happen to be constant enough to use as type-level data. That question should already have been resolved by the parser and static checker.

This will make monomorphization both smaller and more principled.

---

## 12.11 Step 10: keep lowering strict and simple

### Files

- `src/lib/elaborate/lower.mbt`

Lowering should assume:

- all indices are resolved,
- all needed static computations are normalized,
- all instance parameters are sorted and checked,
- no unresolved dynamic width survives in core runtime types.

Then lowering can remain largely as it is:

- translate structural types,
- lower instances,
- lower bundles and vectors,
- and reject only genuinely unsupported constructs.

The current lowerer still has to defend against unresolved dynamic integer parameters. In the cleaner architecture, that state should not survive to lowering at all.

---

## 13. A suggested internal redesign

The following representation would make the compiler substantially clearer.

## 13.1 Static parameters

```text
struct StaticParam {
  name : String
  sort : ParamSort
}
```

## 13.2 Static arguments

```text
enum StaticArg {
  NatArg(IndexExpr)
  TypeArg(Type)
}
```

## 13.3 Runtime types

```text
enum Type {
  UInt(IndexExpr)
  SInt(IndexExpr)
  Clock
  Vec(Type, IndexExpr)
  Struct(Map[String, Type])
  Instance(ModuleSignature, Map[String, StaticArg], AccessedPorts)
  String(IndexExpr)   // optional sugar only
}
```

## 13.4 Static alias definitions

```text
struct TypeAliasDecl {
  name       : String
  parameters : Array[StaticParam]
  body       : Type
}
```

This is much closer to the theory and eliminates several ambiguous states.

---

## 14. Equality, unification, and what not to overbuild

Yodl does not need heavy unification over symbolic arithmetic.

A good strategy is:

1. normalize indices,
2. compare normalized forms,
3. support only a small set of obvious literal-fit or local constraints.

In particular, avoid turning the checker into:

- an SMT front-end,
- a full arithmetic solver,
- or a proof search engine.

That would add complexity far beyond the value it brings to Yodl's current goals.

Keep the static language small and normalization-based.

---

## 15. Optional refinement: row-polymorphic instance views

This is not required, but it would make one part of Yodl more elegant.

Yodl instance types are already treated specially: only accessed ports matter in some places, tracked via `AccessedPorts`.

That can be understood as a lightweight record-row discipline.

Formally, an instance type could be modeled as:

```text
Inst(M, σ, ρ)
```

where:

- `M` is the module name/signature,
- `σ` is the static-argument substitution,
- `ρ` is a row describing the currently exposed or used ports.

This explains why instance types are not plain structs even though they behave structurally in several respects.

However, this refinement is optional. The phase-separated indexed design should come first.

---

## 16. Why this theory is simpler than the current ad hoc mix

The main simplification comes from replacing one vague question:

> "Can this expression inside a type somehow be evaluated later?"

with a much sharper one:

> "Is this an index expression or not?"

Once that distinction exists in the AST:

- parsing gets clearer,
- substitution gets simpler,
- normalization gets local,
- equality gets structural,
- monomorphization becomes principled,
- and lowering has fewer failure modes.

In other words, the elegance comes less from adding power and more from **removing ambiguity**.

---

## 17. Recommended migration plan

This is the safest order to implement the redesign.

### Phase 1: represent the theory

- add `IndexExpr`
- add `ParamSort`
- add sorted static parameters
- add `StaticArg`

### Phase 2: parse and resolve the static layer

- parse type/index positions into `IndexExpr`
- parse sorted parameters
- resolve names with explicit static roles

### Phase 3: normalize and compare

- implement index substitution
- implement normalization
- update type equality to use normalized indices

### Phase 4: refactor the checker

- split static well-formedness from runtime term typing
- move toward bidirectional checking
- isolate literal-fit behavior

### Phase 5: simplify monomorphization and lowering

- treat monomorphization as static elaboration
- ensure lowering only sees normalized core types

This path minimizes disruption while steadily moving the compiler toward a cleaner core.

---

## 18. Final recommendation

If Yodl is to remain:

- small,
- predictable,
- hardware-focused,
- monomorphizing,
- and ergonomic,

then the right theoretical foundation is:

> **a small indexed type theory with strict phase separation**

More explicitly:

- **Static layer**: naturals, type parameters, compile-time arithmetic, type families
- **Runtime layer**: circuit expressions and assignments
- **Bridge**: types indexed by static expressions
- **Checking style**: bidirectional
- **Equality**: normalize static expressions, then compare structurally
- **Compilation strategy**: elaborate and erase static structure before lowering

This gives Yodl:

- the expressive power it already wants,
- a simpler implementation model,
- cleaner invariants,
- and a theory that matches the actual compiler pipeline.

It is stronger than plain polymorphism, but much cheaper and cleaner than full dependent types.

That is the right tradeoff.
