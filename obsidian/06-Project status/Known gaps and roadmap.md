# Known gaps and roadmap

## Code-level gaps

- `Component:GetId()` reads a different attribute name than Crane writes. See [[Gotchas]].
- Duplicate `Character` components can appear after repeated respawns.
- Proxy has expensive pattern scans and prefix-only `AnyChange` notifications; subscribe to parents deliberately.
- Mixed CRLF/LF checkout; normalisation would need its own commit and configuration.
- Some Bridge operations have engine-side quirks; keep calls narrow.
- No automated test suite or gates remain after the tooling cleanup; rely on manual playtest plus `context`, `format` and `impact`. See [[Formatting and inspection]].

## Content gaps

- Lore is essentially empty. Only templates and code-derived name seeds exist. See [[Lore home]].
- The `Test` quest is a placeholder; no full quest chain exists yet.
- Bot AI has limited long-term memory and simple target selection.

## Suggested order of work

1. Reconcile the component-id attribute mismatch and respawn duplication.
2. Establish a lightweight verification habit around formatting and impact inspection.
3. Flesh out one spec end-to-end as a reference implementation (skills, skin, assets, binds).
4. Write lore into the templates, starting with the existing character seeds.
5. Add real quests built on the Test quest skeleton.

Related: [[Implemented systems]], [[Gotchas]], [[Lore map]].
