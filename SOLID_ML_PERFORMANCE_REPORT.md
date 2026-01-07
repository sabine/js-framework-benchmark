# Performance Comparison: SolidJS vs solid-ml

## Executive Summary

This report compares the performance of **SolidJS v1.9.10** (JavaScript) against **solid-ml v0.1.0** (OCaml/Melange), a reactive web framework inspired by SolidJS that compiles from OCaml to JavaScript.

After fixing a critical circular dependency issue in solid-ml, the clear operation improved by **73%** (165ms → 42ms). However, SolidJS still maintains an overall performance advantage.

---

## Benchmark Environment

- **Test Suite**: js-framework-benchmark
- **Runner**: Playwright (headless Chrome)
- **Mode**: Smoketest (15 CPU iterations, 1 memory iteration)
- **Operations**: Create/update/delete 1,000-10,000 table rows
- **Date**: January 2026

---

## CPU Performance Results

### Summary Table (Total Time in ms)

| Benchmark              | SolidJS | solid-ml | Winner          | Difference       |
| ---------------------- | ------- | -------- | --------------- | ---------------- |
| **Create 1,000 rows**  | 65.25   | 74.63    | ✅ SolidJS      | +14% slower      |
| **Replace 1,000 rows** | 67.32   | 75.86    | ✅ SolidJS      | +13% slower      |
| **Update every 10th**  | 45.56   | 51.50    | ✅ SolidJS      | +13% slower      |
| **Select row**         | 7.46    | 9.12     | ✅ SolidJS      | +22% slower      |
| **Swap rows**          | 54.13   | 53.24    | ✅ **solid-ml** | **2% faster** ⭐ |
| **Remove row**         | 36.03   | 35.48    | ✅ **solid-ml** | **2% faster** ⭐ |
| **Create 10,000 rows** | 647.27  | 721.29   | ✅ SolidJS      | +11% slower      |
| **Append 1,000 rows**  | 72.29   | 82.47    | ✅ SolidJS      | +14% slower      |
| **Clear 1,000 rows**   | 28.35   | 42.10    | ✅ SolidJS      | +49% slower      |

### Detailed Performance Breakdown

#### Create 1,000 Rows

- **SolidJS**: 65.25ms (script: 5.31ms, paint: 58.72ms)
- **solid-ml**: 74.63ms (script: 11.85ms, paint: 60.41ms)
- **Analysis**: solid-ml has 2.2x more script time due to compiled OCaml overhead

#### Replace All 1,000 Rows

- **SolidJS**: 67.32ms (script: 13.46ms, paint: 52.95ms)
- **solid-ml**: 75.86ms (script: 19.03ms, paint: 55.99ms)
- **Analysis**: 41% more script time for reconciliation

#### Update Every 10th Row

- **SolidJS**: 45.56ms (script: 2.20ms, paint: 40.01ms)
- **solid-ml**: 51.50ms (script: 2.91ms, paint: 45.40ms)
- **Analysis**: Granular updates show similar efficiency

#### Select Row

- **SolidJS**: 7.46ms (script: 0.99ms, paint: 5.45ms)
- **solid-ml**: 9.12ms (script: 1.22ms, paint: 6.57ms)
- **Analysis**: Both use selector optimization, minimal overhead

#### Swap Rows ⭐

- **SolidJS**: 54.13ms (script: 2.23ms, paint: 47.92ms)
- **solid-ml**: 53.24ms (script: 2.96ms, paint: 46.68ms)
- **Analysis**: **solid-ml wins!** Efficient DOM reconciliation

#### Remove Row ⭐

- **SolidJS**: 36.03ms (script: 0.81ms, paint: 33.94ms)
- **solid-ml**: 35.48ms (script: 1.86ms, paint: 31.68ms)
- **Analysis**: **solid-ml wins!** Despite higher script time, faster paint

#### Create 10,000 Rows

- **SolidJS**: 647.27ms (script: 62.99ms, paint: 575.34ms)
- **solid-ml**: 721.29ms (script: 131.59ms, paint: 580.77ms)
- **Analysis**: 2.1x more script time at scale

#### Append 1,000 Rows

- **SolidJS**: 72.29ms (script: 6.70ms, paint: 63.75ms)
- **solid-ml**: 82.47ms (script: 13.00ms, paint: 67.59ms)
- **Analysis**: 94% more script time for incremental updates

#### Clear 1,000 Rows

