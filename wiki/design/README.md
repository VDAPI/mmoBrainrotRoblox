# Projekt wiki z Claude Design („Kuźnia” v1.0)

Eksport projektu z Claude Design (2026-10-07). **Tylko do wglądu**: kod wiki nie importuje tych plików. Wygląd przenosimy do `wiki/src/styles` i komponentów (`docs/WIKI.md` §6).

## Co tu jest

| Plik | Co to |
|---|---|
| `vaelthorn.css` | **Źródło prawdy wyglądu**: tokeny `--vw-*` (kolory, typografia, odstępy, cienie, poświaty rzadkości, ruch, siatka; motyw ciemny domyślny i jasny `data-theme="light"`) oraz klasy komponentów `.vw-*` |
| `Vaelthorn Design System.dc.html` (+ `standalone`, `.html` = wersja jednoplikowa) | Dokumentacja design systemu: kolory, typografia, odstępy i cienie, ruch, każdy komponent ze stanami |
| `Vaelthorn Wiki - <Strona>.dc.html` | Makiety stron: Główna, Bestiariusz, Potwór, Przedmioty, Przedmiot, Klasa Mag, Mapa świata, Kraina, Ulepszanie, Szukaj (każda desktop 1440 + mobile 390) |
| `Vaelthorn Wiki - Kierunki.dc.html` | Trzy kierunki wizualne (Kronika, Kuźnia, Atlas); wybrano Kuźnię |
| `VwNav`, `VwTooltip`, `VwMonsterCard` (`.dc.html`) | Komponenty współdzielone przez makiety |
| `vw-data.js` | **Przykładowe** dane makiet (nazwy, liczby); na wiki zastępują je dane z gry |
| `support.js` | Runtime makiet Claude Design (React z unpkg) |
| `frames/*.jpg` | Zrzuty każdej makiety osobno: `<Strona>-desktop.jpg` (1440 px) i `<Strona>-mobile.jpg` (390 px). Do porównań z gotowymi stronami |
| `screenshots/` | Zrzuty design systemu (`design-system-1..5.jpg`) i kierunków |

## Jak obejrzeć makiety na żywo

Z tego folderu: `npx serve .` (albo `python -m http.server`), potem w przeglądarce np. `http://localhost:3000/Vaelthorn%20Wiki%20-%20Potwor.dc.html`. Potrzebny internet (React i fonty z CDN). Szybciej: obrazki w `frames/`.

## Znane błędy makiet (nie przenosić)

- Na stronach Potwór, Przedmiot i Kraina tytuły sekcji „Umiejętności”, „Pula bonusów”, „Historia zmian” i „Zadania” wyświetlają się jako długi tekst dużą czcionką, sklejony z treścią sekcji. To kolizja kluczy w przykładowych danych. Na wiki: zwykły tytuł sekcji (`.vw-section-title`), treść pod nim.
- Na mapie świata panel boczny zachodzi na etykiety obszarów; na wiki etykiety pod panelem są ukryte albo mapa przesuwa się tak, by wybrany obszar był widoczny obok panelu.

## Różnice względem gry

Pełna tabela: `docs/WIKI.md` §6 („Różnice: makiety a gra”). Najważniejsze: rzadkości, żywioły, klasy i sloty bierzemy z danych gry; ulepszanie nie niszczy przedmiotów; drzewko umiejętności ma układ z `Data/Skills`.
