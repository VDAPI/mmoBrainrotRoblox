# Vaelthorn: plan wiki

> Plan oficjalnej wiki gry. Sesje Claude Code W0–W9 aktualizują tabelę stanu i sekcję „Decyzje”.

## Stan sesji

| Sesja | Temat | Stan |
|---|---|---|
| D1–D3 | Claude Design: kierunek wizualny, design system, makiety | ○ |
| W0 | Plan, kontrakt JSON, zasady w CLAUDE.md | ○ |
| W1 | Exporter danych (`tools/wikidump.luau`) | ○ |
| W2 | Rendery potworów i SVG map | ○ |
| W3 | Szkielet Astro i design system | ○ |
| W4 | Bestiariusz i bossy | ○ |
| W5 | Przedmioty i rzemiosło | ○ |
| W6 | Klasy i planer buildów | ○ |
| W7 | Świat i mapa interaktywna | ○ |
| W8 | Treści ręczne (poradniki MDX) | ○ |
| W9 | Jakość i wdrożenie | ○ |

Legenda: ○ nie zaczęta · ◐ częściowo · ● gotowa · ✔ sprawdzona przez właściciela

## Decyzje

- Na razie brak.

## Niedokończone

- Na razie brak.

---

## 0. Zasada główna: wiki generowana z danych gry

Tabel potworów, przedmiotów i skilli nie piszemy ręcznie, bo po każdej sesji balansu byłyby nieaktualne.

- **Liczby** są w `src/shared/Data/*`. `Logic` i `Data` działają w Lune, więc exporter `tools/wikidump.luau` zrzuca je do JSON.
- **Nazwy i opisy (PL/EN)** są w `Data/Localization`, dzięki czemu wiki jest dwujęzyczna od pierwszego dnia.
- **Obrazki potworów, bossów i petów** generują `tools/lookdump.luau` i `docs/miasto/tools/render3d.py` (PNG/WebP dla każdego potwora).
- **Mapa świata** powstaje z `Data/Areas`, `Data/Portals` i `Data/Maps` jako SVG. To te same dane, z których korzysta mapa w grze.

Podział pracy: dane generuje skrypt, poradniki i lore pisze człowiek (MDX), wygląd projektujemy w Claude Design.

**Uwaga, wyciek:** `Codes.luau`, `AdminCommands`, `Products` i niewydane questy czy bossy nie mogą trafić na wiki.
Exporter korzysta z **allowlisty** źródeł i pól, nigdy z listy zakazanych. Dodatkowo test wywala się, gdy w JSON pojawi się kod nagrody.

## 1. Stack

| Element | Wybór | Dlaczego |
|---|---|---|
| Generator | **Astro** (statyczny, MDX, content collections) | Najszybsze strony, dobre SEO, interaktywność tylko tam, gdzie jest potrzebna (wyspy w Vue) |
| Wyszukiwarka | **Pagefind** | Pełny tekst offline, działa bez backendu |
| Mapa | SVG z danych, pan i zoom (np. `panzoom`) | Bez kafelków, ostra, lekka |
| Wykresy | Małe wyspy z Chart.js albo czysty SVG | Krzywa EXP, skalowanie statystyk |
| Hosting | **Cloudflare Pages** | Za darmo, własna domena, preview dla każdego brancha |
| Miejsce | Folder `wiki/` w tym repo | Exporter czyta `src/shared` bezpośrednio, a CI buduje stronę po pushu |

Starlight odpada: jest wygodny, ale wygląda jak dokumentacja techniczna, a wiki ma mieć klimat gry.

## 2. Mapa strony

1. **Strona główna**: hero z renderem bossa, przycisk „Graj na Roblox”, „Co nowego”, skróty do sekcji.
2. **Pierwsze kroki**: sterowanie (z `Keybinds`), pierwsze 10 poziomów, strefy PvP, śmierć.
3. **Klasy**: 4 strony, każda z drzewkiem umiejętności (interaktywnym, z planerem buildu i linkiem do niego).
4. **Bestiariusz**: potwory pogrupowane według regionu. Elita i Elita II, poziomy, gdzie występują (mini-mapa), drop i render.
5. **Bossy i lochy**: fazy, mechaniki, łup, wymagania grupy.
6. **Przedmioty**: baza z filtrami (slot, rzadkość, poziom, klasa), tooltip w stylu gry, legendy osobno.
7. **Rzemiosło**: kowal (ulepszanie +0…+9 z szansami), rozbijanie, alchemik, receptury, zbieractwo, ryby.
8. **Świat**: interaktywna mapa (obszary, poziomy, portale, jaskinie, NPC) i strona każdej mapy.
9. **Miasto**: NPC i usługi, z obrazkami z `docs/miasto/img`.
10. **Questy**: fabuła (spoilery domyślnie ukryte) i dzienne.
11. **Mechaniki**: formuły statystyk, obrażenia, żywioły, krzywa EXP (wykresy z `Progression`), błogosławieństwa.
12. **PvP, arena, gildie, handel, aukcja.**
13. **Kosmetyki i przepustki**: przejrzyście, bez „kup teraz”, z jasnym przekazem, że gra nie jest pay-to-win.
14. **Aktualizacje**: changelog pisany dla graczy, nie kopia PROGRESS.md.

