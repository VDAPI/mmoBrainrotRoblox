--!strict
-- Owner's list for the Creator Hub (S131, DESIGN-17 §9): `lune run tools/shop_report.luau` writes docs/SKLEP-ID.md
-- from Data/Products (every Developer Product, pass and subscription with its kind, proposed Robux price, what it gives,
-- where to paste its id and its state) plus the price review of tests/Pricing.luau. `--check` compares with the file
-- and exits 1 on a difference (tests/premium.spec checks that every product key is in the file). The file stays in
-- the repository and never goes to the wiki; it holds no real ids (0 / "" until the owner pastes them).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Config = require("../src/shared/Config")
local Locale = require("../src/shared/Util/Locale")
local Pricing = require("../tests/Pricing")
local Products = require("../src/shared/Data/Products")
local UiArt = require("../src/shared/Logic/UiArt")

local OUT = "docs/SKLEP-ID.md"

local function pl(key: string, args: { [string]: any }?): string
	if Locale.has(key, "pl") then
		return Locale.T(key, args, "pl")
	end
	return key
end

local function num(n: number): string
	local whole = math.floor(n)
	local s = tostring(whole)
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	out = (string.gsub(out, "^%s+", ""))
	local frac = n - whole
	if frac > 0.004 then
		out ..= "," .. string.format("%02d", math.floor(frac * 100 + 0.5))
	end
	return out
end

local function idState(id: number | string, enabled: boolean?): string
	if enabled == false then
		return "wyłączony (`enabled = false`)"
	end
	if id == 0 or id == "" then
		return "bez id: „Wkrótce” na żywym serwerze"
	end
	return "gotowy"
end

-- W28: the icon for the Creator Hub: the owner's picture behind the shop card (art/ui/ui_art.json `src`, a path in
-- the Graphics folder); the same picture is in the shop atlas art/ui/ui_shop_0N.png.
local artCells: { [string]: any } = {}
if fs.isFile("art/ui/ui_art.json") then
	local decoded = serde.decode("json", fs.readFile("art/ui/ui_art.json"))
	artCells = if type(decoded) == "table" and type(decoded.cells) == "table" then decoded.cells else {}
end
local function icon(key: string): string
	local cell = artCells[UiArt.shop(key)]
	if type(cell) == "table" and type(cell.src) == "string" then
		return `\`Graphics/{cell.src}\``
	end
	return "brak obrazka (512×512 do zrobienia)"
end

local lines: { string } = {}
local function add(line: string?)
	table.insert(lines, line or "")
end

