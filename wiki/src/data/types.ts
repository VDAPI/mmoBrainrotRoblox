// GENEROWANE przez tools/wikidump.luau — nie edytuj (zmiany: tools/WikiData/Schema i buildery).

export type Name = { pl: string; en: string };
export type Json = string | number | boolean | null | Json[] | { [key: string]: Json };

export type Category = "backpack" | "consumable" | "equipment" | "material" | "scroll" | "stone" | "tool";
export type ClassId = "Cleric" | "Hunter" | "Mage" | "Warrior";
export type ElementId = "fire" | "ice" | "lightning" | "poison";
export type RarityKey = "common" | "heroic" | "legendary" | "mythic" | "unique";
export type SlotGroup = "armor" | "backpack" | "boots" | "gloves" | "helmet" | "necklace" | "offhand" | "ring" | "talisman" | "weapon";

export interface Ability {
  angle?: number;
  cooldown: number;
  damage: number;
  damageKind?: string;
  element?: ElementId;
  id: string;
  inner?: number;
  length?: number;
  name?: Name;
  origin: string;
  radius?: number;
  shape: string;
  width?: number;
  windup: number;
}

export interface AlchemyRecipe {
  gold: number;
  group: string;
  id: string;
  ingredients: Amount[];
  level: number;
  result: Amount;
  time: number;
}

export interface Amount {
  id: string; // id in items.json
  n: number;
}

export interface AmountRange {
  chance?: number;
  id: string; // id in items.json
  max: number;
  min: number;
}

export interface Area {
  arrive?: Point;
  decor?: string;
  groups: number;
  id: string;
  kinds: string[]; // ids in monsters.json
  landmark?: Point;
  levelMax: number;
  levelMin: number;
  map: string; // id in maps.json
  monsters: number;
  name: Name;
  profile?: string;
  rect: number[];
  respawnMax: number;
  respawnMin: number;
}

export interface AreaProfileInfo {
  atkMul: number;
  color: string;
  desc: Name;
  expMul: number;
  goldMul: number;
  hpMul: number;
  icon: string;
  id: string;
  itemChanceMul: number;
  materialMul: number;
  name: Name;
  respawn: Seconds;
  sizeWeights: number[];
  topTierMul: number;
}

export interface AreasFile {
  areas: Area[];
  groups: Record<string, SpawnGroup[]>;
  maps: Record<string, MapFeatures>;
}

export interface BaseInfo {
  bonusGroup: string;
  classes?: ClassId[];
  elemental: boolean;
  glyph: string;
  name: Name;
  slot: SlotGroup;
}

export interface BasicAttack {
  kind: string;
  ranged: boolean;
  style: string;
}

export interface Blessing {
  id: string;
  item: string; // id in items.json
  line: string;
  name: Name;
  rarity: RarityKey;
  stats: Record<string, number>;
}

export interface BlessingsFile {
  blessings: Blessing[];
  duration: number;
  elixirDuration: number;
  elixirValue: number;
  elixirs: Elixir[];
  lines: string[];
}

export interface Bonus {
  decimals: number;
  hook?: string;
  id: string;
  max: number;
  min: number;
  mode: string;
  name: Name;
  percent: boolean;
  ranges: Record<string, Record<string, number[]>>;
  scaling: string;
  stat?: string;
}

export interface BonusesFile {
  bonuses: Bonus[];
  classStats: Record<string, ClassId[]>;
  frequency: Record<string, Record<string, Record<string, number>>>;
  pools: Record<string, string[]>;
  rolls: number;
}

export interface Boss {
  attack: string;
  attacks: BossAttack[];
  aura: string;
  byPlayers: BossScale[];
  damageKind: string;
  dungeon: string; // id in maps.json
  enrageAfter: number;
  enrageDamage: number;
  enrageText?: Name;
  exp: number;
  gateCave?: string; // id in caves.json
  goldMax: number;
  goldMin: number;
  haste?: Record<string, number>;
  id: string;
  level: number;
  loot: BossLoot;
  moveSpeed: number;
  name: Name;
  personal: BossPersonal;
  phaseTexts: Name[];
  phases: number[];
  range: number;
  region: string;
  requiredLevel: number;
  scriptConsts: Record<string, number>;
  size: number;
  summons: BossSummon[];
  timeLimit: number;
}

