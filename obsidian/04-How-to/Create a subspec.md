# Create a subspec

A subspec is a secondary spec slot layered on the main spec. It reuses the same machinery as [[Create a spec]] but lives in the `SubSpec` slot.

## Checklist

1. Create `src/server/specs/<Name>.luau` with the same `Skills` / `onInit` shape as a main spec.
2. Create a skin under `src/shared/configs/Skins/<Name>/` (at least `None`).
3. Add an entry to `src/shared/configs/Specs.luau` with `Type = "SubSpec"`. This is the **single source of truth** for slot routing — `SpecService:GetSpecType` stamps `SpecData.Slot`; there is no separate slot field in the spec module. `Character.SetSpec` then calls `created:Init({ Movement = slot == "Spec" })`, so a subspec does **not** own the body movement animations; the main spec does.
4. Add a bind for every skill — a missing bind warns and skips the skill. Colliding binds are resolved by slot: `Spec` wins over `SubSpec`, then ids are sorted alphabetically, and the first castable skill receives the key. See [[Input and BindService]].
5. Add assets under `ReplicatedStorage.assets.<Name>.<Skin>`.

## Overlay rules

- Only override the skills that actually differ. Shared skills stay as `~/skills/...`; the key must equal the module filename.
- A subspec skill with the same id as a spec skill competes for the same bind; the spec slot has priority.
- Asset resolution uses the merged skin of the equipped slot, then falls back to the skill's `BaseSpec` skin. There is no per-path `None` fallback in `GetAsset` — `None` is simply the default skin name. Use `TryGetAsset` (with an `or default`) for optional entries; a missing required `GetAsset` path warns and errors.

## Verification

- Equip both slots and confirm bind priority matches the table above, and that the subspec does not overwrite body movement animations.
- Confirm `onInit` of both specs runs and models are welded only once.
- There is no automated test runner. Format with `lune run tools/format.luau --fix --src`, then inspect with `lune run tools/context.luau` and `lune run tools/impact.luau <target>`.

Related: [[Spec and SubSpec]], [[Create a spec]], [[Skill contract and lifecycle]].
