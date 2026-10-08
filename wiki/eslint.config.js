import js from "@eslint/js";
import astro from "eslint-plugin-astro";
import svelte from "eslint-plugin-svelte";
import globals from "globals";
import ts from "typescript-eslint";

export default [
  { ignores: ["dist/", ".astro/", "node_modules/", "design/", "src/data/", ".shots/", "test-results/", "playwright-report/", ".reports/", ".lighthouse/"] },
  js.configs.recommended,
  ...ts.configs.recommended,
  ...astro.configs.recommended,
  ...svelte.configs.recommended,
  {
    files: ["**/*.svelte", "**/*.svelte.ts"],
    languageOptions: { parserOptions: { parser: ts.parser, extraFileExtensions: [".svelte"] } },
  },
  { languageOptions: { globals: { ...globals.browser, ...globals.node } } },
  // CommonJS config files (Lighthouse CI loads them with require)
  { files: ["**/*.cjs"], rules: { "@typescript-eslint/no-require-imports": "off" } },
  { rules: { "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }] } },
];