## 3. Jak dzielić pracę między Claude Design i Claude Code

- **Claude Design** odpowiada za kierunek wizualny, design system i makiety 5–6 kluczowych ekranów. Nie buduje całej strony.
- **Claude Code** odpowiada za exporter, implementację, dane, rendery, testy, wydajność i wdrożenie. Jedna sesja W to jeden zakres, a stan trafia do tego pliku.
- **Przekazanie projektu:** gotowy design system z Claude Design (link do artefaktu albo eksport: tokeny, komponenty, makiety) trafia do Claude Code.
  Claude Code przenosi go 1:1 do `wiki/src/styles/tokens.css` i komponentów Astro. Źródłem prawdy są tokeny, nie zrzuty ekranu.

---

## 4. Prompty: Claude Design

### D1: kierunek wizualny (3 warianty)

```text
Projektuję oficjalną wiki dla mojej gry Vaelthorn: MMORPG na Roblox, "Margonem w 3D".
Klimat: poważne dark fantasy, zero memów. Rdzeń emocjonalny gry to drop legendarnego
przedmiotu (słup światła, odsłanianie statystyk), ulepszanie +0..+9 i losowe bonusy.
Odbiorcy: gracze 12–25 lat, PL i EN, ok. 60% na telefonie.

Kolory z UI gry (trzymaj się ich, możesz dodać odcienie):
tło #14161B, panel #1B1D23, panel wyżej #252832, ramka #3A3F4C,
złoto #C9A45C / jasne #E8C25A / ciemne #7A6438, pergamin #EADDBE,
tekst #E8E4DA / wyciszony #9A9DA8, akcent #4A8FE7,
HP #C2352E, mana #3D6FD6, energia #D9B23A, EXP #8E5BD9,
strefy: zielona #4FD16B, żółta #E0C23B, czerwona #D64A3E,
rzadkości: zwykły #C9CED6, niezwykły #4FD16B, rzadki #3D8BFF, [dopisz resztę z Data/Rarities].

Inspiracje do przemyślenia (nie do kopiowania): czytelność baz danych Wowhead i poe2db,
struktura OSRS Wiki, klimat stron Diablo IV i Hollow Knight.

Zaproponuj 3 wyraźnie różne kierunki wizualne strony głównej (desktop 1440 + mobile 390):
A) "Kronika": pergamin, iluminowane inicjały, ornamentyka
B) "Kuźnia": ciemny metal, złote krawędzie, żar, bliżej UI gry
C) "Atlas": nowoczesny, minimalistyczny, dużo powietrza, fantasy tylko w akcentach
Dla każdego: typografia (nagłówki + tekst, Google Fonts, z polskimi znakami),
przykładowy hero, karta potwora i tooltip przedmiotu. Krótko opisz, dla kogo który działa najlepiej.
```

### D2: design system (po wyborze kierunku)

```text
Wybieram kierunek [X], z tych zmian: [...].
Zbuduj z niego design system wiki:
1. Tokeny: kolory (z trybem jasnym i ciemnym; ciemny jest domyślny), typografia (skala, wysokości linii),
   odstępy, promienie, cienie i poświaty (osobna poświata dla każdej rzadkości), ruch (czasy, easing,
   wariant prefers-reduced-motion).
2. Komponenty, każdy ze stanami (hover, focus, aktywny, wyłączony) i wersją mobilną:
   - tooltip przedmiotu jak w grze: nazwa w kolorze rzadkości, poziom ulepszenia, statystyki bazowe,
     wylosowane bonusy, wymagania, wiązanie
   - karta potwora (render, poziom, typ: zwykły/Elita/Elita II, region, żywioł, drop)
   - nagłówek bossa (fazy, mechaniki, ikony)
   - węzeł i połączenie drzewka umiejętności (zablokowany, dostępny, wykupiony, maks.)
   - tabela danych z sortowaniem, filtrami (chipy), paginacją; na telefonie zamienia się w karty
   - pasek statystyk (HP/mana/energia/EXP), plakietka strefy PvP, plakietka rzadkości
   - callouty: wskazówka, ostrzeżenie, spoiler (zakryty), "zmienione w aktualizacji X"
   - nawigacja: górny pasek, boczny spis treści, okruszki, przełącznik PL/EN, wyszukiwarka (Ctrl+K)
   - stopka, przycisk "Graj na Roblox"
3. Zasady: kontrast WCAG AA, cele dotyku min. 44 px, siatka i breakpointy.
Dokumentuj każdy komponent tak, żeby developer mógł go odtworzyć 1:1 w CSS.
```

