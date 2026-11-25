# Конвейер боя

Полный путь одной атаки. все шаги после пакета выполняются на сервере.

```
ввод клиента
  -> пакет StartSkill({ Id, AimPoint? })
  -> SkillService: проверка (кулдаун, стан, рэгдолл, жизнь, права)
  -> spec:ActivateSkill(skillId, aimPoint)
  -> Skill:Activate(aimPoint)
       -> Sequence:Play() / promise-поток
       -> кадры: параметры, анимация, звук, хитбокс
       -> CombatService:Hitbox() -> кандидаты
       -> CombatService:Attack({ Attacker, Victim, Info })
            -> чтение состояния цели (блок, идеальный блок, броня, IFrames)
            -> AttackHook: Precast -> Cast -> Postcast
            -> сигнал Attacked
            -> promise результата с AttackData
  -> VFX реплицируются выбранным игрокам
  -> состояние Proxy реплицируется; клиент обновляет UI/VFX
```

## Ключевые свойства

- Авторитет сервера: урон и состояние никогда не приходят от клиента. См. [[Runtime boundaries (RU)]].
- Покадровый тайминг: проверки хитбокса выполняются на явных кадрах секвенса [[Sequencer (RU)]].
- Прерывание: стан, рэгдолл или смерть могут прервать скилл; `Interrupt` должен остановить секвенсы и эффекты.
- Всё наблюдаемо через сигналы: `Casted` (хитбокс), `Attacked` (атака), `Interrupted`.
- Необязательный вход хитбокса: троттленный поток поз клиента питает компенсацию начала `CombatService:Hitbox`; сервер проверяет данные перед использованием. См. [[Lag compensation (RU)]].

## Порядок чтения

[[Skill contract and lifecycle (RU)]] → [[Sequencer (RU)]] → [[Hitbox and targeting (RU)]] → [[AttackInfo and AttackData (RU)]] → [[Attack hooks (RU)]] → [[VFX replication (RU)]].

Связанные: [[Character parameters (RU)]], [[Knockback and movement (RU)]], [[Bot combat AI (RU)]], [[Input and BindService (RU)]]. Оригинал: [[Combat pipeline]].
