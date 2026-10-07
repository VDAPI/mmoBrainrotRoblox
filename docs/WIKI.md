# Vaelthorn Wiki: decyzje, kontrakt i stan

Oficjalna wiki gry w folderze `wiki/` tego repozytorium. Ten plik jest źródłem prawdy dla sesji wiki (S34, S36–S44): każda sesja zaczyna od jego lektury i kończy aktualizacją sekcji **Stan**, **Decyzje** i **Niedokończone**. Zasady gry dalej opisuje `docs/DESIGN.md`.

## 0. Zasada główna: wiki generowana z danych gry

- **Tabel potworów, przedmiotów, umiejętności, questów i map nie piszemy ręcznie.** Liczby są w `src/shared/Data/*`, wzory w `src/shared/Logic/*`; oba działają w Lune. Eksporter `tools/wikidump.luau` zrzuca je do `wiki/src/data/*.json`, licząc wartości funkcjami z `Logic` (statystyki potwora na poziomie, szanse i koszty ulepszania, wartości przedmiotów, szanse łupu). Wiki nie powtarza wzorów w TypeScript.
- **Nazwy i opisy PL/EN** pochodzą z `src/shared/Data/Localization` (przez `Util/Locale`), więc wiki jest dwujęzyczna od pierwszego dnia. Teksty samego interfejsu wiki („Filtruj”, „Pokaż więcej”) są w `wiki/src/i18n/{pl,en}.ts`.
- **Obrazki** potworów, bossów i petów generuje `tools/wiki-renders` (na bazie `tools/lookdump.luau` i `docs/miasto/tools/render3d.py`); ikony przedmiotów składa skrypt z atlasów S35 (`art/icons`, `Data/ItemIconAtlas`). Mapy to SVG z `Data/Areas`, `Data/Maps`, `Data/Portals` (te same dane co mapa w grze).
- **Podział pracy:** dane i obrazki generuje skrypt; poradniki i lore pisze człowiek w MDX (`wiki/src/content`); wygląd zaprojektowano w Claude Design (`wiki/design/`).

## 1. Bezpieczeństwo: nic, co nie jest publiczne

- Eksporter działa na **allowliście źródeł i pól** (jawna lista modułów `Data/*` i pól każdej encji), nigdy na liście zakazanych.
- Nigdy nie trafiają na wiki: `Data/Codes` (kody nagród), `Data/AdminCommands`, `Logic/DevPreset`, konfiguracja serwera i identyfikatory administratorów z `Config`, ceny w Robux i Smoczej Walucie, id produktów i przepustek. Z `Config` eksporter bierze tylko jawnie wymienione klucze (nigdy `RespawnNowCost`), z `Data/Cosmetics` nigdy `price`.
- `Data/Products` czyta wyłącznie `tools/WikiDump/Premium.luau` (S43) i kopiuje tylko klucze i ikony przepustek oraz listę usług sklepu premium (klucz, rodzaj, przedmiot, limit dzienny); nazwy i opisy idą z lokalizacji. Ceny w złocie mają w JSON klucz `gold`, klucz `price` nie występuje w żadnym pliku.
- Encje oznaczone jako niewydane (`hidden = true` albo `wiki = false` w danych; eksporter dodaje obsługę tych flag tam, gdzie ich jeszcze nie ma) są pomijane razem z linkami do nich.
- `tests/wikidump.spec.luau` wywala się, gdy w wyjściu pojawi się którykolwiek kod z `Data/Codes`, id administratora, klucz spoza allowlisty albo klucz `productId`, `passId`, `robux`, `price`, `shards`, `RespawnNowCost`. Od S44 ten sam skan wycieków przechodzi po zbudowanej stronie (`dist/`).

## 2. Stack