- **SolidJS**: 28.35ms (script: 25.22ms, paint: 1.90ms)
- **solid-ml**: 42.10ms (script: 38.03ms, paint: 3.15ms)
- **Analysis**: 51% more script time for disposal

---

## Memory Usage Results

| Benchmark                | SolidJS | solid-ml | Winner     | Difference |
| ------------------------ | ------- | -------- | ---------- | ---------- |
| **Ready memory**         | 1.00 MB | 1.25 MB  | ✅ SolidJS | +25% more  |
| **Run memory (1k rows)** | 3.28 MB | 4.55 MB  | ✅ SolidJS | +39% more  |
| **Run/Clear memory**     | 1.57 MB | 4.18 MB  | ✅ SolidJS | +166% more |

**Analysis**: solid-ml's higher memory usage is due to:

1. Larger runtime from OCaml/Melange compilation
2. Additional data structures for reactive system
3. Less efficient garbage collection patterns

---

## Bundle Size Comparison

| Metric                | SolidJS | solid-ml | Winner     | Difference      |
| --------------------- | ------- | -------- | ---------- | --------------- |
| **Uncompressed**      | 11.8 KB | 86.3 KB  | ✅ SolidJS | **631% larger** |
| **Compressed (gzip)** | 4.6 KB  | 20.7 KB  | ✅ SolidJS | **350% larger** |

**Analysis**: The significant size difference is due to:

- OCaml/Melange runtime included in bundle
- Compiled functional programming patterns (currying, closures)
- Additional abstractions from OCaml→JS compilation

---

## Critical Bug Fix: Circular Dependency

### The Problem

solid-ml originally had a circular dependency:

```
Html.ml → Portal.ml → Html.ml
```

This caused:

1. Build failures preventing compilation
2. Inefficient disposal patterns in the old compiled code
3. **165ms clear time** (153ms script time) - 4.5x slower than SolidJS

### The Solution

**Actions Taken:**

1. Moved `Portal` implementation directly into `Html.ml`
2. Fixed missing reactive module imports in `For.ml` and `Index.ml`
3. Updated Effect API usage from old `~track`/`~run` pattern to `create_deferred`
4. Fixed syntax errors in benchmark code

### Performance Impact

#### Clear Operation Performance:

- **Before Fix**: 165.33ms (script: 153.40ms, paint: 6.82ms)
- **After Fix**: 42.10ms (script: 38.03ms, paint: 3.15ms)
- **Improvement**: **73% faster** (3.9x speedup!)

The old version created separate `Owner.create_root()` for each row, causing expensive disposal of 1,000 reactive roots. The fixed version uses a shared effect system with more efficient cleanup.

---

## Competitive Analysis

### Where solid-ml Wins ⭐

1. **Swap rows**: 53.24ms vs 54.13ms (2% faster)
2. **Remove row**: 35.48ms vs 36.03ms (2% faster)

These wins demonstrate that solid-ml's reconciliation algorithm is competitive with SolidJS in specific scenarios.

### Where SolidJS Dominates

1. **Bundle size**: 4.5x smaller (critical for web applications)
2. **Memory usage**: 25-166% more efficient
3. **Script execution**: Generally 13-94% faster
4. **Overall**: Faster on 7 out of 9 CPU benchmarks

---

## Technical Deep Dive

### Why is solid-ml Slower?

1. **OCaml/Melange Compilation Overhead**

   - Curried functions add call overhead
   - Pattern matching compiles to multiple conditionals
   - Type erasure leaves runtime checks

2. **Larger Runtime**

   - Includes OCaml standard library functions
   - Melange JS runtime (arrays, hashtables, etc.)
   - Additional abstractions for functional patterns

3. **Memory Allocation Patterns**

   - Functional immutability creates more temporary objects
   - Less optimized GC patterns compared to hand-tuned JS

4. **Disposal Overhead**
   - Clear operation still 49% slower despite fixes
   - More bookkeeping for effect cleanup
   - Hashtable iteration overhead

### Why solid-ml is Competitive

1. **Efficient DOM Reconciliation**

   - Uses same udomdiff algorithm as SolidJS
   - Keyed updates with minimal DOM operations
   - Template cloning for performance

2. **Fine-Grained Reactivity**

   - Signal-based updates like SolidJS
   - Selective re-renders with createSelector
   - Batched updates to minimize work

3. **Strong Type Safety**
   - OCaml's type system catches errors at compile time
   - No runtime type errors
   - Better maintainability for large codebases

---

## Recommendations

### Use SolidJS When:

