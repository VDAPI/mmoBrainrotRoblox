// Accessible tabs (S39): role="tab" buttons in a role="tablist", arrows / Home / End move and select, the selected
// tab has aria-selected="true" and tabindex 0. Returns the select function (for selecting from the URL).
export function tabs(list: HTMLElement, onSelect: (tab: HTMLElement) => void): (tab: HTMLElement) => void {
  const all = () => [...list.querySelectorAll<HTMLElement>("[role=tab]")];
  const select = (tab: HTMLElement, focus = false) => {
    for (const t of all()) {
      const on = t === tab;
      t.setAttribute("aria-selected", String(on));
      t.tabIndex = on ? 0 : -1;
    }
    if (focus) tab.focus();
    onSelect(tab);
  };
  for (const tab of all()) tab.addEventListener("click", () => select(tab));
  list.addEventListener("keydown", (ev) => {
    const items = all();
    const i = items.indexOf(document.activeElement as HTMLElement);
    if (i < 0) return;
    const next = { ArrowRight: i + 1, ArrowDown: i + 1, ArrowLeft: i - 1, ArrowUp: i - 1, Home: 0, End: items.length - 1 }[ev.key];
    if (next === undefined) return;
    ev.preventDefault();
    select(items[(next + items.length) % items.length], true);
  });
  return (tab) => select(tab);
}
