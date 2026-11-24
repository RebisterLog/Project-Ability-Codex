# Combat pipeline

The end-to-end path of a single attack. Every step after the packet is server-side.

```
client input
  -> packet StartSkill(skillId)
  -> SkillService: validate (cooldown, stun, ragdoll, alive, ownership)
  -> spec:ActivateSkill(skillId)
  -> Skill:Activate()
       -> Sequence:Play() / promise-based flow
       -> frame callbacks: parameters, animation, sound, hitbox
       -> CombatService:Hitbox() -> candidate targets
       -> CombatService:Attack({ Attacker, Victim, Info })
            -> read target states (block, perfect block, armor, IFrames)
            -> AttackHook: Precast -> Cast -> Postcast
            -> Attacked signal
            -> result promise resolves with AttackData
  -> VFX replicated to selected players
  -> Proxy state replicated; client updates UI/VFX
```

## Key properties

- Server authority: damage and state never come from the client. See [[Runtime boundaries]].
- Frame-based timing: hitbox checks happen on explicit frames of a [[Sequencer]] sequence.
- Interruption: stun, ragdoll or death can interrupt a skill; `Interrupt` must stop sequences and effects.
- Everything is observable through signals: `Casted` (hitbox), `Attacked` (attack), `Interrupted`.

## Reading order

[[Skill contract and lifecycle]] → [[Sequencer]] → [[Hitbox and targeting]] → [[AttackInfo and AttackData]] → [[Attack hooks]] → [[VFX replication]].

## Related

[[Character parameters]], [[Knockback and movement]], [[Bot combat AI]], [[Input and BindService]].
