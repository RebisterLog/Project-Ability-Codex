# Templates and generators

## Starter templates

`tools/templates/` contains `Service.luau.tmpl`, `Component.luau.tmpl`, `Spec.luau.tmpl` and `Hook.luau.tmpl`. Copy one, replace every `{{...}}` placeholder, then follow the matching how-to note. Templates are starting points, not finished implementations.

## Available scripts

| Script | Purpose |
|---|---|
| `tools/context.luau` | Repository/session snapshot; `--json` for machine-readable output. |
| `tools/format.luau` | Check or fix formatting; `--fix`, `--src`, `--exclude`. |
| `tools/impact.luau` | Find dependents of a file path or identifier; `--json`. |
| `tools/Toolchain.luau` | Shared helpers: root discovery, binary lookup, vendored set, source walking. |

There are no verification or documentation-generation scripts in the current tooling. Commands that used to exist for those purposes have been removed; do not reference them.

## When to use which

- Learning an unfamiliar working copy: `tools/context.luau`.
- Before editing a widely used module: `tools/impact.luau <path-or-identifier>`.
- Before committing: `tools/format.luau --fix --src`.
- Creating a new module: copy the matching template from `tools/templates/`.

The [[Types index]] and [[Source index]] are maintained by hand in this vault.

Related: [[Formatting and inspection]], [[Source index]], [[Create a service or component]].