### D3: makiety kluczowych stron

```text
Na bazie design systemu zaprojektuj (desktop 1440 + mobile 390, prawdziwe przykładowe dane):
1. Strona główna
2. Lista bestiariusza z filtrami (region, poziom, typ)
3. Strona potwora (render, statystyki, gdzie występuje z mini-mapą, tabela dropu z szansami)
4. Baza przedmiotów + otwarty tooltip
5. Klasa Mag z interaktywnym drzewkiem umiejętności i planerem punktów
6. Interaktywna mapa świata (panel boczny z kartą obszaru, legenda, warstwy)
Pokaż też stany puste, ładowania i "nic nie znaleziono".
```

Wskazówki do pracy z Claude Design:
- Wrzucaj zrzuty z gry (UI, okno ekwipunku, mapa M) i obrazki z `docs/miasto/img`. Wynik będzie bardziej „wasz”.
- Iteruj na jednym komponencie naraz, a nie na całej stronie.
- Najpierw dopracuj tooltip przedmiotu i kartę potwora. To one niosą klimat, reszta to tabele.

---

## 5. Prompty: Claude Code (sesje W0–W9)

Każdą sesję zaczynaj w nowej rozmowie. Na koniec każdego promptu dopisz:

```text
Na start przeczytaj docs/WIKI.md (Decyzje, Niedokończone). Po pracy: `npm run check` w wiki/
(typy, lint, testy, build) musi przejść; zaktualizuj docs/WIKI.md. Nie ruszaj kodu gry
poza tools/ i tests/, chyba że to konieczne (wtedy napisz dlaczego).
```

### W0: plan i zasady

```text
Chcę oficjalną wiki gry w folderze wiki/ tego repo: Astro + TypeScript, statyczna,
dane generowane z src/shared/Data przez Lune, poradniki w MDX, PL i EN, hosting Cloudflare Pages.
Przeczytaj docs/WIKI.md, docs/DESIGN.md, docs/ARCHITECTURE.md, src/shared/Data/* i tools/*.luau.
Uzupełnij docs/WIKI.md o: strukturę folderów, kontrakt JSON (schemat dla każdej
encji: monster, boss, item base, unique, skill, recipe, quest, map, area, portal, npc)
i mapę strony z URL-ami (/pl/bestiariusz/<id>, /en/bestiary/<id>). Dopisz do CLAUDE.md
sekcję "Wiki" (krótko: gdzie co jest, jak dodać stronę).
Najpierw pokaż mi plan, nie pisz plików bez akceptacji.
```

### W1: exporter danych

```text
Napisz tools/wikidump.luau (Lune): zrzuca do wiki/src/data/*.json wszystkie encje z kontraktu
w docs/WIKI.md, z nazwami i opisami z Localization (pl i en) oraz z wartościami
wyliczonymi przez Logic (np. statystyki potwora na poziomie, szanse ulepszania), żeby wiki
nie powtarzała formuł w TS.
Bezpieczeństwo: ALLOWLISTA źródeł i pól. Nigdy nie eksportuj Codes, AdminCommands, Products
(poza nazwą i opisem kosmetyków), niczego z flagą hidden/unreleased. Dodaj
tests/wikidump.spec.luau: brak kodów nagród w wyjściu, każde id ma nazwę PL i EN,
każdy drop wskazuje istniejący przedmiot, każdy potwór ma obszar występowania.
Dodaj generowanie typów TS (wiki/src/data/types.ts) z tego samego schematu.
Wyjście ma być deterministyczne (posortowane klucze), żeby diff w git był czytelny.
```

### W2: rendery i mapa

```text
Na bazie tools/lookdump.luau i docs/miasto/tools/render3d.py zrób skrypt
tools/wiki-renders (Python): render każdego potwora, wariantów Elita/Elita II, bossów i petów
do wiki/public/img/mobs/<id>.webp (512 px, przezroczyste tło, ten sam kąt kamery i światło,
lekki 3/4) + miniatura 128 px. Skrypt jest przyrostowy: hash wyglądu → nie renderuje,
jeśli się nie zmienił.
Mapy: tools/wikimap.luau generuje SVG każdej mapy z Data/Areas, Portals, Maps
(obszary z poziomami, drogi, jeziora, jaskinie, portale, NPC), z id elementów do
podświetlania z poziomu strony. Kolory z tokenów wiki (zmienne CSS).
```