- ✅ Bundle size is critical (mobile, slow networks)
- ✅ Peak performance is required
- ✅ Memory constraints are tight
- ✅ JavaScript ecosystem integration is important

### Use solid-ml When:

- ✅ Type safety is paramount
- ✅ OCaml expertise exists on the team
- ✅ Functional programming patterns are preferred
- ✅ Willing to trade performance for correctness
- ✅ Building server-side rendered apps (OCaml on backend + Melange on frontend)

---

## Future Optimization Opportunities for solid-ml

1. **Reduce Bundle Size**

   - Tree-shake unused Melange runtime
   - Optimize compilation output
   - Use lighter-weight data structures

2. **Improve Disposal Performance**

   - Pool reactive computations instead of creating/destroying
   - Batch disposal operations
   - Optimize hashtable iterations

3. **Memory Optimization**

   - Use more efficient object representations
   - Reduce temporary allocations
   - Optimize reactive graph structure

4. **Compilation Optimizations**
   - Generate more idiomatic JavaScript
   - Reduce function call overhead
   - Inline hot paths

---

## Conclusion

**SolidJS** remains the superior choice for most web applications due to:

- 4.5x smaller bundle size
- 25-166% better memory efficiency
- 11-49% faster execution on most benchmarks
- Mature ecosystem and tooling

**solid-ml** demonstrates that OCaml/Melange can produce competitive reactive frameworks:

- Achieves 73% performance improvement after fixing architectural issues
- Wins 2 out of 9 benchmarks (swap, remove)
- Within 13-22% of SolidJS on most operations
- Provides strong type safety and functional programming benefits

The **20.7 KB vs 4.6 KB** bundle size difference is the most significant barrier to solid-ml adoption for web applications, though the type safety and maintainability benefits may outweigh this for certain use cases.

---

## Appendix: Raw Benchmark Data

### SolidJS v1.9.10-keyed

**CPU Benchmarks:**

- 01_run1k: 65.25ms (script: 5.31ms, paint: 58.72ms)
- 02_replace1k: 67.32ms (script: 13.46ms, paint: 52.95ms)
- 03_update10th1k_x16: 45.56ms (script: 2.20ms, paint: 40.01ms)
- 04_select1k: 7.46ms (script: 0.99ms, paint: 5.45ms)
- 05_swap1k: 54.13ms (script: 2.23ms, paint: 47.92ms)
- 06_remove-one-1k: 36.03ms (script: 0.81ms, paint: 33.94ms)
- 07_create10k: 647.27ms (script: 62.99ms, paint: 575.34ms)
- 08_create1k-after1k_x2: 72.29ms (script: 6.70ms, paint: 63.75ms)
- 09_clear1k_x8: 28.35ms (script: 25.22ms, paint: 1.90ms)

**Memory Benchmarks:**

- 21_ready-memory: 1.00 MB
- 22_run-memory: 3.28 MB
- 25_run-clear-memory: 1.57 MB

**Bundle Size:**

- Uncompressed: 11,762 bytes
- Compressed: 4,596 bytes

### solid-ml v0.1.0-keyed

**CPU Benchmarks:**

- 01_run1k: 74.63ms (script: 11.85ms, paint: 60.41ms)
- 02_replace1k: 75.86ms (script: 19.03ms, paint: 55.99ms)
- 03_update10th1k_x16: 51.50ms (script: 2.91ms, paint: 45.40ms)
- 04_select1k: 9.12ms (script: 1.22ms, paint: 6.57ms)
- 05_swap1k: 53.24ms (script: 2.96ms, paint: 46.68ms) ⭐ WIN
- 06_remove-one-1k: 35.48ms (script: 1.87ms, paint: 31.68ms) ⭐ WIN
- 07_create10k: 721.29ms (script: 131.59ms, paint: 580.77ms)
- 08_create1k-after1k_x2: 82.47ms (script: 13.00ms, paint: 67.59ms)
- 09_clear1k_x8: 42.10ms (script: 38.03ms, paint: 3.15ms)

**Memory Benchmarks:**

- 21_ready-memory: 1.25 MB
- 22_run-memory: 4.55 MB
- 25_run-clear-memory: 4.18 MB

**Bundle Size:**

- Uncompressed: 86,324 bytes
- Compressed: 20,707 bytes

---

**Report Generated**: January 7, 2026  
**Test Repository**: js-framework-benchmark  
**Frameworks Tested**: SolidJS v1.9.10, solid-ml v0.1.0