add("# Sklep: lista id do Creator Hub")
add()
add("> Plik generowany przez tools/shop_report.luau (S131). Nie edytuj ręcznie, uruchom narzędzie.")
add("> Odśwież: `lune run tools/shop_report.luau`; sprawdzenie: `lune run tools/shop_report.luau --check`.")
add('> Plik nigdy nie trafia na wiki. Nie zawiera prawdziwych id: dopóki w `Data/Products` jest `0` / `""`,')
add("> gra na żywym serwerze pokazuje „Wkrótce”, a w Studio zakup jest symulowany.")
add()
add("## 1. Co zrobić w Creator Hub (krok po kroku)")
add()
add("Raz na początek:")
add()
add("1. Opublikuj grę (Studio: File → Publish to Roblox), jeśli jeszcze nie jest opublikowana.")
add("2. Otwórz https://create.roblox.com → Creations → gra Vaelthorn → **Monetization** (menu po lewej).")
add()
add("**Przepustki (Game Pass)**, każdy wiersz „Game Pass” z tabeli w punkcie 2:")
add()
add("1. Monetization → **Passes** → „Create a Pass”.")
add("2. Ikona: plik z kolumny „Ikona” (folder Graphics; kwadrat, Roblox przytnie do koła), nazwa z kolumny")
add("   „Nazwa (PL)”, opis z kolumny „Co daje”. Zapisz („Create Pass”).")
add(
	"3. Otwórz nową przepustkę → **Sales** → włącz „Item for Sale”, wpisz cenę z kolumny „Proponowana cena”, zapisz."
)
add("4. Skopiuj id: menu ⋯ przy przepustce → „Copy Asset ID” (albo liczba w adresie strony).")
add("5. Wklej id w `src/shared/Data/Products.luau` w miejsce z kolumny „Gdzie wkleić id” (np. `passId = 0` →")
add("   `passId = 123456789` w wierszu z tym kluczem).")
add()
add("**Produkty (Developer Product)**, każdy wiersz „Developer Product”:")
add()
add("1. Monetization → **Developer Products** → „Create a Developer Product”.")
add("2. Ikona z kolumny „Ikona”, nazwa, opis, cena z kolumny „Proponowana cena”. Zapisz.")
add(
	"3. Id: menu ⋯ przy produkcie → „Copy Asset ID”. Wklej w `productId` w miejscu z kolumny „Gdzie wkleić id”."
)
add()
add("**Subskrypcja VIP** (wiersz „Subscription”):")
add()
add("1. Monetization → **Subscriptions** → „Create Subscription”; opis korzyści jak w oknie VIP w grze.")
add("2. Cena tylko z progów Roblox: wybierz próg najbliższy propozycji. Ikona z kolumny „Ikona”.")
add('3. Id ma postać `EXP-...`: wklej jako tekst w `subscriptionId = ""` (w cudzysłowie).')
add(
	"   Nazwy zakładek wg dokumentacji Roblox znanej w sesji S131 (2026-10); jeśli się różnią, szukaj „Subscriptions”."
)
add()
add("Na koniec:")
add()
add("1. `scripts/check` (albo `bash scripts/check.sh`) i `lune run tools/shop_report.luau`: kolumna „Stan” pokaże")
add("   „gotowy” przy każdym wklejonym id.")
add(
	"2. Commit, w Studio Rojo sync, File → Publish to Roblox. Od tej chwili na żywym serwerze zamiast „Wkrótce”"
)
add("   jest przycisk z ceną i prawdziwe okno zakupu Roblox.")
add("3. Zakupu za prawdziwe Robux nie trzeba robić do testu: w Studio wszystko działa jako zakup testowy (punkt 1a).")
add()
add("## 1a. Testy zakupów w Studio")
add()
add('- W Studio (Play) przyciski Robux nigdy nie pokazują „Wkrótce”: id `0` / `""` daje zakup symulowany bez')
add(
	"  płacenia (`MonetizationService`, tylko `RunService:IsStudio()`); na żywym serwerze id `0` jest zawsze odmawiane."
)
add("- Paczki waluty dodają odłamki od razu; przepustki działają od razu (Auto-łup podnosi worki, Skarbiec,")
add("  Kieszenie, miejsca na postać, Garderoba+); VIP z subskrypcji włącza się na tę sesję.")
add(
	"- Przepustki i VIP z symulacji trzymają się do końca sesji Play (nie są zapisywane), tak jak `/pass <klucz> on`"
)
add("  i `/vip on`. Na stałe w profilu: `/premium grant <klucz>`, `/vip grant`.")
add(
	"- Smocze Odłamki do testów: przycisk „+1000 ◆ (Studio)” w nagłówku Smoczego Sklepu (widoczny tylko w Studio)"
)
add("  albo `/shards <ile>` i `/setshards <ile>` (panel F2, zakładka ekonomii).")
add()
add("## 2. Produkty, przepustki i subskrypcja")
add()
add("| Klucz | Nazwa (PL) | Rodzaj | Proponowana cena | Co daje | Ikona | Gdzie wkleić id | Stan |")
add("|---|---|---|---|---|---|---|---|")
for i, pack in Products.shardPacks do
	add(
		`| \`{pack.key}\` | {num(pack.shards)} Smoczej Waluty | Developer Product | {num(pack.robux)} R$ | Smocza Waluta na konto | {icon(
			pack.key
		)} | \`SHARD_PACKS[{i}].productId\` | {idState(pack.productId)} |`
	)
end
for i, pass in Products.passes do
	add(
		`| \`{pass.key}\` | {pl(`premium.pass.{pass.key}`)} | Game Pass | {num(pass.robux)} R$ | {pl(
			`premium.pass.{pass.key}.desc`
		)} | {icon(pass.key)} | \`PASSES[{i}].passId\` | {idState(pass.passId, pass.enabled)} |`
	)
end
for i, sub in Products.subscriptions do
	add(
		`| \`{sub.key}\` (subskrypcja) | {pl(`premium.sub.{sub.key}`)} | Subscription | ok. {num(
			Pricing.PROPOSED.vipSubscription
		)} R$ / mies. (próg Roblox) | {pl(`premium.sub.{sub.key}.desc`)} | {icon(sub.key)} | \`SUBSCRIPTIONS[{i}].subscriptionId\` | {idState(
			sub.subscriptionId,
			sub.enabled
		)} |`
	)
