# Create a subspec

A subspec is a secondary spec slot layered on the main spec. It reuses the same machinery as [[Create a spec]] but lives in the `SubSpec` slot.

## Checklist

1. Create `src/server/specs/<Name>.luau` with the same `Skills` / `onInit` shape as a main spec.
2. Create a skin under `src/shared/configs/Skins/<Name>/` (at least `None`).
3. Add an entry to `src/shared/configs/Specs.luau`; make sure the slot is `SubSpec` where the init options are supplied.
4. Add binds. Colliding binds are resolved by slot: `Spec` wins over `SubSpec`, then ids are sorted alphabetically, and the first castable skill receives the key. See [[Input and BindService]].
5. Add assets under `ReplicatedStorage.assets.<Name>.<Skin>`.

## Overlay rules

- Only override the skills that actually differ. Shared skills stay as `~/skills/...`.
- A subspec skill with the same id as a spec skill competes for the same bind; the spec slot has priority.
- Asset resolution falls back through the base spec and the `None` skin, so missing optional entries fall back rather than crash. Use `GetAsset` / `TryGetAsset` consistently.

## Verification

- Equip both slots and confirm bind priority matches the table above.
- Confirm `onInit` of both specs runs and models are welded only once.
- Run `lune run tools/format.luau --fix --src`.

Related: [[Spec and SubSpec]], [[Create a spec]], [[Skill contract and lifecycle]].
