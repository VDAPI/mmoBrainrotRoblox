# Sklep: lista id do Creator Hub

> Plik generowany przez tools/shop_report.luau (S131). Nie edytuj ręcznie, uruchom narzędzie.
> Odśwież: `lune run tools/shop_report.luau`; sprawdzenie: `lune run tools/shop_report.luau --check`.
> Plik nigdy nie trafia na wiki. Nie zawiera prawdziwych id: dopóki w `Data/Products` jest `0` / `""`,
> gra na żywym serwerze pokazuje „Wkrótce”, a w Studio zakup jest symulowany.

## 1. Co zrobić w Creator Hub (krok po kroku)

Raz na początek:

1. Opublikuj grę (Studio: File → Publish to Roblox), jeśli jeszcze nie jest opublikowana.
2. Otwórz https://create.roblox.com → Creations → gra Vaelthorn → **Monetization** (menu po lewej).

**Przepustki (Game Pass)**, każdy wiersz „Game Pass” z tabeli w punkcie 2:

1. Monetization → **Passes** → „Create a Pass”.
2. Ikona: plik z kolumny „Ikona” (folder Graphics; kwadrat, Roblox przytnie do koła), nazwa z kolumny
   „Nazwa (PL)”, opis z kolumny „Co daje”. Zapisz („Create Pass”).
3. Otwórz nową przepustkę → **Sales** → włącz „Item for Sale”, wpisz cenę z kolumny „Proponowana cena”, zapisz.
4. Skopiuj id: menu ⋯ przy przepustce → „Copy Asset ID” (albo liczba w adresie strony).
5. Wklej id w `src/shared/Data/Products.luau` w miejsce z kolumny „Gdzie wkleić id” (np. `passId = 0` →
   `passId = 123456789` w wierszu z tym kluczem).

**Produkty (Developer Product)**, każdy wiersz „Developer Product”:

1. Monetization → **Developer Products** → „Create a Developer Product”.
2. Ikona z kolumny „Ikona”, nazwa, opis, cena z kolumny „Proponowana cena”. Zapisz.
3. Id: menu ⋯ przy produkcie → „Copy Asset ID”. Wklej w `productId` w miejscu z kolumny „Gdzie wkleić id”.

**Subskrypcja VIP** (wiersz „Subscription”):

1. Monetization → **Subscriptions** → „Create Subscription”; opis korzyści jak w oknie VIP w grze.
2. Cena tylko z progów Roblox: wybierz próg najbliższy propozycji. Ikona z kolumny „Ikona”.
3. Id ma postać `EXP-...`: wklej jako tekst w `subscriptionId = ""` (w cudzysłowie).
   Nazwy zakładek wg dokumentacji Roblox znanej w sesji S131 (2026-10); jeśli się różnią, szukaj „Subscriptions”.

Na koniec:

1. `scripts/check` (albo `bash scripts/check.sh`) i `lune run tools/shop_report.luau`: kolumna „Stan” pokaże
   „gotowy” przy każdym wklejonym id.
2. Commit, w Studio Rojo sync, File → Publish to Roblox. Od tej chwili na żywym serwerze zamiast „Wkrótce”
   jest przycisk z ceną i prawdziwe okno zakupu Roblox.
3. Zakupu za prawdziwe Robux nie trzeba robić do testu: w Studio wszystko działa jako zakup testowy (punkt 1a).

## 1a. Testy zakupów w Studio

- W Studio (Play) przyciski Robux nigdy nie pokazują „Wkrótce”: id `0` / `""` daje zakup symulowany bez
  płacenia (`MonetizationService`, tylko `RunService:IsStudio()`); na żywym serwerze id `0` jest zawsze odmawiane.
- Paczki waluty dodają odłamki od razu; przepustki działają od razu (Auto-łup podnosi worki, Skarbiec,
  Kieszenie, miejsca na postać, Garderoba+); VIP z subskrypcji włącza się na tę sesję.
- Przepustki i VIP z symulacji trzymają się do końca sesji Play (nie są zapisywane), tak jak `/pass <klucz> on`
  i `/vip on`. Na stałe w profilu: `/premium grant <klucz>`, `/vip grant`.
- Smocze Odłamki do testów: przycisk „+1000 ◆ (Studio)” w nagłówku Smoczego Sklepu (widoczny tylko w Studio)
  albo `/shards <ile>` i `/setshards <ile>` (panel F2, zakładka ekonomii).