end
for i, pack in Products.starterPacks do
	add(
		`| \`{pack.key}\` | {pl(`premium.pack.{pack.key}`)} | Developer Product (raz na konto) | {num(pack.robux)} R$ | {pl(
			`premium.pack.{pack.key}.desc`
		)} | {icon(pack.key)} | \`STARTER_PACKS[{i}].productId\` | {idState(pack.productId)} |`
	)
end
for i, mount in Products.mounts do
	add(
		`| \`{mount.key}\` | {pl(`mount.{mount.mount}.name`)} | Developer Product | {if mount.robux > 0
			then `{num(mount.robux)} R$`
			else "do decyzji"} | Wierzchowiec premium (szybkość jak każdy wierzchowiec) | {icon(mount.key)} | \`MOUNTS[{i}].productId\` | {idState(
			mount.productId,
			mount.enabled
		)} |`
	)
end
add()
add("Ceny za Smoczą Walutę (sklep, garderoba) są w grze (`Data/Products.shop`, `Data/Cosmetics`); w Creator Hub nic")
add("się dla nich nie ustawia.")
add(
	`Przepustka sezonu (\`{Products.seasonPass.key}\`, S152) to ścieżka premium kupowana raz na sezon za {num(
		Products.seasonPass.price
	)}`
)
add("Smoczej Waluty (`Data/Products.seasonPass`): bez własnego produktu Robux, w Creator Hub nic do utworzenia.")
add(
	`Natychmiastowe odrodzenie na ekranie śmierci kosztuje {num(Config.RespawnNowCost)} Smoczej Waluty (\`Config.RespawnNowCost\`, W28):`
)
add("bez produktu Robux, w Creator Hub nic do utworzenia (stary produkt `respawn` za 15 R$ usunięty).")
add()
add("## 3. Wyłączone do decyzji właściciela")
add()
add(
	"- **„VIP na zawsze”** (przepustka `vip`, `enabled = false`): dawałaby dzienne Smocze Odłamki bez końca. Domyślnie"
)
add(
	"  wyłączona. Włączenie: utwórz przepustkę, wklej `passId`, ustaw `enabled = true` (albo usuń pole) i sprawdź cenę."
)
add("- **Wierzchowiec premium** `mount_royal` (`Products.mounts`, `enabled = false`, S97): domyślnie wyłączony.")
add("  Włączenie: cena w R$ (`robux`), produkt w Creator Hub, `productId`, `enabled = true`.")
add()
add("## 4. Poza sklepem")
add()
add("- **Premium Payouts**: działają same (czas gry graczy Premium), nic do ustawienia.")
add(
	`- **Prywatne serwery**: cena w ustawieniach gry (Monetization → Private Servers), propozycja {num(
		Pricing.PROPOSED.privateServer
	)} R$ / mies.`
)
add(
	"- **Rankingi na wiki** (S125, opcjonalnie): sekret repozytorium GitHub `ROBLOX_OPEN_CLOUD_KEY` (Settings → Secrets"
)
add(
	"  and variables → Actions) z kluczem Open Cloud z uprawnieniami odczytu Ordered Data Stores, Data Stores i Memory"
)
add(
	"  Stores tej gry, oraz zmienna `ROBLOX_UNIVERSE_ID` (szczegóły: `docs/WIKI.md` → „Rankingi (S125)”). Bez sekretu"
)
add("  strona wiki pokazuje „ranking dostępny w grze”. Wartości klucza nigdy nie wpisuj do repozytorium.")
add(
	"- **Testy w Studio**: Game Settings → Security → „Enable Studio Access to API Services”, żeby rankingi, kolejka"
)
add("  areny i zapisy turnieju używały prawdziwych magazynów (bez tego tryb „tylko ten serwer”).")
add("- **Teleporty** na serwery areny i turnieju (S127, S130) działają tylko w opublikowanej grze, nie w Studio.")
add()
add("## 5. Przegląd cen")
add()
add("### Paczki Smoczej Waluty")
add()
add("| Paczka | Odłamki | R$ | Odłamki na 1 R$ | Premia wobec najmniejszej |")
add("|---|---|---|---|---|")
for _, r in Pricing.packRates() do
	add(`| \`{r.key}\` | {num(r.shards)} | {num(r.robux)} | {num(r.perRobux)} | {num(r.bonusPct)}% |`)
