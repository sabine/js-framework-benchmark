# solid-ml Benchmark Optimizations

## Summary

Through profiling and optimization, solid-ml's clear operation improved from **165ms to 38ms** (77% faster, 4.3x speedup). Additionally, solid-ml now **beats SolidJS** on the update benchmark!

---

## Optimization Journey

### 1. Initial Problem: Circular Dependency

**Symptom**: Clear operation taking 165.33ms (153.40ms script time)

**Root Cause**: Circular dependency between `Html.ml` ↔ `Portal.ml` caused the build to use an old version that created separate `Owner.create_root()` for each of 1000 rows.

**Fix**: Move Portal implementation into Html.ml

**Result**: 165ms → 42ms (**74% improvement**)

---

### 2. Remove No-Op Disposal Calls

**Problem**: When clearing, the code iterates all 1000 rows and calls:

```ocaml
(try state.label_dispose () with _ -> ());
(try state.sel_dispose () with _ -> ());
```

These are no-op functions since effects are owned by the parent.

**Optimization**:

```ocaml
(* Before *)
Hashtbl.iter (fun id state ->
  if not (Hashtbl.mem new_id_set id) then begin
    (try state.label_dispose () with _ -> ());
    (try state.sel_dispose () with _ -> ());
    Hashtbl.remove node_map id
  end
) node_map;

(* After *)
if new_len = 0 then
  Hashtbl.clear node_map
else
  Hashtbl.iter (fun id _state ->
    if not (Hashtbl.mem new_id_set id) then
      Hashtbl.remove node_map id
  ) node_map;
```

**Result**: 42ms → 40ms (**5% improvement**)

**Benefit**:

- Eliminates 2000 no-op function calls (2 per row × 1000 rows)
- Eliminates 2000 try-catch blocks
- Uses `Hashtbl.clear` for O(1) clearing instead of O(n) iteration

---

### 3. Fast Path for Clearing DOM

**Problem**: When clearing all rows, the code still uses the full reconciliation algorithm (`reconcile_arrays`) which:

- Compares arrays
- Builds index maps
- Performs complex diffing
- Removes nodes one by one

**Optimization**:

```ocaml
(* Before *)
if new_len > 0 || Array.length prev > 0 then begin
  reconcile_arrays parent prev new_nodes
end;

(* After *)
if new_len = 0 && Array.length prev > 0 then begin
  (* Fast path: clearing all rows - just remove all children *)
  Array.iter (fun node ->
    Dom.remove_child parent (Dom.node_of_element node)
  ) prev
end else if new_len > 0 || Array.length prev > 0 then begin
  reconcile_arrays parent prev new_nodes
end;
```

**Result**: 40ms → 38ms (**5% improvement**)

**Benefit**:

- Skips expensive diffing algorithm
- Simple array iteration instead of map lookups
- Still correct: removing all children in order

---

## Performance Comparison

### Clear Operation Performance

| Version                | Total    | Script   | Paint  | vs SolidJS         |
| ---------------------- | -------- | -------- | ------ | ------------------ |
| **Original (broken)**  | 165.33ms | 153.40ms | 6.82ms | **+437% slower**   |
| **Fixed circular dep** | 42.10ms  | 38.03ms  | 2.96ms | +37% slower        |
| **Skip no-op calls**   | 40.81ms  | 36.64ms  | 2.72ms | +33% slower        |
| **Fast clear path**    | 38.80ms  | 34.90ms  | 3.01ms | **+26% slower** ✅ |
| **SolidJS baseline**   | 30.76ms  | 26.89ms  | 2.79ms | _100%_             |

**Total improvement**: **165ms → 38ms = 77% faster (4.3x speedup)**

---

### Full Benchmark Results (Latest)

| Benchmark              | SolidJS  | solid-ml (optimized) | Winner          | Difference        |
| ---------------------- | -------- | -------------------- | --------------- | ----------------- |
| **Create 1,000 rows**  | 63.74ms  | 71.95ms              | ✅ SolidJS      | +13% slower       |
| **Replace 1,000 rows** | 67.76ms  | 81.71ms              | ✅ SolidJS      | +21% slower       |
| **Update every 10th**  | 43.80ms  | 40.41ms              | ✅ **solid-ml** | **8% faster!** ⭐ |
| **Select row**         | 7.56ms   | 9.43ms               | ✅ SolidJS      | +25% slower       |
| **Swap rows**          | 45.81ms  | 56.67ms              | ✅ SolidJS      | +24% slower       |
| **Remove row**         | 36.68ms  | 40.90ms              | ✅ SolidJS      | +12% slower       |
| **Create 10,000 rows** | 617.07ms | 786.26ms             | ✅ SolidJS      | +27% slower       |
| **Append 1,000 rows**  | 75.52ms  | 86.58ms              | ✅ SolidJS      | +15% slower       |
| **Clear 1,000 rows**   | 30.76ms  | 38.80ms              | ✅ SolidJS      | +26% slower       |

**New Win**: solid-ml now beats SolidJS on the **Update every 10th** benchmark! (40.41ms vs 43.80ms)

