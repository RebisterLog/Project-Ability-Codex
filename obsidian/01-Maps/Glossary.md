# Glossary

| Term | Meaning |
|---|---|
| **Rojo** | Tool that maps `src/` into Roblox containers. See [[Repository and Rojo layout]]. |
| **Crane** | In-project framework providing services, components, signals, packets and cleanup. |
| **Service** | Singleton module with `onInit` / `onStart` lifecycle, obtained with `Crane:GetService`. |
| **Component** | Instance-bound module; holds `self.instance`, obtained with `Crane:GetComponent`. |
| **Signal** | Crane event primitive (`Signal()`), used for `Casted`, `Attacked`, `Interrupted`. |
| **Packet** | Typed network event/function wrapper (`Crane:GetPacket`). |
| **Proxy** | Reactive state tree with `Patch` and `Subscribe`, replicated to clients. See [[Data schemas and Proxy]]. |
| **Janitor / Buttler** | Cleanup containers; track connections and spawned instances. |
| **Spec** | A character loadout: skills, binds, skin assets and init logic. See [[Spec and SubSpec]]. |
| **SubSpec** | Secondary spec slot layered onto the main spec. |
| **Skin** | Per-spec asset set under `src/shared/configs/Skins/`. |
| **Skill** | Atomic combat action module under `src/server/skills/`. See [[Skill contract and lifecycle]]. |
| **SkillCharacters** | Freeform tag list describing a skill's combat role. |
| **Sequencer** | Frame-based animation driver used by most skills. See [[Sequencer]]. |
| **Frame** | Integer tick in a sequence; hitbox checks happen on chosen frames. |
| **AttackHook** | Phase pipeline (`Precast`, `Cast`, `Postcast`) that processes every attack. See [[Attack hooks]]. |
| **AttackInfo** | Description of an attack: damage, block, stun, knockback, ragdoll, angular. |
| **AttackData** | Result of an attack, including the `State` flag table. |
| **Parameter** | Layered temporary character modifier (`AddParameter` / `GetParameter`). |
| **Hitbox** | Server-side spatial query that returns candidate targets. |
| **Bind** | Key or mouse button mapped to a skill in `src/shared/configs/Specs.luau`. |
| **VFX** | Visual/sound effects started by `VFXService` and replicated to selected players. |
| **Bridge** | Studio-only runtime control surface; never available in a published game. |
| **Pragma** | `--!strict`, `--!native`, `--!optimize 2` at the top of a module. |