| Element | Wybór | Dlaczego |
|---|---|---|
| Generator | **Astro 5** (`output: "static"`), TypeScript `strict`, MDX, content collections | Najszybsze strony i dobre SEO; JavaScript tylko tam, gdzie jest potrzebny |
| Wyspy interaktywne | **Svelte 5** (`@astrojs/svelte`) | Najmniejszy narzut na stronę (budżet < 50 KB JS poza mapą) |
| Wyszukiwarka | **Pagefind** (`pagefind --site dist` po buildzie), własny interfejs z makiety + paleta Ctrl+K | Pełny tekst offline, bez backendu |
| Mapa | SVG z danych, przesuwanie i zoom: `@panzoom/panzoom` | Bez kafelków, ostra, lekka |
| Wykresy | Czysty SVG (komponenty Astro) | Krzywa EXP, skalowanie statystyk, bez bibliotek |
| Obrazy | WebP generowane skryptami; ikony przedmiotów przez `sharp` (Node) | Działa na Windows bez Pythona |
| Testy TS | Vitest; `astro check`; ESLint | `npm run check` = typy + lint + testy + build |
| Hosting | **Cloudflare Pages**, budowa w GitHub Actions | Za darmo, własna domena, podgląd dla każdego PR |
| Menedżer pakietów | npm, Node 22 LTS | Najprostszy na Windows |

Starlight odpada: wygląda jak dokumentacja techniczna, a wiki ma mieć klimat gry.

## 3. Struktura folderów

```
wiki/
  design/                 eksport z Claude Design (tylko do wglądu, nie importować w kodzie)
    vaelthorn.css         design system „Kuźnia” v1.0: tokeny + klasy komponentów (źródło prawdy wyglądu)
    *.dc.html             makiety stron i komponentów (desktop 1440 + mobile 390)
    vw-data.js            PRZYKŁADOWE dane makiet (do zastąpienia danymi z gry)
    frames/               zrzuty makiet: <Strona>-desktop.jpg, <Strona>-mobile.jpg
    screenshots/          zrzuty design systemu
    README.md             jak oglądać makiety, znane błędy makiet, różnice względem gry
  src/
    data/                 GENEROWANE przez tools/wikidump.luau (commitowane, deterministyczne)
      *.json, types.ts
    styles/
      tokens.css          tokeny 1:1 z design/vaelthorn.css
      tokens.data.css     GENEROWANE: kolory rzadkości, żywiołów, klas i stref z danych gry
      components.css      klasy .vw-* z design/vaelthorn.css
    components/           komponenty Astro (statyczne)
    islands/              komponenty Svelte (interaktywne)
    layouts/              Base.astro (topbar, tabbar mobilny, stopka, meta, hreflang)
    i18n/                 pl.ts, en.ts (teksty interfejsu), routes.ts (segmenty URL)
    lib/                  funkcje TS (formatowanie liczb pl/en, filtry, wyszukiwanie, kalkulator) + testy Vitest
    views/                widoki stron + registry.ts (jeden wpis = nowa strona)
    pages/[lang]/...      trasy (index, [...path] z rejestru, endpointy JSON)
    generated/            GENEROWANE manifesty (np. item-icons.json)
    content/              updates, guides, mechanics ({pl,en}/*.mdx), bosses (opisy mechanik)
  public/img/{mobs,items,maps,og,city}/  GENEROWANE obrazy
  scripts/                data, shots, search-index, check-links, item-icons, og-images, budgets, audit, stale-data (.mjs)
  e2e/                    testy Playwright: dostępność, klawiatura, układ (S44)
  package.json            npm run dev | build | check | data | shots | renders | icons | qa | lighthouse
tools/
  wikidump.luau           CLI eksportera; logika w tools/WikiDump/*.luau (czyste moduły, testowalne)
  wikimap.luau            SVG map z danych; logika w tools/WikiMap/*.luau
  LookDump.luau           wyglądy potworów, bossów i petów do renderów (lookdump.luau --wiki)
  wiki-renders/           rendery potworów, bossów i petów (Python + numpy + Pillow; tylko lokalnie)
scripts/
  wikidump.sh, wikidump.ps1
tests/
  wikidump.spec.luau, wikimap.spec.luau, lookdump.spec.luau
.github/workflows/wiki.yml   build, testy i wdrożenie na Cloudflare Pages (S44)
```

## 4. Adresy stron

Identyfikatory w URL to **id z danych gry** (stabilne między językami, także wielkość liter, np. `/pl/klasy/Mage/`), segmenty sekcji są tłumaczone. Slugi poradników i mechanik są tłumaczone i łączone wspólnym kluczem `key`. `/` przekierowuje do `/pl/` albo `/en/` według języka przeglądarki (domyślnie PL). Każda strona ma `hreflang` do drugiego języka.

