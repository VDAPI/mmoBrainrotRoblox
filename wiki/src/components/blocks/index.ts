// Data blocks usable in MDX without an import (S42; S43: city, guild, market, cosmetics, guides; S97: mounts; S131:
// arena, PvP events, VIP, premium items; S132: class outfits; WIKI-3: guild progress, contract sets, the in-game
// bestiary, the wandering merchant, the map legend).
import ArenaTable from "./ArenaTable.astro";
import AuctionTable from "./AuctionTable.astro";
import BestiaryBook from "./BestiaryBook.astro";
import BlessingTable from "./BlessingTable.astro";
import CapsTable from "./CapsTable.astro";
import CityGallery from "./CityGallery.astro";
import CityNpcs from "./CityNpcs.astro";
import ClassOutfits from "./ClassOutfits.astro";
import ClassStartTable from "./ClassStartTable.astro";
import CosmeticsGrid from "./CosmeticsGrid.astro";
import DailySetTable from "./DailySetTable.astro";
import ElementList from "./ElementList.astro";
import ElixirTable from "./ElixirTable.astro";
import EventSchedule from "./EventSchedule.astro";
import ExpChart from "./ExpChart.astro";
import ExpDiffChart from "./ExpDiffChart.astro";
import GuildProgressTable from "./GuildProgressTable.astro";
import GuildRanksTable from "./GuildRanksTable.astro";
import GuildSkillsTable from "./GuildSkillsTable.astro";
import KeybindTable from "./KeybindTable.astro";
import LevelBandStrip from "./LevelBandStrip.astro";
import LevelPath from "./LevelPath.astro";
import MapLegend from "./MapLegend.astro";
import MonsterExpTable from "./MonsterExpTable.astro";
import MountTable from "./MountTable.astro";
import PassList from "./PassList.astro";
import PotionTable from "./PotionTable.astro";
import PremiumItems from "./PremiumItems.astro";
import PvpMatrix from "./PvpMatrix.astro";
import ReductionTable from "./ReductionTable.astro";
import StatFormulaTable from "./StatFormulaTable.astro";
import TitleTable from "./TitleTable.astro";
import UpgradeChances from "./UpgradeChances.astro";
import VariantTable from "./VariantTable.astro";
import VipBenefits from "./VipBenefits.astro";
import WandererTable from "./WandererTable.astro";
import ZoneCards from "./ZoneCards.astro";

export const BLOCKS = {
  ArenaTable,
  AuctionTable,
  BestiaryBook,
  BlessingTable,
  CapsTable,
  CityGallery,
  CityNpcs,
  ClassOutfits,
  ClassStartTable,
  CosmeticsGrid,
  DailySetTable,
  ElementList,
  ElixirTable,
  EventSchedule,
  ExpChart,
  ExpDiffChart,
  GuildProgressTable,
  GuildRanksTable,
  GuildSkillsTable,
  KeybindTable,
  LevelBandStrip,
  LevelPath,
  MapLegend,
  MonsterExpTable,
  MountTable,
  PassList,
  PotionTable,
  PremiumItems,
  PvpMatrix,
  ReductionTable,
  StatFormulaTable,
  TitleTable,
  UpgradeChances,
  VariantTable,
  VipBenefits,
  WandererTable,
  ZoneCards,
};
