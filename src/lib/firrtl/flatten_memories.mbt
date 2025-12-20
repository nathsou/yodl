
// See https://github.com/llvm/circt/blob/9c89d1c181e1e7bd26bb5c5567ba43806357bf6b/lib/Dialect/FIRRTL/Transforms/FlattenMemory.cpp
struct FlattenMemoriesPass {
  ref_mappings: @stack.Stack[Map[TypedRef, TypedRef]]
}

pub fn FlattenMemoriesPass::new() -> Self {
  { ref_mappings: @stack.new() }
}

impl FIRRTLRewriter for FlattenMemoriesPass

pub impl FIRRTLPass for FlattenMemoriesPass with run(self, circuit) -> TypedCircuit raise {
  self.rewrite_circuit(circuit)
}

impl FIRRTLRewriter for FlattenMemoriesPass with rewrite_module(self, mod) -> TypedModule raise {
  self.ref_mappings.push({})
  let res = rewrite_module_default_impl(self, mod)
  let _ = self.ref_mappings.unsafe_pop()
  res
}

impl FIRRTLRewriter for FlattenMemoriesPass with rewrite_ref(self, r, stmts) -> TypedRef raise {
  let ref_map = self.ref_mappings.unsafe_peek()
  
  if ref_map.get(r) is Some(r2) {
    r2
  } else {
    match r {
      FieldAccess(lhs~, field~, ty~) => {
        let new_lhs = self.rewrite_ref(lhs, stmts)
        FieldAccess(lhs=new_lhs, field~, ty~)
      }
      StaticIndexing(lhs~, index~, ty~) => {
        let new_lhs = self.rewrite_ref(lhs, stmts)
        StaticIndexing(lhs=new_lhs, index~, ty~)
      }
      DynamicIndexing(lhs~, index~, ty~) => {
        let new_lhs = self.rewrite_ref(lhs, stmts)
        let new_index = self.rewrite_expr(index, stmts~)
        DynamicIndexing(lhs=new_lhs, index=new_index, ty~)
      }
      _ => r
    }
  }
}

impl FIRRTLRewriter for FlattenMemoriesPass with rewrite_mem_stmt(self, mem, stmts~) -> Unit raise {
  if mem.data_type.is_ground() {
    stmts.push(Mem(mem))
  } else {
    let mem_bundle_type = mem.as_bundle()
    let leaf_types = mem.data_type.leaf_types()
    let mut mem_flat_width = 0
    let leaf_widths = []

    for ty in leaf_types {
      let width = ty.width()
      mem_flat_width += width
      leaf_widths.push(width)
    }

    if mem_flat_width > 0 {
      // Create the flattened memory
      // Internally, the CIRCT MLIR compiler supports granular masks but FIRRTL
      // does not, so we introduce a custom flatmem construct which cannot be expressed in FIRRTL directly.
      let mask_granularity = mem.data_type.mem_mask_granularity()

      stmts.push(Mem({
        ..mem,
        is_flat: true,
        data_type: UInt(mem_flat_width),
        mask_ty: UInt(mem_flat_width / mask_granularity),
      }))

      // Now create new ports for the flattened memory and create wires
      // to hold the original aggregate types.
      for port in mem.ports() {
        let (port_id, port_ty) = port

        for field in port_ty.bundle_fields() {
          let field_name = field.id.value()
          let is_data = field_name == "data" || field_name == "wdata" || field_name == "rdata"
          let is_mask = field_name == "mask" || field_name == "wmask"

          if is_data || is_mask {
            let mem_port_ref = FieldAccess(
              lhs=Id(mem.id, ty=mem_bundle_type),
              field=port_id,
              ty=port_ty,
            )

            let flat_ty = Type::UInt(mem_flat_width)
            let flat_field = FieldAccess(
              lhs=mem_port_ref,
              field=field.id,
              ty=flat_ty,
            )

            // create a new wire to map from original aggregate type to flattened mem port fields
            let wire_id = Id::from("\{mem.id}_\{port_id}_\{field_name}_agg$")
            stmts.push(Wire(id=wire_id, ty=field.ty))
            let ref_map = self.ref_mappings.unsafe_peek()
            // replace subsequent references to this mem port field with the wire
            ref_map[flat_field] = Id(wire_id, ty=field.ty)

            if !field.flip {
              if is_mask {
                let mask_leafs = flatten_ref(Id(wire_id, ty=field.ty))
                let leaf_types = mem.data_type.leaf_types()
                let new_mask = []

                for i in 0..<mask_leafs.length() {
                  let mask_bit = mask_leafs[i]
                  let repeat_count = leaf_types[i].width() / mask_granularity

                  for _ in 0..<repeat_count {
                    new_mask.push(mask_bit)
                  }
                }

                let expanded_mask = concat_refs(new_mask)
                stmts.push(Connect(flat_field, expanded_mask))
              } else {
                // connect from flattened memory port to wire
                stmts.push(Connect(flat_field, concat_refs(flatten_ref(Id(wire_id, ty=field.ty)))))
              }
            } else {
              // Mask expansion
                // connect from wire to flattened memory port
              for connection in build_aggregate_connections(Id(wire_id, ty=field.ty), flat_field, field.ty) {
                let (target, source) = connection
                stmts.push(Connect(target, source))
              }
            }
          }
        }
      }
    }
  }
}