## 2. Produkty, przepustki i subskrypcja

| Klucz | Nazwa (PL) | Rodzaj | Proponowana cena | Co daje | Ikona | Gdzie wkleić id | Stan |
|---|---|---|---|---|---|---|---|
| `shards_100` | 100 Smoczej Waluty | Developer Product | 99 R$ | Smocza Waluta na konto | `Graphics/tylko_2d/sklep/shards_100.png` | `SHARD_PACKS[1].productId` | bez id: „Wkrótce” na żywym serwerze |
| `shards_550` | 550 Smoczej Waluty | Developer Product | 499 R$ | Smocza Waluta na konto | `Graphics/tylko_2d/sklep/shards_550.png` | `SHARD_PACKS[2].productId` | bez id: „Wkrótce” na żywym serwerze |
| `shards_1200` | 1 200 Smoczej Waluty | Developer Product | 999 R$ | Smocza Waluta na konto | `Graphics/tylko_2d/sklep/shards_1200.png` | `SHARD_PACKS[3].productId` | bez id: „Wkrótce” na żywym serwerze |
| `shards_2600` | 2 600 Smoczej Waluty | Developer Product | 1 999 R$ | Smocza Waluta na konto | `Graphics/tylko_2d/sklep/shards_2600.png` | `SHARD_PACKS[4].productId` | bez id: „Wkrótce” na żywym serwerze |
| `shards_7000` | 7 000 Smoczej Waluty | Developer Product | 4 999 R$ | Smocza Waluta na konto | `Graphics/tylko_2d/sklep/shards_7000.png` | `SHARD_PACKS[5].productId` | bez id: „Wkrótce” na żywym serwerze |
| `autoLoot` | Auto-łup | Game Pass | 199 R$ | Worki z łupem w promieniu 15 st. podnoszą się same. | `Graphics/tylko_2d/sklep/pass_autoLoot.png` | `PASSES[1].passId` | bez id: „Wkrótce” na żywym serwerze |
| `vault` | Skarbiec | Game Pass | 149 R$ | +60 miejsc w depozycie konta. | `Graphics/tylko_2d/sklep/pass_vault.png` | `PASSES[2].passId` | bez id: „Wkrótce” na żywym serwerze |
| `fastRespawn` | Szybki Powrót | Game Pass | 99 R$ | Czas odrodzenia o połowę krótszy. | `Graphics/tylko_2d/sklep/pass_fastRespawn.png` | `PASSES[3].passId` | bez id: „Wkrótce” na żywym serwerze |
| `vip` | VIP na zawsze | Game Pass | 399 R$ | Wszystkie korzyści VIP bez subskrypcji. | `Graphics/tylko_2d/sklep/pass_vip.png` | `PASSES[4].passId` | wyłączony (`enabled = false`) |
| `pockets` | Kieszenie Kupca | Game Pass | 249 R$ | +10 miejsc w każdym plecaku, także w tym, który dopiero zdobędziesz. | `Graphics/tylko_2d/sklep/pass_pockets.png` | `PASSES[5].passId` | bez id: „Wkrótce” na żywym serwerze |
| `slot4` | Miejsce na postać 4 | Game Pass | 99 R$ | Czwarte miejsce na postać na koncie. | `Graphics/tylko_2d/sklep/pass_slot4.png` | `PASSES[6].passId` | bez id: „Wkrótce” na żywym serwerze |
| `slot5` | Miejsce na postać 5 | Game Pass | 149 R$ | Piąte miejsce na postać. Wymaga miejsca 4. | `Graphics/tylko_2d/sklep/pass_slot5.png` | `PASSES[7].passId` | bez id: „Wkrótce” na żywym serwerze |
| `wardrobePlus` | Garderoba+ | Game Pass | 79 R$ | Pięć zapisanych zestawów wyglądu zamiast jednego. | `Graphics/tylko_2d/sklep/pass_wardrobePlus.png` | `PASSES[8].passId` | bez id: „Wkrótce” na żywym serwerze |
| `vip` (subskrypcja) | VIP (subskrypcja miesięczna) | Subscription | ok. 349 R$ / mies. (próg Roblox) | Codzienna Smocza Waluta, wygoda i kosmetyk co miesiąc. Bez przewagi w walce. | `Graphics/tylko_2d/sklep/pass_vip.png` | `SUBSCRIPTIONS[1].subscriptionId` | bez id: „Wkrótce” na żywym serwerze |
| `starter_wanderer` | Paczka Wędrowca | Developer Product (raz na konto) | 199 R$ | Na pierwszą drogę: Smocza Waluta, płaszcz wędrowca z peleryną i wierny chart. | brak obrazka (512×512 do zrobienia) | `STARTER_PACKS[1].productId` | bez id: „Wkrótce” na żywym serwerze |
| `starter_hero` | Paczka Bohatera | Developer Product (raz na konto) | 799 R$ | Dużo Smoczej Waluty, Aura Męstwa i Kieszenie Kupca na zawsze. | brak obrazka (512×512 do zrobienia) | `STARTER_PACKS[2].productId` | bez id: „Wkrótce” na żywym serwerze |
| `mount_royal` | Królewski Rumak | Developer Product | do decyzji | Wierzchowiec premium (szybkość jak każdy wierzchowiec) | brak obrazka (512×512 do zrobienia) | `MOUNTS[1].productId` | wyłączony (`enabled = false`) |