| Strona | PL | EN |
|---|---|---|
| Główna | `/pl/` | `/en/` |
| Baza przedmiotów | `/pl/przedmioty/` | `/en/items/` |
| Przedmiot | `/pl/przedmioty/<id>/` | `/en/items/<id>/` |
| Przedmioty bossów | `/pl/przedmioty/bossy/` | `/en/items/bosses/` |
| Bestiariusz | `/pl/bestiariusz/` | `/en/bestiary/` |
| Potwór | `/pl/bestiariusz/<id>/` | `/en/bestiary/<id>/` |
| Bossy, boss | `/pl/bossy/`, `/pl/bossy/<id>/` | `/en/bosses/`, `/en/bosses/<id>/` |
| Klasy, klasa z planerem | `/pl/klasy/`, `/pl/klasy/<classId>/` (`?b=<kod buildu>`) | `/en/classes/`, `/en/classes/<classId>/` |
| Mapa świata | `/pl/mapa/` (`?m=<mapa>&a=<obszar>&x=&z=&s=`) | `/en/map/` |
| Krainy, kraina | `/pl/krainy/`, `/pl/krainy/<mapId>/` | `/en/regions/`, `/en/regions/<mapId>/` |
| Obszar / jaskinia | `/pl/krainy/<mapId>/<areaId>/` | `/en/regions/<mapId>/<areaId>/` |
| Kalkulator ulepszania | `/pl/ulepszanie/` | `/en/upgrading/` |
| Rzemiosło | `/pl/rzemioslo/` (kowal, alchemia, rozbijanie, zbieractwo, ryby) | `/en/crafting/` |
| Zadania | `/pl/zadania/`, `/pl/zadania/<id>/` | `/en/quests/` |
| Mechaniki | `/pl/mechaniki/`, `/pl/mechaniki/<temat>/` | `/en/mechanics/`, `/en/mechanics/<topic>/` |
| Poradniki | `/pl/poradniki/`, `/pl/poradniki/<slug>/` | `/en/guides/`, `/en/guides/<slug>/` |
| Szukaj | `/pl/szukaj/?q=` | `/en/search/?q=` |
| Aktualizacje | `/pl/aktualizacje/` | `/en/updates/` |
| Styleguide (noindex) | `/pl/styleguide/` | `/en/styleguide/` |

## 5. Kontrakt danych (pliki `wiki/src/data`)

Szczegółowy schemat każdej encji uzupełnia S34 (tutaj tylko lista i zasady). Wszystkie pliki: posortowane klucze, liczby zaokrąglone tam, gdzie gra je zaokrągla, nazwy jako `{ pl, en }`, odwołania przez id (bez kopii obiektów), `meta.json` z commitem i datą.

`meta`, `rarities`, `elements`, `classes`, `stats`, `items` (bazy + progi + mityki bossów + materiały + użytkowe + plecaki), `bonuses` (pule i zakresy), `icons` (warstwy ikon z S35), `monsters` (rodzaje + warianty + statystyki na poziomach), `bosses`, `maps`, `areas`, `caves`, `portals`, `npcs`, `shops`, `quests` (główne, poboczne, dzienne), `skills`, `recipes` (alchemia), `crafting` (kowal, skrócony do progów), `upgrade` (szanse i koszty +1…+9 dla progów), `blessings`, `titles`, `fish`, `gather`, `progression` (krzywa EXP 1–100), `mechanics` (liczby do stron mechanik), `cosmetics` (bez cen), `search` (lekki indeks do palety Ctrl+K), od S37 `mapsearch` (indeks szukania na mapie, jak `Logic/MapSearch`). Typy TS (`types.ts`) generuje ten sam eksporter, a także `wiki/src/styles/tokens.data.css` i `docs/PRZEDMIOTY.md`.

## 6. Design system i makiety