fn flatten_ref(r: TypedRef) -> Array[TypedRef] {
  let leaf_refs = []

  fn aux(r: TypedRef) -> Unit {
    match r.ty() {
      Bundle(fields) => {
        for field in fields {
          aux(FieldAccess(lhs=r, field=field.id, ty=field.ty))
        }
      }
      Vec(elem_ty, size) => {
        for i in 0..<size {
          aux(StaticIndexing(lhs=r, index=i, ty=elem_ty))
        }
      }
      _ => {
        leaf_refs.push(r)
      }
    }
  }

  aux(r)

  leaf_refs
}

fn as_uint(expr: TypedExpr) -> TypedExpr {
  match expr.ty().without_const() {
    UInt(_) => expr
    SInt(_) | Clock | AsyncReset | Reset => {
      PrimOp(op=AsUInt, args=[expr], ty=Type::UInt(expr.ty().width()))
    }
    Bundle(_) | Vec(_) => @utils.fail("Cannot convert aggregate type to UInt")
    Const(_) => @utils.unreachable_code()
  }
}

fn concat_refs(refs: Array[TypedRef]) -> TypedExpr {
  let last_ref = refs[refs.length() - 1]

  refs[:refs.length() - 1].rev_fold((acc, r) =>
    PrimOp(
      op=Cat,
      args=[acc, as_uint(r.as_expr())],
      ty=UInt(acc.ty().width() + r.ty().width()),
    ),
    init=last_ref.as_expr(),
  )
}

fn build_aggregate_connections(target: TypedRef, source: TypedRef, ty: Type) -> Array[(TypedRef, TypedExpr)] {
  let connections = []

  fn aux(target: TypedRef, ty: Type, offset: Int) -> Unit {
    match ty {
      Bundle(fields) => {
        for field in fields {
          let field_access = FieldAccess(lhs=target, field=field.id, ty=field.ty)
          aux(field_access, field.ty, offset + field.ty.width())
        }
      }
      Vec(elem_ty, size) => {
        for i in 0..<size {
          aux(StaticIndexing(lhs=target, index=i, ty=elem_ty), elem_ty, offset + i * elem_ty.width())
        }
      }
      _ => {
        let width = ty.width()
        let lo_idx = TypedExpr::Literal(Literal::uint(offset), ty=Type::UInt(32))
        let hi_idx = TypedExpr::Literal(Literal::uint(offset + width - 1), ty=Type::UInt(32))
        let bits = TypedExpr::PrimOp(op=Bits, args=[source.as_expr(), hi_idx, lo_idx], ty=UInt(width))
        let bits = match ty {
          UInt(_) | Reset => bits
          SInt(_,) => PrimOp(op=AsSInt, args=[bits], ty~)
          Clock => PrimOp(op=AsClock, args=[bits], ty~)
          AsyncReset => PrimOp(op=AsAsyncReset, args=[bits], ty~)
          Bundle(_) | Vec(_) | Const(_) => @utils.unreachable_code()
        }

        connections.push((target, bits))
      }
    }
  }

  aux(target, ty, 0)

  connections
}
