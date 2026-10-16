// Boss page behaviour (S39): phase tabs show their panel and the phase render when it exists. S134: the player chips
// 1–5 are gone (one HP for every party).
import { tabs } from "./tabs";

const header = document.querySelector<HTMLElement>("[data-boss]");
if (header) init(header);

function init(boss: HTMLElement) {
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
