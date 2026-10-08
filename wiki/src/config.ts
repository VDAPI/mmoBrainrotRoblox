// Site settings (S36). S44: SITE_URL and PUBLIC_NOINDEX come from the environment of the build (GitHub Actions sets
// SITE_URL from the repository variable, PUBLIC_NOINDEX=1 for pull requests and preview branches); the default is
// the Cloudflare Pages address. PLAY_URL and DISCORD_URL are filled in by the owner: empty = the "Play on Roblox"
// button / Discord link are hidden (never a dead link).
const env: Record<string, string | undefined> = typeof process === "undefined" ? {} : process.env;

export const SITE_URL = (env.SITE_URL || "https://vaelthorn-wiki.pages.dev").replace(/\/+$/, "");
/** Preview builds: every page gets <meta name="robots" content="noindex"> and robots.txt disallows everything. */
export const NOINDEX = env.PUBLIC_NOINDEX === "1";
export const PLAY_URL = "";
export const DISCORD_URL = "";