Ceny za Smoczą Walutę (sklep, garderoba) są w grze (`Data/Products.shop`, `Data/Cosmetics`); w Creator Hub nic
się dla nich nie ustawia.
Przepustka sezonu (`season_pass`, S152) to ścieżka premium kupowana raz na sezon za 800
Smoczej Waluty (`Data/Products.seasonPass`): bez własnego produktu Robux, w Creator Hub nic do utworzenia.
Natychmiastowe odrodzenie na ekranie śmierci kosztuje 5 Smoczej Waluty (`Config.RespawnNowCost`, W28):
bez produktu Robux, w Creator Hub nic do utworzenia (stary produkt `respawn` za 15 R$ usunięty).

## 3. Wyłączone do decyzji właściciela

- **„VIP na zawsze”** (przepustka `vip`, `enabled = false`): dawałaby dzienne Smocze Odłamki bez końca. Domyślnie
  wyłączona. Włączenie: utwórz przepustkę, wklej `passId`, ustaw `enabled = true` (albo usuń pole) i sprawdź cenę.
- **Wierzchowiec premium** `mount_royal` (`Products.mounts`, `enabled = false`, S97): domyślnie wyłączony.
  Włączenie: cena w R$ (`robux`), produkt w Creator Hub, `productId`, `enabled = true`.

## 4. Poza sklepem

- **Premium Payouts**: działają same (czas gry graczy Premium), nic do ustawienia.
- **Prywatne serwery**: cena w ustawieniach gry (Monetization → Private Servers), propozycja 100 R$ / mies.
- **Rankingi na wiki** (S125, opcjonalnie): sekret repozytorium GitHub `ROBLOX_OPEN_CLOUD_KEY` (Settings → Secrets
  and variables → Actions) z kluczem Open Cloud z uprawnieniami odczytu Ordered Data Stores, Data Stores i Memory
  Stores tej gry, oraz zmienna `ROBLOX_UNIVERSE_ID` (szczegóły: `docs/WIKI.md` → „Rankingi (S125)”). Bez sekretu
  strona wiki pokazuje „ranking dostępny w grze”. Wartości klucza nigdy nie wpisuj do repozytorium.
- **Testy w Studio**: Game Settings → Security → „Enable Studio Access to API Services”, żeby rankingi, kolejka
  areny i zapisy turnieju używały prawdziwych magazynów (bez tego tryb „tylko ten serwer”).
- **Teleporty** na serwery areny i turnieju (S127, S130) działają tylko w opublikowanej grze, nie w Studio.

## 5. Przegląd cen

### Paczki Smoczej Waluty

| Paczka | Odłamki | R$ | Odłamki na 1 R$ | Premia wobec najmniejszej |
|---|---|---|---|---|
| `shards_100` | 100 | 99 | 1,01 | 0% |
| `shards_550` | 550 | 499 | 1,10 | 9,12% |
| `shards_1200` | 1 200 | 999 | 1,20 | 18,92% |
| `shards_2600` | 2 600 | 1 999 | 1,30 | 28,76% |
| `shards_7000` | 7 000 | 4 999 | 1,40 | 38,63% |

### Sklep za Smoczą Walutę (koszt w R$ przy najlepszym / najgorszym kursie paczki)

