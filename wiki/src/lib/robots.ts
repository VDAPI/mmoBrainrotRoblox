// robots.txt (S44): production allows everything but the styleguide and points at the sitemap; preview builds
// (PUBLIC_NOINDEX=1) disallow everything.
export function robotsTxt(siteUrl: string, noindex: boolean): string {
  if (noindex) return "User-agent: *\nDisallow: /\n";
  return ["User-agent: *", "Allow: /", "Disallow: /pl/styleguide/", "Disallow: /en/styleguide/", "", `Sitemap: ${siteUrl}/sitemap-index.xml`, ""].join("\n");
}
