# Fixture: basic input for /validate-html (synthetic)

Synthetic input for the validate-html skill. The skill checks a rendered HTML page (or static file) for common UX/a11y/structural defects (missing alt, broken links, low contrast, console errors).

## Synthetic input artifact

Target: `dist/index.html` rendered locally; or live URL `http://localhost:5173`.

Expected probes: a11y (axe-core or equivalent), broken-link, console-error capture, viewport sizing.

## Skill invocation

```
/validate-html
```

## Notes

This fixture exercises the smart-default flow (load → probe → categorize). For mode-specific fixtures (--url, --file, --council), add additional fixtures.