| Wpis | Sekcja | Cena | Za sztukę | R$ (najtaniej) | R$ (najdrożej) | Limit |
|---|---|---|---|---|---|---|
| `scroll_oblivion` | scroll | 120 | - | 85,70 | 118,80 | - |
| `scroll_skillreset` | scroll | 120 | - | 85,70 | 118,80 | - |
| `scroll_unbind` | scroll | 150 | - | 107,12 | 148,50 | - |
| `scroll_protection` | scroll | 60 | - | 42,85 | 59,40 | 1/dzień |
| `reroll_stone` | scroll | 100 | - | 71,41 | 99 | 10/dzień |
| `effect_stone` | scroll | 100 | - | 71,41 | 99 | 10/dzień |
| `transmute_scroll` | scroll | 240 | - | 171,39 | 237,60 | 1/dzień |
| `rename` | service | 400 | - | 285,66 | 396 | - |
| `backpack_premium_100` | backpack | 300 | - | 214,24 | 297 | - |
| `backpack_premium_150` | backpack | 600 | - | 428,49 | 594 | - |
| `backpack_premium_200` | backpack | 1 000 | - | 714,14 | 990 | - |
| `potion_full_5` | consumable | 120 | 24 | 85,70 | 118,80 | - |
| `potion_full_20` | consumable | 400 | 20 | 285,66 | 396 | - |
| `lure_1h` | service | 150 | - | 107,12 | 148,50 | - |
| `lure_7d` | service | 990 | - | 707 | 980,10 | - |
| `autopotion_1d` | service | 60 | - | 42,85 | 59,40 | - |
| `autopotion_7d` | service | 250 | - | 178,54 | 247,50 | - |
| `autopotion_perm` | service | 800 | - | 571,31 | 792 | - |
| `hunt_1h` | service | 100 | - | 71,41 | 99 | - |
| `hunt_5h` | service | 420 | - | 299,94 | 415,80 | - |
| `hunt_24h` | service | 1 500 | - | 1 071,21 | 1 485 | - |
| `season_pass` | season | 800 | - | 571,31 | 792 | 1/sezon |

### Kosmetyki za Smoczą Walutę (przedziały cen wg rodzaju)

| Rodzaj | Sztuk | Min | Mediana | Max | Max w R$ (najdrożej) |
|---|---|---|---|---|---|
| outfit | 20 | 300 | 600 | 900 | 891 |
| aura | 4 | 500 | 500 | 650 | 643,50 |
| trail | 2 | 250 | 250 | 250 | 247,50 |
| weapon | 3 | 400 | 400 | 500 | 495 |
| pet | 6 | 400 | 600 | 1 200 | 1 188 |
| mountskin | 4 | 350 | 500 | 900 | 891 |
| dye | 6 | 30 | 30 | 60 | 59,40 |
| frame | 5 | 100 | 200 | 300 | 297 |
| chatframe | 4 | 100 | 150 | 250 | 247,50 |
| title | 5 | 100 | 200 | 250 | 247,50 |
| emote | 6 | 50 | 80 | 120 | 118,80 |
| levelup | 4 | 250 | 350 | 400 | 396 |

### VIP

Miesiąc VIP (30 dni × 15) daje 450 Smoczej Waluty, czyli 321,36–445,50 R$ według kursu paczek, wobec proponowanej ceny 349 R$ / mies.
(stosunek przy najdroższym kursie: 1,28). Do tego wygoda i kosmetyk miesiąca.

### Paczki startowe

| Paczka | R$ | Odłamki | Wartość odłamków w R$ (kurs najmniejszej paczki) | Dodatki |
|---|---|---|---|---|
| `starter_wanderer` | 199 | 500 | 495 | outfit_wayfarer, pet_hound |
| `starter_hero` | 799 | 2 200 | 2 178 | aura_valor, pass:pockets |

### Do decyzji właściciela (domyślnie zostaje jak w kodzie)

- Szybki Powrót (`fastRespawn`) kosztuje w kodzie 99 R$, KATALOG podawał 149 R$: domyślnie 99 R$.
- Miesiąc VIP oddaje w dziennej Smoczej Walucie 321,36–445,50 R$ wartości paczek
  przy proponowanej cenie 349 R$: domyślnie bez zmian (`Config.Vip.dailyShards` = 15).
- Paczki startowe dają odłamki warte więcej niż ich cena (starter_wanderer ×2,49, starter_hero ×2,73 wobec kursu najmniejszej paczki),
  raz na konto, plus kosmetyki i przepustka: celowo jako oferta na start, domyślnie bez zmian.
- „VIP na zawsze” i wierzchowiec premium: punkt 3 (domyślnie wyłączone).
