// Skill ranks on the wiki (S56): ranks grow with the character level (ROZWOJ 2.5). The level of every rank
// comes from skills.json (`rankLevels`, Logic/Skills.rankLevel in Lune). S82 rebuilds the planner.

export interface RankSkill {
  unlock: number;
  maxLevel: number;
  rankLevels: number[];
}

/** Character level at which `skill` reaches rank n (clamped to 1..maxLevel). */
export function rankLevel(skill: RankSkill, n: number): number {
  const r = Math.min(Math.max(Math.floor(n), 1), skill.maxLevel);
  return skill.rankLevels[r - 1] ?? skill.unlock;
}

/** Rank of `skill` at character level `level` (0 before the unlock). */
export function rankAt(skill: RankSkill, level: number): number {
  for (let r = skill.maxLevel; r >= 1; r--) {
    if (level >= rankLevel(skill, r)) return r;
  }
  return 0;
}
