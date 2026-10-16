// GENEROWANE przez tools/wikidump.luau — nie edytuj (zmiany: tools/WikiData/Schema i buildery).

export type Name = { pl: string; en: string };
export type Json = string | number | boolean | null | Json[] | { [key: string]: Json };

export type Category = "backpack" | "consumable" | "equipment" | "material" | "scroll" | "stone" | "tool";
export type ClassId = "Cleric" | "Hunter" | "Mage" | "Warrior";
export type ElementId = "fire" | "ice" | "lightning" | "poison";
export type FamilyId = "animal" | "beast" | "dragon" | "elemental" | "humanoid" | "undead";
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

export interface ArenaBracket {
  max: number;
  min: number;
}

export interface ArenaFile {
  bloodMoon: BloodMoonInfo;
  brackets: ArenaBracket[];
  minLevel: number;
  rules: ArenaRules;
  season: ArenaSeason;
  seasonRewards: ArenaSeasonReward[];
  shop: ArenaShopEntry[];
  tiers: ArenaTier[];
  tokens: ArenaTokens;
  tourney: TourneyInfo;
}

export interface ArenaRules {
  acceptSec: number;
  declinePenaltyMin: number;
  k: number;
  kNew: number;
  kNewMatches: number;
  potions: number;
  roundTime: number;
  roundsToWin: number;
  sameOpponentDaily: number;
  start: number;
  teamTime: number;
}

export interface ArenaSeason {
  minPlayed: number;
  softReset: number;
}

export interface ArenaSeasonReward {
  aura?: Name;
  currency: boolean;
  frame?: Name;
  name: Name;
  tier: string;
  title?: Name;
}

export interface ArenaShopEntry {
  cosmetic?: string;
  group: string;
  id: string;
  item?: string; // id in items.json
  kind: string;
  n?: number;
  name: Name;
  tokens: number;
}

export interface ArenaTier {
  id: string;
  min: number;
  name: Name;
}

export interface ArenaTokens {
  firstDaily: number;
  firstMul: number;
  loss: number;
  loss3: number;
  weekCap: number;
  win: number;
  win3: number;
}

export interface AuctionCategory {
  id: string;
  name: Name;
}

export interface AuctionExample {
  deposit: number;
  fee: number;
  gold: number;
  payout: number;
}

export interface AuctionRules {
  depositPct: number;
  durations: number[];
  feePct: number;
  maxListings: number;
}

export interface AutoGrindInfo {
  blocked: Name[];
  dailyHours: number;
  expPct: number;
  goldPct: number;
  levelGap: number;
  scroll: string; // id in items.json
  scrollMin: number;
}

export interface AutoPotionInfo {
  blocked: Name[];
  maxPct: number;
  minPct: number;
  step: number;
}

export interface BaseInfo {
  affinity?: Record<string, Record<string, number>>;
  bonusGroup: string;
  classes?: ClassId[];
  elemental: boolean;
  glyph: string;
  name: Name;
  poolClasses: ClassId[];
  slot: SlotGroup;
  trait?: string;
}

export interface BasicAttack {
  kind: string;
  ranged: boolean;
  style: string;
}

