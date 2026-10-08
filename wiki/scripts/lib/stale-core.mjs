// Stale wiki data (S44), pure parts: which generated text files differ from the commit after `npm run data`.
// meta.json is compared without dataCommit and dataDate (an export made before a commit carries the previous one,
// which is not staleness); binary images are never compared (encoders differ between systems).

/** Generated text files watched for changes (repository paths). */
export const WATCHED = [/^wiki\/src\/data\//, /^wiki\/src\/styles\/tokens\.data\.css$/, /^docs\/PRZEDMIOTY\.md$/, /^wiki\/public\/img\/maps\/.+\.svg$/, /^wiki\/src\/generated\//];
export const META = "wiki/src/data/meta.json";

/** Paths of `git status --porcelain` lines (renames give the new path; quotes removed). */
export function porcelainPaths(text) {
  return text
    .split(/\r?\n/)
    .filter((l) => l.trim())
    .map((l) => l.slice(3).split(" -> ").pop().replace(/^"|"$/g, ""));
}

/** meta.json without the commit and date of the data. */
export function metaWithoutCommit(json) {
  try {
    const { dataCommit: _c, dataDate: _d, ...rest } = JSON.parse(json);
    return JSON.stringify(rest);
  } catch {
    return json;
  }
}

/** Stale generated files: watched paths that changed; meta.json only when more than commit/date changed. */
export function staleFiles(paths, metaHead, metaNow) {
  return paths.filter((p) => {
    if (!WATCHED.some((re) => re.test(p))) return false;
    if (p === META) return metaHead === null || metaWithoutCommit(metaHead) !== metaWithoutCommit(metaNow ?? "");
    return true;
  });
}
