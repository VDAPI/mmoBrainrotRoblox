// Render each HTML page given as argv pairs (html png) with a transparent background.
const { chromium } = require('playwright');
const { pathToFileURL } = require('url');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i += 2) {
    await p.goto(pathToFileURL(args[i]).href);
    await p.screenshot({ path: args[i + 1], omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  }
  await b.close();
})();