export interface BestArea {
  area: string; // id in areas.json
  level: number;
  map: string; // id in maps.json
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

export interface BloodMoonInfo {
  durationMin: number;
  eliteChance: number;
  minPoints: number;
  points: BloodMoonPoints;
  regions: Name[];
  rewards: EventReward[];
  slots: EventSlot[];
  warnMin: number[];
}

export interface BloodMoonPoints {
  elite: number;
  elite2: number;
  levelGap: number;
  player: number;
  sameVictim: number;
}

export interface Bonus {
  decimals: number;
  hook?: string;
  id: string;
  max: number;
  min: number;
  mode: string;
  name: Name;
  of?: string;
  param?: string;
  percent: boolean;
  ranges: Record<string, Record<string, number[]>>;
  scaling: string;
  stat?: string;
  tier: string;
}

export interface BonusParam {
  name: Name;
  over: string;
  variants: string[]; // ids in bonuses.json
}

export interface BonusesFile {
  bonuses: Bonus[];
  classStats: Record<string, ClassId[]>;
  frequency: Record<string, Record<string, Record<string, Record<string, number>>>>;
  params: Record<string, BonusParam>;
  pools: Record<string, string[]>;
  rolls: number;
}

export interface Boss {
  attack: string;
  attacks: BossAttack[];
  aura: string;
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
  stats: BossStats;
  summons: BossSummon[];
  timeLimit: number;
}

export interface BossAttack {
  angle?: number;
  avoid?: boolean;
  channel?: BossChannel;
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
  mark?: BossMark;
  mechanic?: string;
  mechanicText?: Name;
  name?: Name;
  phases: number[];
  radius?: number;
  shape: string;
  split?: BossSplit;
  target: string;
  width?: number;
  windup: number;
}

export interface BossChannel {
  breakPct: number;
  seconds: number;
  stagger: number;
}

export interface BossContract {
  byLevel: BossContractLevel[];
  n: number;
}

export interface BossContractLevel {
  boss: string; // id in bosses.json
  level: number;
  reward: QuestReward;
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

export interface BossMark {
  seconds: number;
  self: number;
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

export interface BossQuest {
  boss: string; // id in bosses.json
  giver: string; // id in npcs.json
  id: string;
  level: number;
  reward: QuestReward;
  title: Name;
  where?: PlaceRef;
}

export interface BossSplit {
  missAll: number;
}

export interface BossStats {
  armor: number;
  dmgMax: number;
  dmgMin: number;
  hp: number;
  mres: number;
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

export interface ClassLook {
  class: ClassId;
  colors: LookColors;
  garments: Name[];
  name: Name;
  outfits: ClassOutfit[];
}

export interface ClassLooksFile {
  classes: ClassLook[];
  faces: number;
  hairs: number;
  skins: string[];
}

export interface ClassOutfit {
  id: string;
  source: string;
}

export interface ClassesFile {
  classes: ClassInfo[];
}

export interface Contract {
  area: string; // id in areas.json
  label: Name;
  level: number;
  map: string; // id in maps.json
  n: number;
  reward: QuestReward;
}

export interface Contracts {
  board: string; // id in npcs.json
  list: Contract[];
  max: number;
  milestoneEvery: number;
  scouts: string[]; // ids in npcs.json
}

export interface Cosmetic {
  class?: ClassId;
  color: string;
  color2?: string;
  desc?: Name;
  flies?: boolean;
  icon: string;
  id: string;
  kind: string;
  name: Name;
  parts?: string[];
}

export interface CosmeticKind {
  id: string;
  name?: Name;
}

export interface CosmeticTexts {
  hint: Name;
  pack: Name;
  wardrobe: Name;
}

export interface CosmeticsFile {
  cosmetics: Cosmetic[];
  kinds: CosmeticKind[];
  texts: CosmeticTexts;
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

export interface EventReward {
  aura?: Name;
  blessing?: Name;
  currency: boolean;
  frame?: Name;
  place: string;
  title?: Name;
  titleDays?: number;
  tokens?: number;
  top?: number;
}

export interface EventSlot {
  hour: number;
  minute: number;
  weekday: number;
}

export interface FamilyInfo {
  name: Name;
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

export interface FullElixirInfo {
  blocked: Name[];
  cooldown: number;
  dailyLimit: number;
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

export interface GuildInfo {
  actions: string[];
  maxLevel: number;
  memberLimits: number[];
  ranks: GuildRankInfo[];
  rules: Record<string, number>;
  skills: GuildSkillInfo[];
}

export interface GuildRankInfo {
  can: Record<string, boolean>;
  id: string;
  name: Name;
}

export interface GuildSkillInfo {
  costs: number[];
  desc: Name[];
  effects: number[];
  icon: string;
  id: string;
  name: Name;
  stat: string;
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
  traits: Record<string, TraitInfo>;
}

export interface KeybindInfo {
  group: string;
  id: string;
  key: string;
  name: Name;
}

export interface Lake {
  r: number;
  x: number;
  z: number;
}

export interface LevelBandInfo {
  band: string;
  color: string;
  max: number;
  min: number;
}

export interface LevelDiff {
  diff: number;
  multiplier: number;
}

export interface LevelDiffRules {
  bonusPerLevel: number;
  freeDiff: number;
  maxBonus: number;
  minMultiplier: number;
  penaltyPerLevel: number;
}

export interface LevelExp {
  exp: number;
  level: number;
  total: number;
}

export interface LookColors {
  main: string;
  second: string;
  trim: string;
}

export interface LootGroup {
  chance: number;
  ilvlMax: number;
  ilvlMin: number;
  top: ItemChance[];
}

export interface LureInfo {
  blocked: Name[];
  interval: number;
  levelGap: number;
  maxPulled: number;
  radius: number;
}

export interface MailRules {
  lifetimeDays: number;
  maxItemsPerParcel: number;
  maxParcels: number;
}

export interface MainQuest {
  chapter: number;
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

export interface MarketInfo {
  auction: AuctionRules;
  categories: AuctionCategory[];
  examples: AuctionExample[];
  mail: MailRules;
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
  dexRatingLevel: number;
  formula: Json;
  guild: GuildInfo;
  keybinds: KeybindInfo[];
  levelBands: LevelBandInfo[];
  market: MarketInfo;
  potionInterval: PotionInterval[];
  pvp: PvpInfo;
  reduction: ReductionTable;
  variants: Record<string, VariantInfo>;
  worldEvents?: WorldEventsInfo;
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
  dodge?: number;
  element?: ElementId;
  elites: boolean;
  family: FamilyId;
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

export interface MonsterExpRow {
  exp: Record<string, number>;
  level: number;
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
  families: Record<string, FamilyInfo>;
  monsters: Monster[];
}

export interface Mount {
  boss?: string; // id in bosses.json
  chance?: number;
  color: string;
  color2?: string;
  desc?: Name;
  id: string;
  kills?: number;
  name: Name;
  source: string;
  startLevel: number;
}

export interface MountConfig {
  baseMul: number;
  fastFromLevel: number;
  maxLevel: number;
  maxMul: number;
  minLevel: number;
  mountTime: number;
  mountTimeFast: number;
}

export interface MountLevel {
  charLevel?: number;
  gold?: number;
  level: number;
  materials?: MountMaterial[];
  mountTime: number;
  speedMul: number;
}

export interface MountMaterial {
  id: string; // id in items.json
  n: number;
}

export interface MountSkin {
  boss?: string; // id in bosses.json
  chance?: number;
  id: string;
  name: Name;
  quest?: Name;
  source: string;
}

export interface MountsFile {
  config: MountConfig;
  levels: MountLevel[];
  mounts: Mount[];
  skins: MountSkin[];
}

export interface NormalizeVector {
  input: string;
  output: string;
}

export interface Npc {
  building?: string;
  buildingName?: Name;
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

export interface PassInfo {
  desc: Name;
  icon: string;
  key: string;
  name: Name;
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

export interface PotionInterval {
  id: string;
  level: number;
  seconds: number;
}

export interface PremiumFile {
  items: PremiumItems;
  passes: PassInfo[];
  shop: PremiumService[];
  starterPacks: StarterPackInfo[];
  vip: VipInfo;
}

export interface PremiumItems {
  autoGrind: AutoGrindInfo;
  autoPotion: AutoPotionInfo;
  fullElixir: FullElixirInfo;
  lure: LureInfo;
}

export interface PremiumService {
  cat: string;
  dailyLimit?: number;
  desc?: Name;
  item?: string; // id in items.json
  key: string;
  kind: string;
  name: Name;
  weeklyLimit?: number;
}

export interface ProgressionFile {
  bestArea: BestArea[];
  expToNext: LevelExp[];
  levelDiff: LevelDiff[];
  levelDiffRules: LevelDiffRules;
  maxLevel: number;
  monsterExp: MonsterExpRow[];
  statPointsPerLevel: number;
  variantExp: Record<string, number>;
}

export interface PvpCase {
  allowed: boolean;
  attackerPvp: boolean;
  reason?: string;
  reasonName?: Name;
  relation: string;
  targetPvp: boolean;
  zone: string;
}

export interface PvpInfo {
  rows: PvpCase[];
  toggleMatters: Record<string, boolean>;
}

export interface QuestAnchorInfo {
  id: string;
  x: number;
  z: number;
}

export interface QuestChapter {
  final?: boolean;
  from: number;
  map: string; // id in maps.json
  n: number;
  title: Name;
  to: number;
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
  cosmetic?: string; // id in cosmetics.json
  exp: number;
  gold: number;
  items: QuestRewardItem[];
  mount?: string; // id in mounts.json
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
  bossQuests: BossQuest[];
  chapters: QuestChapter[];
  contracts: Contracts;
  daily: DailyQuests;
  levelSlack: number;
  main: MainQuest[];
  side: SideQuest[];
  sideChoice: SideChoice;
  sideLevelSlack: number;
  sideMaxActive: number;
  weekly: WeeklyQuests;
}

export interface RankingBoard {
  bracket?: string;
  class?: string;
  id: string;
  kind: string;
  name: Name;
  rows: RankingRow[];
  week?: number;
}

export interface RankingRow {
  class?: string;
  guild?: string;
  level?: number;
  members?: number;
  name: string;
  rank: number;
  value: number;
}

export interface RankingsFile {
  available: boolean;
  boards: RankingBoard[];
  updatedAt: number;
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
  mythicLines: number;
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

export interface ReductionRow {
  defense: number;
  values: number[];
}

export interface ReductionTable {
  levels: number[];
  rows: ReductionRow[];
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

export interface SideChoice {
  count: number;
  rarity: Record<string, RarityKey>;
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
  path?: string;
  radius?: number;
  range?: number;
  rankLevels: number[];
  ranks: SkillRank[];
  requiredElement?: ElementId;
  resource?: string;
  shape: string;
  target: string;
  type: string;
  unlock: number;
  values: Json;
  width?: number;
}

export interface SkillBreakpoint {
  a: SkillOption;
  b?: SkillOption;
  level: number;
  rank: number;
}

export interface SkillOption {
  change: Json;
  text: Name;
}

export interface SkillPath {
  class: ClassId;
  desc: Name;
  id: string;
  name: Name;
  order: number;
  role: string;
  rows: SkillPathRow[];
  title?: string; // id in titles.json
  weapon: SkillPathWeapon;
}

export interface SkillPathModify {
  at?: number;
  option?: string;
  skill: string; // id in skills.json
}

export interface SkillPathNode {
  dipScale?: number;
  glyph: string;
  id: string;
  kind: string;
  maxRank: number;
  modify?: SkillPathModify;
  name: Name;
  ranks: SkillPathNodeRank[];
  skill?: string; // id in skills.json
  skillB?: number[];
  weapon?: SkillPathWeapon;
}

export interface SkillPathNodeRank {
  desc: Name;
  dipDesc?: Name;
  rank: number;
  values: Record<string, number>;
}

export interface SkillPathRow {
  choice: boolean;
  kind: string;
  level: number;
  nodes: SkillPathNode[];
  required: number;
  row: number;
}

export interface SkillPathVectorBuild {
  achievable: boolean;
  class: ClassId;
  level: number;
  main?: string;
  nodes: Record<string, number>;
}

export interface SkillPathVectorResult {
  node: string;
  ok: boolean;
  reason?: string;
  refund: boolean;
  refundReason?: string;
}

export interface SkillPathVectorState {
  class: ClassId;
  free: number;
  level: number;
  main?: string;
  nodes: Record<string, number>;
  results: SkillPathVectorResult[];
}

export interface SkillPathVectors {
  builds: SkillPathVectorBuild[];
  states: SkillPathVectorState[];
}

export interface SkillPathWeapon {
  main?: string[];
  offhand?: string[];
}

export interface SkillRank {
  cooldown: number;
  cost: number;
  desc: Name;
  rank: number;
  requiredLevel: number;
  values: Record<string, number>;
  variants?: Record<string, SkillRankVariant>;
}

export interface SkillRankRules {
  capLevel: number;
  step: number;
}

export interface SkillRankVariant {
  cooldown: number;
  cost: number;
  desc: Name;
  values: Record<string, number>;
}

export interface SkillRowRule {
  choice: boolean;
  kind: string;
  level: number;
  required: number;
  row: number;
  twoPathExtra?: boolean;
}

export interface SkillRules {
  breakpointLevels: number[];
  breakpointsEnabled: boolean;
  dipRows: number;
  dipScale: number;
  mainPathLevel: number;
  maxLevel: number;
  pathPointsByLevel: number[];
  pathPointsEvery: number;
  ranks: SkillRankRules;
  rows: SkillRowRule[];
  vectors: SkillPathVectors;
}

export interface SkillsFile {
  paths: SkillPath[];
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

export interface StarterPackInfo {
  cosmetics: string[];
  currency: boolean;
  desc?: Name;
  key: string;
  name: Name;
  passes: string[];
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
  days?: number;
  kind: string;
  tier?: string;
  value?: number;
}

export interface TitlesFile {
  titles: Title[];
}

export interface TourneyInfo {
  cap: number;
  fields: number;
  hallWeeks: number;
  inviteSec: number;
  minPlayers: number;
  rewards: EventReward[];
  signupFromMin: number;
  signupToMin: number;
  slot: EventSlot;
}

export interface TraitInfo {
  cap?: Name;
  info: Name;
  line: Record<string, Name[]>;
  name: Name;
  pvp: Name;
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

export interface VipInfo {
  alchemyQueue: number;
  auctionExtraListings: number;
  auctionFeeBasePct: number;
  auctionFeePct: number;
  dailyCurrency: boolean;
  freeRespawnsPerDay: number;
  monthCosmetics: VipMonthCosmetic[];
  recallMin: number;
}

export interface VipMonthCosmetic {
  id: string;
  month: string;
  name: Name;
}

export interface WeeklyQuests {
  bossContract: BossContract;
  perWeek: number;
  templates: WeeklyTemplate[];
}

export interface WeeklyTemplate {
  byLevel: DailyLevel[];
  id: string;
  minLevel: number;
  title: Name;
}

export interface WorldEventKind {
  desc: Name;
  durationMin: number;
  glyph: string;
  id: string;
  name: Name;
  waves?: number;
}

export interface WorldEventsInfo {
  chestMax: Name;
  failPct: number;
  intervalMin: number;
  jitterMin: number;
  kinds: WorldEventKind[];
  maxLevelAbove: number;
  minSharePct: number;
  regions: Name[];
  warnMin: number;
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
  arena: ArenaFile;
  blessings: BlessingsFile;
  bonuses: BonusesFile;
  bosses: BossesFile;
  caves: CavesFile;
  classes: ClassesFile;
  classlooks: ClassLooksFile;
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
  mounts: MountsFile;
  npcs: NpcsFile;
  portals: PortalsFile;
  premium: PremiumFile;
  progression: ProgressionFile;
  quests: QuestsFile;
  rankings: RankingsFile;
  rarities: RaritiesFile;
  recipes: RecipesFile;
  search: SearchFile;
  shops: ShopsFile;
  skills: SkillsFile;
  stats: StatsFile;
  titles: TitlesFile;
  upgrade: UpgradeFile;
}