### W3: szkielet i design system

```text
Postaw wiki/ (Astro, TS strict, i18n PL/EN z routingiem, Pagefind, sitemap).
Zaimplementuj design system z [link / eksport z Claude Design]: tokeny w
src/styles/tokens.css 1:1 z projektu, komponenty z listy w docs/WIKI.md jako komponenty
Astro (interaktywne jako wyspy Vue). Zrób stronę /styleguide pokazującą każdy
komponent we wszystkich stanach, na prawdziwych danych z JSON.
Sprawdź w przeglądarce (wbudowany browser) na 390 i 1440 px, porównaj z makietami,
pokaż mi zrzuty i listę różnic.
```

### W4: bestiariusz i bossy (W5 i W6 analogicznie)

```text
Zbuduj sekcję [Bestiariusz + Bossy] wg makiety [D3 #2, #3] i kontraktu z docs/WIKI.md.
Strony generowane z JSON (getStaticPaths), lista z filtrami w URL (do udostępniania),
na telefonie karty zamiast tabeli. Każda strona: render, statystyki, gdzie występuje
(fragment SVG mapy z podświetlonym obszarem), tabela dropu, linki krzyżowe do przedmiotów.
Meta tagi i obrazek OG generowany per strona (render + nazwa + poziom).
Sprawdź w przeglądarce 3 losowe strony na 390 i 1440 px i pokaż zrzuty.
```

- **W5** (Przedmioty i rzemiosło): makiety D3 #4, baza z filtrami, tooltip, kowal z szansami ulepszania, receptury.
- **W6** (Klasy i planer): makieta D3 #5. Planer rozdaje punkty zgodnie z regułami z `Logic`, trzyma stan w URL i ma przycisk „Kopiuj link”.

### W7: świat i mapa interaktywna

```text
Interaktywna mapa świata wg makiety D3 #6: pan i zoom (mysz, dotyk, pinch), warstwy
(potwory wg poziomu, portale, jaskinie, NPC, zbieractwo), klik → panel boczny z kartą,
wyszukiwarka na mapie, deep-link (/mapa?m=<mapa>&x=..&z=..). Strona każdej mapy i obszaru.
Bez bibliotek kafelkowych, SVG z W2. 60 fps na średnim telefonie (sprawdź w devtools).
```

### W8: treści ręczne

```text
Napisz poradniki w MDX (PL, potem tłumaczenie EN): Pierwsze kroki, Jak expić 1–30,
Ulepszanie bez płaczu, Strefy PvP, Gildie. Źródło prawdy to DESIGN.md i dane; liczby
wstawiaj komponentem <Stat id="..."/> z JSON, nie na sztywno. Ton: konkretny, krótki,
dla nastolatka, bez memów. Fabułę questów ukrywaj za spoilerem.
```

### W9: jakość i wdrożenie

```text
Audyt i wdrożenie: Lighthouse (cel: 95+ w każdej kategorii na mobile), dostępność (axe,
nawigacja klawiaturą, focus), budżet JS na stronę <50 KB poza mapą, obrazy webp/avif z
srcset, 404 w obu językach, sitemap i hreflang, robots. GitHub Actions: na push do main
lune wikidump → testy → build → Cloudflare Pages (preview na PR). Nie podłączaj
domeny ani sekretów sam, przygotuj instrukcję dla mnie.
```

---

## 6. Co da najlepszy efekt

1. **Najpierw design, potem kod.** Do W3 nie ruszaj implementacji, dopóki makieta tooltipu i karty potwora nie jest „ta”.
2. **Weryfikacja wizualna w każdej sesji.** Zawsze wymagaj zrzutów na 390 i 1440 px oraz porównania z makietą.
3. **Rendery to połowa wrażenia.** Jeśli `render3d.py` daje płaskie obrazki, poświęć jedną sesję na samo oświetlenie, kąt i obrys.
4. **Zrzuty z gry robi właściciel** (Claude nie uruchamia gry). Przygotuj 10–15 ujęć: miasto o zmierzchu, drop legendy, boss, mapa.
5. **Dane zawsze aktualne.** `wikidump` w `scripts/check.ps1` oraz test, że JSON w repo zgadza się z danymi.
6. **Później:** porównywarka przedmiotów, timery Elit II online (wymaga backendu) i edycje społeczności przez PR na GitHubie.

Kolejność: **W0 → D1–D3 (równolegle W1–W2) → W3 → W4…W8 → W9.** Realnie to 10–12 sesji.