export interface BossAttack {
  angle?: number;
  cooldown: number;
  count?: number;
  damage: number;
  damageKind?: string;
  dmgMax: number;
  dmgMin: number;
  element?: ElementId;
  id: string;
  inner?: number;
  leap?: boolean;
  length?: number;
  name?: Name;
  phases: number[];
  radius?: number;
  shape: string;
  target: string;
  width?: number;
  windup: number;
}

export interface BossItemChance {
  chance: number;
  id: string; // id in items.json
}

export interface BossLoot {
  itemMax: number;
  itemMin: number;
  items: BossItemChance[];
  legendaryBlessingChance: number;
  materials: BossMaterial[];
  named: string[]; // ids in items.json
  rarities: Record<string, number>;
  rolls: number;
}

export interface BossMaterial {
  chance: number;
  id: string; // id in items.json
  max: number;
  min: number;
}

export interface BossPersonal {
  legendary: PityLine;
  mythic: PityLine;
}

export interface BossScale {
  armor: number;
  dmgMax: number;
  dmgMin: number;
  extraItems: number;
  hp: number;
  mres: number;
  players: number;
}

export interface BossSummon {
  count: number;
  every?: number;
  level: number;
  monster: string; // id in monsters.json
  phase: number;
  shield?: boolean;
}

export interface BossesFile {
  bosses: Boss[];
  countdown: number;
  dailyRuns: number;
  entryRange: number;
  releaseAfter: number;
}

export interface CategoryInfo {
  name: Name;
}

export interface Cave {
  arrival?: Point;
  boss: boolean;
  elite2: string[]; // ids in monsters.json
  eliteGroups: number;
  elites: string[]; // ids in monsters.json
  entrance?: CaveEntrance;
  groups: number;
  id: string;
  levelMax: number;
  levelMin: number;
  monsters: number;
  name: Name;
  normal: string[]; // ids in monsters.json
  oreCount: number;
  ores: string[];
  profile?: string;
  region: string; // id in maps.json
}

export interface CaveEntrance {
  rot: number;
  x: number;
  z: number;
}

export interface CaveEntranceInfo {
  cave: string; // id in caves.json
  rot: number;
  x: number;
  z: number;
}

export interface CavesFile {
  caves: Cave[];
}

export interface ClassInfo {
  basicAttack: BasicAttack;
  color: string;
  desc: Name;
  icon: string;
  id: ClassId;
  mainStats: string[];
  name: Name;
  offhandTypes: string[];
  order: number;
  resource: string;
  role: Name;
  startStats: Record<string, number>;
  startingGear: string[]; // ids in items.json
  weaponTypes: string[];
}

export interface ClassesFile {
  classes: ClassInfo[];
}

export interface Cosmetic {
  color: string;
  color2?: string;
  desc?: Name;
  icon: string;
  id: string;
  kind: string;
  name: Name;
}

export interface CosmeticKind {
  id: string;
  name?: Name;
}

export interface CosmeticsFile {
  cosmetics: Cosmetic[];
  kinds: CosmeticKind[];
}

export interface CraftAmount {
  id: string; // id in items.json
  n: number;
}

export interface CraftItem {
  classes?: string[];
  el?: string;
  item: string; // id in items.json
  recipe: string;
}

export interface CraftRange {
  id: string; // id in items.json
  max: number;
  min: number;
}

export interface CraftRow {
  gold: number;
  items: CraftItem[];
  level: number;
  materials: CraftAmount[];
  slot: string;
}

export interface CraftingFile {
  dismantle: Record<string, CraftRange[]>;
  refund: UpgradeRefund[];
  rows: CraftRow[];
}

export interface DailyLevel {
  level: number;
  objective: QuestObjective;
  reward: QuestReward;
}

export interface DailyQuests {
  perDay: number;
  templates: DailyTemplate[];
}

export interface DailyTemplate {
  byLevel: DailyLevel[];
  id: string;
  minLevel: number;
  title: Name;
}

export interface DropSource {
  cap: RarityKey;
  chance: number;
  extra?: number;
  max: number;
  min: number;
  weights: Record<string, number>;
}

export interface Element {
  color: string;
  id: ElementId;
  name: Name;
  weapon: boolean;
}

export interface ElementsFile {
  default: ElementId;
  elements: Element[];
}

export interface Elixir {
  name: Name;
  stat: string;
}

export interface FishCatch {
  chance: number;
  id: string; // id in items.json
  rarity: RarityKey;
  speed: number;
  weight: number;
  zone: number;
}

export interface FishChest {
  gold: number;
  loot: AmountRange[];
}

export interface FishFile {
  chest: FishChest;
  spots: FishSpot[];
}

