---
id: 000044
status: done
deps: []
created: 2026-03-31
updated: 2026-04-03
---

# float finder, up/down arrow navigation should wrap around at boundary

Pressing Up at the first item or Down at the last item does nothing. Should wrap around.

## Resolution

Changed `move_selection()` in `float_picker.lua` from clamping (`math.max`/`math.min`) to modular arithmetic so navigation wraps from last→first and first→last. Works for both `top` and `bottom` anchor modes.

## Done when

- [x] Down at last item wraps to first
- [x] Up at first item wraps to last
- [x] All existing tests pass
