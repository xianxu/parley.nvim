# Lessons

## 2026-03-07
- Avoid escaped-quote initialization inside Makefile shell recipes (e.g. `all_tests=\"\"`), which can become a literal token (`""`) and be treated as a filename.
- Prefer newline-producing helper commands plus plain `for` iteration over manually concatenating quoted strings in Make recipes.
- Always run the new Make target against at least one changed input path to catch recipe-level quoting bugs early.