export interface FishSpot {
  chestChance: number;
  fish: FishCatch[];
  id: string;
}

export interface FixedBonus {
  stat: string; // id in bonuses.json
  v: number;
}

export interface GatherFile {
  nodes: GatherNode[];
  placements: Record<string, GatherPlacement[]>;
}

export interface GatherNode {
  category: string;
  color: string;
  id: string;
  level: number;
  loot: AmountRange[];
  name: Name;
  respawn: number;
  shape: string;
  spot?: string;
  time: number;
  tool?: string; // id in items.json
}

export interface GatherPlacement {
  kind: string;
  n: number;
  rect?: number[];
  x?: number;
  z?: number;
}

export interface IconLayer {
  image: number;
  tint?: string;
  x: number;
  y: number;
}

export interface IconsFile {
  cell: number;
  icons: Json;
  sheets: string[];
  tierTint: Json;
}

export interface Item {
  bind: boolean;
  bonusGroup?: string;
  boss?: string; // id in bosses.json
  capacity?: number;
  category: Category;
  classes?: ClassId[];
  color: string;
  desc?: Name;
  elemental: boolean;
  fixedBonuses?: FixedBonus[];
  glyph: string;
  iconKey?: string;
  id: string;
  layers?: IconLayer[];
  layersByElement?: Record<string, IconLayer[]>;
  level: number;
  maxStack: number;
  name: Name;
  nameByElement?: Record<string, Name>;
  noSell: boolean;
  rarities: RarityKey[];
  requiredLevel: number;
  slot?: SlotGroup;
  sources: ItemSources;
  stackable: boolean;
  stats?: Record<string, ItemRarityStats>;
  tier?: number;
  type: string;
  use?: Json;
  usedFor?: ItemUsedFor;
  value: Record<string, number[]>;
}

export interface ItemChance {
  chance: number;
  id: string; // id in items.json
}

export interface ItemRarityStats {
  base: Record<string, number[]>;
  weapon?: ItemWeapon;
}

export interface ItemSources {
  alchemy: string[];
  bosses: SourceBoss[];
  crafting: SourceCraft[];
  dismantle: boolean;
  fishing: SourceFish[];
  fishingChest: boolean;
  gathering: SourceGather[];
  monsters: SourceMonster[];
  quests: SourceQuest[];
  shops: SourceShop[];
}

export interface ItemUsedFor {
  alchemy: string[];
  crafting: number;
  upgrade: number[];
}

export interface ItemWeapon {
  dmg: number[];
  mdmg: number[];
  ranged: boolean;
  speed: number;
  twoHanded: boolean;
}

export interface ItemsFile {
  bases: Record<string, BaseInfo>;
  categories: Record<string, CategoryInfo>;
  items: Item[];
  slots: Record<string, SlotInfo>;
}

export interface Lake {
  r: number;
  x: number;
  z: number;
}

export interface LevelDiff {
  diff: number;
  multiplier: number;
}

export interface LevelExp {
  exp: number;
  level: number;
  total: number;
}

export interface LootGroup {
  chance: number;
  ilvlMax: number;
  ilvlMin: number;
  top: ItemChance[];
}

export interface MainQuest {
  done?: Name;
  giver: string; // id in npcs.json
  id: string;
  level: number;
  objectives: QuestObjective[];
  order: number;
  reward: QuestReward;
  text?: Name;
  title: Name;
  turnIn: string; // id in npcs.json
}

export interface MapFeatures {
  caves: CaveEntranceInfo[];
  lakes: Lake[];
  npcSpots: Record<string, NpcSpotInfo>;
  questAnchors: QuestAnchorInfo[];
  roads: Road[];
  streams: StreamInfo[];
}

export interface MapInfo {
  biome: string;
  dungeonEntrance?: Point3;
  dungeonRegion?: string;
  id: string;
  kind: string;
  links: string[]; // ids in maps.json
  maxLevel: number;
  minLevel: number;
  name: Name;
  offset: Point3;
  route?: string[]; // ids in maps.json
  size: Point;
  spawn: Point3;
  worldMap: WorldMapPos;
  zone: string;
}

export interface MapSearchEntry {
  id: string;
  kind: string;
  map: string; // id in maps.json
  texts: string[];
  x: number;
  z: number;
}

export interface MapSearchFile {
  en: MapSearchEntry[];
  limit: number;
  pl: MapSearchEntry[];
  vectors: MapSearchVector[];
}

