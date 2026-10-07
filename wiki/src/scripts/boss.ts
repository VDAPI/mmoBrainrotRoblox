// Boss page behaviour (S39): player chips 1–5 swap every [data-by-players] value (JSON list of 5 texts; the HP bar
// label too) and mark the row of the party size; phase tabs show their panel and the phase render when it exists.
import { tabs } from "./tabs";

const header = document.querySelector<HTMLElement>("[data-boss]");
if (header) init(header);

function init(boss: HTMLElement) {
  const chips = [...boss.querySelectorAll<HTMLButtonElement>("[data-players]")];
  const pick = (players: number) => {
    for (const c of chips) c.setAttribute("aria-pressed", String(Number(c.dataset.players) === players));
    for (const el of document.querySelectorAll<HTMLElement>("[data-by-players]")) {
      const values = JSON.parse(el.dataset.byPlayers ?? "[]") as string[];
      const text = values[players - 1];
      if (text === undefined) continue;
      if (el.dataset.target === "label") {
        const bar = el.querySelector<HTMLElement>(".vw-bar");
        bar?.setAttribute("aria-label", text);
        const span = bar?.querySelector("span");
        if (span) span.textContent = text;
      } else {
        el.textContent = text;
      }
    }
    for (const row of document.querySelectorAll<HTMLElement>("[data-players-row]")) {
      row.toggleAttribute("data-selected", Number(row.dataset.playersRow) === players);
    }
  };
  for (const c of chips) c.addEventListener("click", () => pick(Number(c.dataset.players)));

  const list = boss.querySelector<HTMLElement>("[role=tablist]");
  const img = boss.querySelector<HTMLImageElement>(".picture img");
  const srcset = img?.getAttribute("srcset") ?? null;
  if (list) {
    tabs(list, (tab) => {
      const id = tab.getAttribute("aria-controls");
      for (const p of boss.querySelectorAll<HTMLElement>("[role=tabpanel]")) p.toggleAttribute("data-active", p.id === id);
      const src = tab.dataset.src;
      if (img && src) {
        const first = tab === list.querySelector("[role=tab]");
        img.src = src;
        if (first && srcset) img.setAttribute("srcset", srcset);
        else img.removeAttribute("srcset");
      }
    });
  }
}
