# PAC API Types (generated)

Source: `src/server/types.luau`, `src/client/types.luau`, `src/shared/schemas/*.luau`. Regenerate: `lune run tools/gen-types-doc.luau`.

## src/server/types.luau
- export type PlayerModule = {
- export type Bind = Enum.KeyCode | Enum.UserInputType
- export type SpecSlot = "Spec" | "SubSpec"
- export type SpecInitOptions = {
- export type CleanUp = () -> ()
- export type EffectData = { [string]: any }
- export type Parameters = typeof(Parameters)
- export type ParameterName = keyof<Parameters>
- export type ParameterValue<K = ParameterName> = index<index<Parameters, K>, "Default">
- export type ParameterObject<T> = {
- export type GrabData = {
- export type HitboxData = {
- export type AttackInfo = {
- export type AttackData = {
- export type ProjectileMoveContext = {
- export type ProjectileMoveFunction = (
- export type ProjectileReflection = {
- export type ProjectileConfig = {
- export type Projectile = ProjectileProperities & ProjectileMethods
- export type Quest = QuestProperities & QuestMethods
- export type Stand = Crane.Component<Model> & StandProperities & StandMethods
- export type SkillData = {
- export type Skill = SkillProperties & SkillMethods
- export type SkillReplicationData = {
- export type SpecSaveData = PlayerSaveData.SpecData
- export type SpecDef = {
- export type SpecData = {
- export type Spec = SpecProperities & SpecMethods
- export type PlayerComponent = Crane.Component<Player> & PlayerProperties & PlayerMethods
- export type HealData = {
- export type NoDeathEntry =
- export type Character = Crane.Component<Model> & CharacterMethods & CharacterProperities

## src/client/types.luau
- export type ClientPlayerModule = {

## shared/schemas
### GameData.luau
- export type GameData = {

### PlayerData.luau
- export type PlayerData = PlayerDynamicData.PlayerDynamicData & PlayerSaveData.PlayerSaveData

### PlayerDynamicData.luau
- export type SpecSlot = "Spec" | "SubSpec"
- export type CharacterParameters = {
- export type PlayerDynamicData = {

### PlayerSaveData.luau
- export type SpecData = {
- export type PlayerSaveData = {
