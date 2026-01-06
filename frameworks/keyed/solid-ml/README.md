# solid-ml Benchmark Implementation

This is the [js-framework-benchmark](https://github.com/krausest/js-framework-benchmark) implementation for [solid-ml](https://github.com/makerprism/solid-ml), an OCaml reactive web framework inspired by SolidJS.

## Building

solid-ml uses OCaml/Melange and requires a separate build process:

```bash
# In the solid-ml repository
cd /path/to/solid-ml
esy build

# Bundle the output
esbuild _esy/default/store/b/solid_ml-*/default/examples/js_framework_benchmark/output/examples/js_framework_benchmark/main.js \
  --bundle --minify \
  --outfile=/path/to/js-framework-benchmark/frameworks/keyed/solid-ml/dist/main.js
```

The `dist/main.js` file is pre-built and committed to this repository for convenience.

## Implementation Notes

- Uses vanilla DOM operations (no virtual DOM)
- Implements keyed updates with row template cloning for performance
- Event delegation for button and row click handlers
- Mutable data arrays for O(1) updates