export interface MapSearchVector {
  lang: string;
  query: string;
  results: string[];
}

export interface MapsFile {
  maps: MapInfo[];
}

export interface MaterialChance {
  chance: number;
  id: string; // id in items.json
  max: number;
  measured: number;
  min: number;
}

export interface MechanicsFile {
  areaProfiles?: Record<string, AreaProfileInfo>;
  bossDailyRuns: number;
  combat: Json;
  config: Record<string, number>;
  formula: Json;
  variants: Record<string, VariantInfo>;
  zones: Record<string, ZoneInfo>;
}

export interface MetaFile {
  counts: Record<string, number>;
  dataCommit: string;
  dataDate: string;
  dataHash: string;
  features: Record<string, boolean>;
  rolls: number;
  schemaVersion: number;
}

export interface Monster {
  ability?: Ability;
  atkMul: number;
  attack: string;
  cave: boolean;
  classBias: number;
  damageKind: string;
  defMul: number;
  element?: ElementId;
  elites: boolean;
  family?: string;
  hpMul: number;
  id: string;
  kindReward: number;
  lootTable: string;
  moveSpeed: number;
  name: Name;
  passive: boolean;
  range: number;
  region: number;
  regionMap: string; // id in maps.json
  speed: number;
  variants: Record<string, MonsterVariant>;
}

export interface MonsterLevel {
  abilityMax?: number;
  abilityMin?: number;
  aggroRange: number;
  armor: number;
  attackInterval: number;
  dmgMax: number;
  dmgMin: number;
  exp: number;
  finalLevel: number;
  goldMax: number;
  goldMin: number;
  hp: number;
  level: number;
  mres: number;
  range: number;
}

export interface MonsterLoot {
  groups: Record<string, LootGroup>;
  itemChance: number;
  itemExtra?: number;
  itemMax: number;
  itemMeasured: number;
  itemMin: number;
  items: ItemChance[];
  materials: MaterialChance[];
  rarities: Record<string, number>;
  rolls: number;
}

export interface MonsterSpawn {
  area?: string; // id in areas.json
  cave?: string; // id in caves.json
  count: number;
  groups: number;
  levelMax: number;
  levelMin: number;
  map: string; // id in maps.json
  profile?: string;
  respawnMax: number;
  respawnMin: number;
}

export interface MonsterVariant {
  levelMax: number;
  levelMin: number;
  levels: MonsterLevel[];
  loot: MonsterLoot;
  name: Name;
  spawns: MonsterSpawn[];
}

export interface MonstersFile {
  monsters: Monster[];
}

export interface NormalizeVector {
  input: string;
  output: string;
}

export interface Npc {
  colors: NpcColors;
  decoration: boolean;
  facing: number;
  greeting?: Name;
  icon: string;
  id: string;
  map: string; // id in maps.json
  name: Name;
  role?: Name;
  services: string[];
  shop?: string; // id in shops.json
  x: number;
  z: number;
}

export interface NpcColors {
  accent: string;
  body: string;
}

export interface NpcSpotInfo {
  facing: number;
  x: number;
  z: number;
}

export interface NpcsFile {
  npcs: Npc[];
  services: Record<string, Name>;
}

export interface PityLine {
  byMisses: number[];
  chance: number;
  expectedKills: number;
  hard: number;
  step: number;
}

export interface PlaceRef {
  area?: string; // id in areas.json
  cave?: string; // id in caves.json
  map: string; // id in maps.json
  npc?: string; // id in npcs.json
}

export interface Point {
  x: number;
  z: number;
}

export interface Point3 {
  x: number;
  y: number;
  z: number;
}

export interface PortalInfo {
  arrive?: Point;
  id: string;
  kind: string;
  map: string; // id in maps.json
  rot: number;
  target: string; // id in maps.json
  x: number;
  z: number;
}

export interface PortalsFile {
  portals: PortalInfo[];
}

export interface ProgressionFile {
  expToNext: LevelExp[];
  levelDiff: LevelDiff[];
  maxLevel: number;
  skillPointsFromLevel: number;
  skillPointsPerLevel: number;
  statPointsPerLevel: number;
  variantExp: Record<string, number>;
}

export interface QuestAnchorInfo {
  id: string;
  x: number;
  z: number;
}