end
add()
add("### Sklep za Smoczą Walutę (koszt w R$ przy najlepszym / najgorszym kursie paczki)")
add()
add("| Wpis | Sekcja | Cena | Za sztukę | R$ (najtaniej) | R$ (najdrożej) | Limit |")
add("|---|---|---|---|---|---|---|")
for _, row in Pricing.shopTable() do
	add(
		`| \`{row.key}\` | {row.cat} | {num(row.so)} | {if row.perUnit then num(row.perUnit) else "-"} | {num(
			row.robuxCheap
		)} | {num(row.robuxDear)} | {row.limit or "-"} |`
	)
end
add()
add("### Kosmetyki za Smoczą Walutę (przedziały cen wg rodzaju)")
add()
add("| Rodzaj | Sztuk | Min | Mediana | Max | Max w R$ (najdrożej) |")
add("|---|---|---|---|---|---|")
for _, r in Pricing.cosmeticRanges() do
	add(`| {r.kind} | {r.n} | {num(r.min)} | {num(r.median)} | {num(r.max)} | {num(Pricing.robuxOf(r.max).dearest)} |`)
end
add()
local vip = Pricing.vipMonth(Pricing.PROPOSED.vipSubscription)
add("### VIP")
add()
add(
	`Miesiąc VIP (30 dni × {Config.Vip.dailyShards}) daje {num(vip.so)} Smoczej Waluty, czyli {num(
		vip.robuxValueCheap
	)}–{num(vip.robuxValueDear)} R$ według kursu paczek, wobec proponowanej ceny {num(
		Pricing.PROPOSED.vipSubscription
	)} R$ / mies.`
)
add(`(stosunek przy najdroższym kursie: {num(vip.ratio)}). Do tego wygoda i kosmetyk miesiąca.`)
add()
add("### Paczki startowe")
add()
add("| Paczka | R$ | Odłamki | Wartość odłamków w R$ (kurs najmniejszej paczki) | Dodatki |")
add("|---|---|---|---|---|")
for _, p in Pricing.starterPacks() do
	add(`| \`{p.key}\` | {num(p.robux)} | {num(p.so)} | {num(p.soValueRobux)} | {p.extras} |`)
end
add()
add("### Do decyzji właściciela (domyślnie zostaje jak w kodzie)")
add()
do
	local fast = Products.getPass("fastRespawn")
	local robux = if fast then num(fast.robux) else "?"
	add(
		`- Szybki Powrót (\`fastRespawn\`) kosztuje w kodzie {robux} R$, KATALOG podawał 149 R$: domyślnie {robux} R$.`
	)
end
add(
	`- Miesiąc VIP oddaje w dziennej Smoczej Walucie {num(vip.robuxValueCheap)}–{num(vip.robuxValueDear)} R$ wartości paczek`
)
add(
	`  przy proponowanej cenie {num(Pricing.PROPOSED.vipSubscription)} R$: domyślnie bez zmian (\`Config.Vip.dailyShards\` = {Config.Vip.dailyShards}).`
)
do
	local ratios: { string } = {}
	for _, p in Pricing.starterPacks() do
		table.insert(ratios, `{p.key} ×{num(p.soValueRobux / p.robux)}`)
	end
	add(
		`- Paczki startowe dają odłamki warte więcej niż ich cena ({table.concat(ratios, ", ")} wobec kursu najmniejszej paczki),`
	)
	add("  raz na konto, plus kosmetyki i przepustka: celowo jako oferta na start, domyślnie bez zmian.")
end
add("- „VIP na zawsze” i wierzchowiec premium: punkt 3 (domyślnie wyłączone).")

local text = table.concat(lines, "\n") .. "\n"

if table.find(process.args, "--check") then
	local current = if fs.isFile(OUT) then fs.readFile(OUT) else ""
	if current ~= text then
		print(`shop_report: {OUT} is out of date (run lune run tools/shop_report.luau)`)
		process.exit(1)
	end
	print(`shop_report: {OUT} is up to date`)
	return
end

fs.writeFile(OUT, text)
print(`shop_report: wrote {OUT} ({#lines} lines)`)