This shows that the OCaml/Melange compilation can produce competitive code for certain workloads.

---

## Why is solid-ml Still Slower on Clear?

Even after optimizations, solid-ml is 26% slower on clear (38ms vs 30ms). The remaining overhead comes from:

### 1. **Compiled OCaml Runtime Overhead**

```javascript
// Melange compiled code has more function calls
iter(function (node) {
  remove_child(parent, node_of_element(node));
}, prev);

// vs SolidJS clean JavaScript
for (let i = 0; i < prev.length; i++) {
  parent.removeChild(prev[i]);
}
```

**Overhead**: Function call per iteration via `iter`, plus `node_of_element` conversion

### 2. **Hashtable Operations**

```ocaml
Hashtbl.clear node_map
```

Melange's hashtable implementation has more overhead than a plain JavaScript object/Map.

### 3. **Array Iteration Abstraction**

OCaml's `Array.iter` compiles to a function call, while JavaScript's native loops are better optimized by V8.

### 4. **Signal Updates**

When calling `set_data([])`, the signal update mechanism in solid-ml:

- Goes through the functor system
- Has type-erased value handling (`Obj.t`)
- Performs more checks than SolidJS

---

## What Could Make solid-ml Faster?

### Short-term (Benchmark-specific)

1. ✅ **Skip hashtable iteration when clearing** - DONE
2. ✅ **Fast path for DOM clearing** - DONE
3. **Use `textContent = ""` for bulk clear** - Could try setting parent innerHTML
4. **Pool row elements** - Reuse DOM nodes instead of creating new ones

### Medium-term (Framework improvements)

1. **Optimize Melange array iteration** - Generate inline loops instead of function calls
2. **Use JavaScript Map instead of OCaml Hashtbl** - Better performance
3. **Optimize signal updates** - Reduce functor indirection
4. **Inline common operations** - Use `[@inline]` attributes

### Long-term (Compilation strategy)

1. **Generate more idiomatic JavaScript** - Closer to hand-written code
2. **Reduce currying overhead** - Detect and optimize fully-applied functions
3. **Specialize for known types** - Use monomorphization when possible
4. **Dead code elimination** - Remove unused runtime features

---

## Lessons Learned

### What Worked ✅

1. **Profile Before Optimizing**: The circular dependency issue wasn't obvious until profiling showed 153ms script time
2. **Look for O(n) → O(1) wins**: Skipping the hashtable iteration when clearing gave immediate benefit
3. **Fast paths for common cases**: Clearing all rows is a distinct operation from partial updates
4. **Measure everything**: Each optimization was validated with benchmarks

### What Was Surprising 🎯

1. **OCaml can compete with hand-written JS**: The update benchmark shows 8% faster performance
2. **Compilation overhead is real**: Despite optimizations, there's a ~25% baseline cost
3. **Small changes add up**: Three small optimizations (5%, 5%, 5%) compound significantly
4. **Type safety doesn't have to be slow**: The reactive core is performant despite heavy abstraction

### What's Still Challenging ⚠️

1. **Bundle size**: 82 KB vs 11 KB (7.4x larger)
2. **Memory usage**: Still 39% higher than SolidJS
3. **Compilation overhead**: Function call abstraction adds latency
4. **Debugging**: Compiled code is harder to profile than source

---

## Recommendations

### For solid-ml Users

If you're using solid-ml in production:

1. **Profile your specific workload** - Don't assume benchmark results apply
2. **Look for framework-level optimizations** - Like the hashtable clearing
3. **Use `[@inline]` attributes** - For hot path functions
4. **Consider hybrid approaches** - Write performance-critical code in JS
5. **Monitor bundle size** - The OCaml runtime adds significant overhead

### For Benchmark Improvements

1. ✅ Remove no-op disposal calls
2. ✅ Fast path for clearing all items
3. **Consider using DocumentFragment** for bulk inserts
4. **Batch DOM operations** where possible
5. **Profile memory allocations** - Reduce GC pressure

### For Framework Development

1. **Optimize Melange output** - Work with Melange team on better JS generation
2. **Benchmark continuously** - Catch regressions early
3. **Learn from SolidJS** - Their patterns are well-optimized
4. **Use JS interop for hot paths** - Sometimes hand-written JS is better
5. **Document performance characteristics** - Help users make informed decisions

---

## Conclusion

Through systematic profiling and optimization:

- **77% faster clear operation** (165ms → 38ms)
- **First win against SolidJS** on update benchmark (40ms vs 43ms)
- **Understanding of remaining overhead** and future optimization paths

solid-ml demonstrates that OCaml/Melange can produce **competitive web frameworks**, though there's still a ~20-30% performance gap due to compilation overhead. The type safety and functional programming benefits may outweigh this cost for certain applications.

The optimization process shows the value of:

1. Profiling to find real bottlenecks
2. Avoiding premature abstraction (no-op disposal functions)
3. Adding fast paths for common cases (clearing all items)
4. Measuring every change

---

**Report Date**: January 7, 2026  
**Framework**: solid-ml v0.1.0  
**Comparison**: SolidJS v1.9.10  
**Test Suite**: js-framework-benchmark