export interface QuestObjective {
  anchor?: string;
  anchors?: string[];
  area?: string; // id in areas.json
  boss?: string; // id in bosses.json
  category?: string;
  chance?: number;
  hold?: number;
  item?: string;
  itemName?: Name;
  label: Name;
  level?: number;
  map?: string; // id in maps.json
  monster?: string; // id in monsters.json
  n: number;
  node?: string;
  npc?: string; // id in npcs.json
  place?: Name;
  radius?: number;
  rarity?: number;
  region?: number;
  type: string;
  up?: number;
  variant?: string;
  where?: PlaceRef;
  x?: number;
  z?: number;
}

export interface QuestReward {
  choice?: string;
  exp: number;
  gold: number;
  items: QuestRewardItem[];
}

export interface QuestRewardItem {
  id: string; // id in items.json
  n: number;
}

export interface QuestWhere {
  area?: string; // id in areas.json
  map: string; // id in maps.json
  x?: number;
  z?: number;
}

export interface QuestsFile {
  daily: DailyQuests;
  levelSlack: number;
  main: MainQuest[];
  side: SideQuest[];
  sideLevelSlack: number;
  sideMaxActive: number;
}

export interface RaritiesFile {
  rarities: Rarity[];
  sources: Record<string, DropSource>;
  upgradeStatPerLevel: number;
}

export interface Rarity {
  baseMul: number;
  bindOnPickup: boolean;
  bonusMax: number;
  bonusMin: number;
  color: string;
  dismantle: AmountRange[];
  id: number;
  key: RarityKey;
  legendaryLines: number;
  name: Name;
  rangeMul: number;
  sellMul: number;
  short: Name;
  textColor: string;
}

export interface RecipeGroup {
  id: string;
  name?: Name;
}

export interface RecipesFile {
  groups: RecipeGroup[];
  queueSlots: number;
  recipes: AlchemyRecipe[];
}

export interface Road {
  material: string;
  points: number[];
  width: number;
}

export interface SearchEntry {
  class?: string;
  id: string;
  key: string;
  level?: number;
  map?: string; // id in maps.json
  name: Name;
  rarity?: string;
  type: string;
  zone?: string;
}

export interface SearchFile {
  entries: SearchEntry[];
  vectors: NormalizeVector[];
}

export interface Seconds {
  max: number;
  min: number;
}

export interface Shop {
  classTabs: boolean;
  entries: ShopEntry[];
  id: string;
  npcs: string[]; // ids in npcs.json
}

export interface ShopEntry {
  classes?: string[];
  el?: string;
  gold: number;
  goldPerLevel?: number;
  ilvl?: number;
  item: string; // id in items.json
  key?: string;
  level?: number;
  rarity: string;
}

export interface ShopsFile {
  shops: Shop[];
  weaponsmithTiers: number[];
}

export interface SideQuest {
  arc: string;
  arcName: Name;
  done?: Name;
  giver: string; // id in npcs.json
  id: string;
  level: number;
  objectives: QuestObjective[];
  pages: Name[];
  progress?: Name;
  requires: string[];
  reward: QuestReward;
  title: Name;
  turnIn: string; // id in npcs.json
  where?: QuestWhere;
}

export interface Skill {
  adaptive?: boolean;
  angle?: number;
  breakpoints: SkillBreakpoint[];
  class: ClassId;
  col: number;
  damageKind?: string;
  delay?: number;
  effects?: Json;
  element?: ElementId;
  elementNote?: Name;
  glyph: string;
  hits?: number;
  holy?: boolean;
  id: string;
  interval?: number;
  length?: number;
  maxLevel: number;
  name: Name;
  order: number;
  passive?: Json;
  passiveSkill: boolean;
  radius?: number;
  range?: number;
  ranks: SkillRank[];
  requiredElement?: ElementId;
  requires: SkillRequirement[];
  resource?: string;
  row: number;
  shape: string;
  target: string;
  type: string;
  unlock: number;
  values: Json;
  width?: number;
}

export interface SkillBreakpoint {
  change: Json;
  level: number;
  text: Name;
}

export interface SkillRank {
  cooldown: number;
  cost: number;
  desc: Name;
  rank: number;
  requiredLevel: number;
  values: Record<string, number>;
}

export interface SkillRequirement {
  level: number;
  skill: string; // id in skills.json
}

export interface SkillRules {
  breakpointLevels: number[];
  breakpointsEnabled: boolean;
  maxLevel: number;
  pointsByLevel: number[];
  skillPointsFromLevel: number;
  skillPointsPerLevel: number;
  vectors: SkillVectors;
}

export interface SkillVectorBuild {
  achievable: boolean;
  class: ClassId;
  level: number;
  skills: Record<string, number>;
}