- Kierunek wizualny: **„Kuźnia”** (ciemny metal, złote krawędzie, żar), wybrany z trzech w `design/Vaelthorn Wiki - Kierunki.dc.html`.
- **Źródłem prawdy są tokeny i klasy z `design/vaelthorn.css`**, nie zrzuty. `tokens.css` i `components.css` przenoszą je 1:1 (te same nazwy `--vw-*` i `.vw-*`); zmiany wyglądu robimy w tokenach.
- Fonty: Grenze Gotisch 500/700 (nagłówki), Alegreya Sans 400/500/700/800 (tekst i UI), IBM Plex Mono 400/500 (id, kod); hostowane lokalnie (`@fontsource`), z polskimi znakami, `font-display: swap`.
- Makiety: Główna, Bestiariusz, Potwór, Przedmioty, Przedmiot, Klasa Mag, Mapa świata, Kraina, Ulepszanie, Szukaj (każda desktop 1440 + mobile 390) oraz komponenty `VwNav`, `VwTooltip`, `VwMonsterCard`.
- Komponenty z design systemu: przyciski (`.vw-btn` primary/ghost/play), tooltip przedmiotu (`.vw-tooltip`, też pływający), karta potwora (`.vw-monster`, wariant boss), nagłówek bossa z fazami (`.vw-boss`), węzeł i krawędź drzewka (`.vw-node`, `.vw-edge`), tabela z chipami i paginacją (`.vw-table`, `.vw-chip`, `.vw-pager`), paski zasobów (`.vw-bar`), plakietki strefy, rzadkości i rangi (`.vw-zone`, `.vw-rarity`, `.vw-rank`), callouty (wskazówka, ostrzeżenie, spoiler, „zmienione w aktualizacji”), nawigacja (`.vw-topbar`, `.vw-tabbar`, `.vw-toc`, `.vw-crumbs`, `.vw-lang`, `.vw-search`, paleta `.vw-palette`), stopka, szkielety ładowania i stany puste (`.vw-skeleton`, `.vw-empty`), animacja odsłonięcia legendy (`.vw-reveal`, `.vw-beam`).

### Różnice: makiety a gra (zawsze wygrywają dane gry)

| W makiecie | W grze / na wiki |
|---|---|
| Rzadkości Zwykły, Niezwykły, Rzadki, Epicki, Legendarny, Mityczny (turkus) | Z `Data/Rarities`: po S30 Zwykły #9DA3AB, Unikatowy #F2D33A, Heroiczny #3D8BFF, Legendarny #FF9F1C, Mityczny #E5302A. Tokeny `--vw-r-<key>` i poświaty `--vw-glow-<key>` (po kluczu rzadkości, bo `--vw-r-0/1/2` to promienie) generowane do `tokens.data.css`; kolor tekstu z kontrastem AA (jaśniejszy wariant tekstowy, jak `--vw-zone-red-text`) |
| Żywioły fizyczny, ogień, mróz, mrok, natura | `Data/Elements`: ogień, lód, błyskawica, trucizna (+ fizyczne obrażenia jako brak żywiołu) |
| Klasy Wojownik, Mag, Łowca, Łotr | `Data/Classes`: Wojownik, Łowca, Mag, Kapłan |
| Sloty Głowa, Tors, Dłonie, Stopy, Szyja | Sloty gry: broń, druga ręka, hełm, zbroja, rękawice, buty, naszyjnik, pierścień, talizman (+ plecak) |
| Drzewko maga: 3 gałęzie (Mróz/Ogień/Arkana), progi 1/10/20/30, „pkt w gałęzi” | Układ i wymagania z `Data/Skills` (`col`, `row`, `unlock`, `requires`), zasady punktów z `Logic/Skills`; przełomy na 5. i 10. poziomie umiejętności po S28 |
| Ulepszanie z „ryzykiem zniszczenia” i „Popielnymi Kamieniami” | `Logic/Upgrade.chance/cost`: porażka = −1 poziom, bez niszczenia; materiały i złoto z kosztu; zwój ochrony jak w grze |
| Wersje „0.9.x”, „Sezon II: Popielne Ziemie” | Gra nie ma wersji; zamiast nich commit i data z `meta.json` oraz wpisy w „Aktualizacjach” (MDX) |
| Nazwy (Strażnik Kurhanu, Ostrze Popielnego Króla, Kurhany Wschodu) | Przykłady; prawdziwe potwory, przedmioty i mapy z danych |
| Nagłówki sekcji „Umiejętności”, „Pula bonusów”, „Historia zmian”, „Zadania” sklejone z treścią dużą czcionką | Błąd makiety (kolizja kluczy w przykładowych danych): zwykły tytuł sekcji `.vw-section-title`, treść pod nim |
| Przycisk „Zagraj na Roblox” | Adres gry w `wiki/src/config.ts` (`PLAY_URL`), uzupełnia właściciel |

