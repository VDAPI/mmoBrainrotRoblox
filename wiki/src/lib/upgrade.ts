// Upgrade calculator math (S40, pure): an absorbing Markov chain over the levels below the target. Every chance,
// failure result and cost comes from the export (upgrade.json steps and costs); this module only solves
// (I − Q)x = c with Gaussian elimination. Checked against the Lune simulation vectors (upgrade.json vectors).

export interface Step {
  to: number; // target level of the attempt
  chance: number; // 0..1
  failTo?: number; // level after a failure without protection (missing = never fails)
  protectedTo: number; // level after a failure with the protection scroll
}

export interface Cost {
  gold: number;
  materials: { id: string; n: number }[];
}

export interface Expected {
  attempts: number;
  gold: number;
  materials: Record<string, number>;
  scrolls: number;
  perStep: StepExpected[];
}

export interface StepExpected {
  from: number;
  to: number;
  chance: number;
  protected: boolean;
  failTo: number; // where a failure leads on this path
  attempts: number;
  gold: number;
  materials: Record<string, number>;
  scrolls: number;
}

/** Chance to go from `from` to `to` with no failure: the product of the step chances. */
export function firstTryChance(steps: Step[], from: number, to: number): number {
  let p = 1;
  for (let n = from + 1; n <= to; n++) p *= steps[n - 1]?.chance ?? 0;
  return p;
}

/** Solves A x = b (A n×n) by Gaussian elimination with partial pivoting. */
export function solve(a: number[][], b: number[]): number[] {
  const n = b.length;
  const m = a.map((row, i) => [...row, b[i]]);
  for (let col = 0; col < n; col++) {
    let pivot = col;
    for (let r = col + 1; r < n; r++) if (Math.abs(m[r][col]) > Math.abs(m[pivot][col])) pivot = r;
    [m[col], m[pivot]] = [m[pivot], m[col]];
    const d = m[col][col];
    if (Math.abs(d) < 1e-12) throw new Error("upgrade: singular system");
    for (let c = col; c <= n; c++) m[col][c] /= d;
    for (let r = 0; r < n; r++) {
      if (r === col || m[r][col] === 0) continue;
      const f = m[r][col];
      for (let c = col; c <= n; c++) m[r][c] -= f * m[col][c];
    }
  }
  return m.map((row) => row[n]);
}

/** Level after a failed attempt at target `to` (protected or not). */
function failLevel(step: Step, protect: boolean): number {
  if (protect) return step.protectedTo >= step.to ? step.to - 1 : step.protectedTo;
  return step.failTo ?? step.to - 1;
}

/**
 * Expected totals of upgrading from `from` to `to` (states 0..to−1; a failure may drop below `from`). Protection is
 * used on every attempt whose target is >= protectFrom (null = never) and costs one scroll per attempt.
 */
function totals(steps: Step[], costs: Cost[], from: number, to: number, protectFrom: number | null) {
  const n = to; // states 0..to-1
  const ids = [...new Set(costs.slice(0, to).flatMap((c) => c.materials.map((m) => m.id)))];
  const a: number[][] = Array.from({ length: n }, () => Array(n).fill(0));
  const rhs = { attempts: Array(n).fill(0), gold: Array(n).fill(0), scrolls: Array(n).fill(0), mats: ids.map(() => Array(n).fill(0)) };
  for (let level = 0; level < n; level++) {
    const step = steps[level];
    const cost = costs[level];
    const protect = protectFrom !== null && step.to >= protectFrom;
    a[level][level] += 1;
    if (level + 1 < n) a[level][level + 1] -= step.chance;
    const q = 1 - step.chance;
    if (q > 0) a[level][failLevel(step, protect)] -= q;
    rhs.attempts[level] = 1;
    rhs.gold[level] = cost?.gold ?? 0;
    rhs.scrolls[level] = protect ? 1 : 0;
    ids.forEach((id, i) => (rhs.mats[i][level] = cost?.materials.find((m) => m.id === id)?.n ?? 0));
  }
  const at = (x: number[]) => x[from];
  return {
    attempts: at(solve(a, rhs.attempts)),
    gold: at(solve(a, rhs.gold)),
    scrolls: at(solve(a, rhs.scrolls)),
    materials: Object.fromEntries(ids.map((id, i) => [id, at(solve(a, rhs.mats[i]))])),
  };
}

export function expected(steps: Step[], costs: Cost[], from: number, to: number, protectFrom: number | null = null): Expected {
  if (to <= from) return { attempts: 0, gold: 0, materials: {}, scrolls: 0, perStep: [] };
  const all = totals(steps, costs, from, to, protectFrom);
  const perStep: StepExpected[] = [];
  for (let level = from; level < to; level++) {
    // Failures only move down, so reaching L+1 from L is a first passage; its totals sum to the whole path.
    const one = totals(steps, costs, level, level + 1, protectFrom);
    const step = steps[level];
    const protect = protectFrom !== null && step.to >= protectFrom;
    perStep.push({ from: level, to: level + 1, chance: step.chance, protected: protect, failTo: failLevel(step, protect), ...one });
  }
  return { ...all, perStep };
}