export interface SkillVectorResult {
  detail?: Json;
  ok: boolean;
  reason?: string;
  skill: string; // id in skills.json
}

export interface SkillVectorState {
  class: ClassId;
  level: number;
  results: SkillVectorResult[];
  skillPoints: number;
  skills: Record<string, number>;
}

export interface SkillVectors {
  builds: SkillVectorBuild[];
  states: SkillVectorState[];
}

export interface SkillsFile {
  rules: SkillRules;
  skills: Skill[];
}

export interface SlotInfo {
  name: Name;
}

export interface SourceBoss {
  boss: string; // id in bosses.json
  chance: number;
  personal: boolean;
}

export interface SourceCraft {
  gold: number;
  level: number;
  recipe: string;
}

export interface SourceFish {
  chance: number;
  spot: string;
}

export interface SourceGather {
  chance: number;
  max: number;
  min: number;
  node: string;
}

export interface SourceMonster {
  chance: number;
  monster: string; // id in monsters.json
  variant: string;
}

export interface SourceQuest {
  n: number;
  quest: string;
}

export interface SourceShop {
  gold: number;
  ilvl?: number;
  shop: string; // id in shops.json
}

export interface SpawnGroup {
  area?: string;
  count: number;
  id: string;
  kinds: string[]; // ids in monsters.json
  levelMax: number;
  levelMin: number;
  respawnMax: number;
  respawnMin: number;
  variant: string;
  x: number;
  z: number;
}

export interface StatGroupInfo {
  id: string;
  name: Name;
}

export interface StatInfo {
  cap?: number;
  decimals: number;
  format: string;
  group: string;
  id: string;
  name: Name;
  order: number;
}

export interface StatsFile {
  formula: Json;
  groups: StatGroupInfo[];
  primary: string[];
  primaryNames: Record<string, Name>;
  stats: StatInfo[];
}

export interface StreamInfo {
  id: string;
  into: string;
  points: number[];
  widths: number[];
}

export interface Title {
  color: string;
  id: string;
  name: Name;
  req: TitleReq;
}

export interface TitleReq {
  kind: string;
  value: number;
}

export interface TitlesFile {
  titles: Title[];
}

export interface UpgradeCost {
  gold: number;
  materials: UpgradeMaterial[];
}

export interface UpgradeFile {
  costs: Record<string, Record<string, UpgradeCost[]>>;
  max: number;
  protection: string; // id in items.json
  steps: UpgradeStep[];
  tiers: number[];
  vectors: UpgradeVector[];
}

export interface UpgradeMaterial {
  id: string; // id in items.json
  n: number;
}

export interface UpgradeRefund {
  materials: CraftAmount[];
  up: number;
}

export interface UpgradeStep {
  chance: number;
  failTo?: number;
  protectedTo: number;
  statMultiplier: number;
  to: number;
}

export interface UpgradeVector {
  attempts: number;
  from: number;
  gold: number;
  ilvl: number;
  materials: Record<string, number>;
  protectFrom?: number;
  rarity: string;
  runs: number;
  scrolls: number;
  to: number;
}

export interface VariantInfo {
  aggroRange: number;
  dmgMul: number;
  expMul: number;
  goldMul: number;
  hpMul: number;
  levelAdd: number;
  name?: Name;
  scale: number;
}

export interface WorldMapPos {
  x: number;
  y: number;
}

export interface ZoneInfo {
  color: string;
  name: Name;
  rule: Name;
}

/** Every data file in wiki/src/data by name (<name>.json). */
export interface Files {
  areas: AreasFile;
  blessings: BlessingsFile;
  bonuses: BonusesFile;
  bosses: BossesFile;
  caves: CavesFile;
  classes: ClassesFile;
  cosmetics: CosmeticsFile;
  crafting: CraftingFile;
  elements: ElementsFile;
  fish: FishFile;
  gather: GatherFile;
  icons: IconsFile;
  items: ItemsFile;
  maps: MapsFile;
  mapsearch: MapSearchFile;
  mechanics: MechanicsFile;
  meta: MetaFile;
  monsters: MonstersFile;
  npcs: NpcsFile;
  portals: PortalsFile;
  progression: ProgressionFile;
  quests: QuestsFile;
  rarities: RaritiesFile;
  recipes: RecipesFile;
  search: SearchFile;
  shops: ShopsFile;
  skills: SkillsFile;
  stats: StatsFile;
  titles: TitlesFile;
  upgrade: UpgradeFile;
}