## 7. Plan sesji

| Sesja | Zakres |
|---|---|
| **S34** | Wiki 1/10: dane. `tools/wikidump.luau`, kontrakt, allowlista, testy wycieku, `types.ts`, `tokens.data.css`, `docs/PRZEDMIOTY.md` |
| **S36** | Wiki 2/10: szkielet Astro, design system 1:1, wspólne komponenty, układ, i18n, Pagefind, strona główna, szukaj, `/styleguide` |
| **S37** | Wiki 3/10: świat. `tools/wikimap.luau` (SVG), interaktywna mapa świata, strony krain, obszarów i jaskiń, `MiniMap` |
| **S38** | Wiki 4/10: rendery potworów, bossów i petów (`tools/wiki-renders`), boss w hero, obrazy bazowe OG |
| **S39** | Wiki 5/10: bestiariusz, strony potworów i bossów, obrazy OG |
| **S40** | Wiki 6/10: przedmioty (baza, strona przedmiotu, ikony, przedmioty bossów), kalkulator ulepszania, rzemiosło |
| **S41** | Wiki 7/10: klasy i planer umiejętności |
| **S42** | Wiki 8/10: komponenty MDX, zadania, mechaniki (PvP, śmierć, doświadczenie, walka, statystyki, błogosławieństwa) |
| **S43** | Wiki 9/10: miasto, handel, gildie, kosmetyki, poradniki MDX, aktualizacje |
| **S44** | Wiki 10/10: jakość i wdrożenie (budżety, dostępność, SEO, Lighthouse, GitHub Actions, Cloudflare Pages) |

Kolejność wiki: S34 → S36 → dalej po kolei (S37–S41 zależą tylko od S34 i S36, więc w razie potrzeby można je przestawić; S42 → S43 → S44 na końcu). Kolejność względem gry: S34 najlepiej po S30–S33 (rzadkości, wartości, balans, profile expowisk), S40 po S35 (ikony), S42–S43 po S27 (zadania poboczne). Wiki działa na każdym stanie danych: po każdej sesji zmieniającej dane wystarczy `npm run data` w `wiki/`.

## 8. Wspólne zasady sesji wiki

- Na start: ten plik, `CLAUDE.md`, `wiki/design/README.md`, odpowiednie makiety z `wiki/design/frames/`.
- Bez pytań do właściciela w trakcie; niejasność → rozwiązanie najbliższe makiecie i danym, zapis w **Decyzje**.
- Kod gry (`src/`) zmieniamy tylko, gdy to konieczne (np. flaga `wiki = false`, brakujący klucz lokalizacji), z uzasadnieniem w **Decyzje**.
- Po pracy: `npm run check` w `wiki/` (typy, lint, testy, build) i `scripts/check` muszą przejść; zrzuty `npm run shots` na 390 i 1440 px porównane z makietami; aktualizacja tego pliku (Stan, Decyzje, Niedokończone) i sekcji sesji w `docs/PROGRESS.md` z „Instrukcją testu”; commit `SXX: wiki — …` i push.
- Wdrożenie: domenę, konto Cloudflare i sekrety GitHub podłącza właściciel według sekcji „Wdrożenie” (pisze ją S44); sesje tego nie robią.

## Stan

- (pusto; pierwsza sesja wiki wpisuje tu, co działa)

## Decyzje

- 2026-10-07: wiki w `wiki/` (Astro 5 + Svelte 5 + Pagefind + Cloudflare Pages), dane z `tools/wikidump.luau`, wygląd „Kuźnia” z Claude Design. Zastępuje plan jednoplikowej wiki z pierwotnej S34. Budowa w 10 sesjach: S34, S36–S44 (S35 to ikony przedmiotów w grze).

## Niedokończone

- (pusto)
