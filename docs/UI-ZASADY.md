# Vaelthorn: zasady UI

> Plan UI 2026-11-10 (właściciel 2026-11-10: „bardzo dużo napisów, niektóre rzeczy zasłaniają inne, zbyt szczegółowe
> opisy, nie da się zwinąć”). Zasady dotyczą każdego nowego i zmienianego ekranu, na PC i na telefonie. Decyzje
> właściciela (`docs/DECYZJE.md`, `docs/DESIGN.md` §23) mają pierwszeństwo. Zmiana zasady to najpierw zmiana w kodzie,
> który jej pilnuje (`Logic/TextCaps`, `Logic/HudZones`, `Logic/WindowFrame`, `Logic/Popover`, `Data/Folds`), potem
> tutaj. Pilnują ich specy Lune (§9).

## 1. Zasada główna

- Na wierzchu jest jedna krótka linia: co to jest i w jakim jest stanie. Reszta jest o jeden ruch dalej.
- Wejścia do szczegółów (tylko te):
  - (i), `InfoTip`: zasady, wzory, wyjątki, progi, szanse, skąd to wziąć, fabuła. Jedno (i) na blok.
  - „Więcej ▸”, `Details`: dłuższe wyjaśnienie pod krótką linią w oknie albo modalu. Na start zamknięte.
  - „▸ Tytuł”, `Section`: zwinięta część okna. Stan jest zapisany na koncie.
  - Alt na PC (klawisz „Szczegóły”, `item_details`, domyślnie lewy Alt): pełny dymek przedmiotu i umiejętności.
    Shift steruje kamerą, nie szczegółami. Na dotyku: „Więcej ▸” w dymku albo dłuższe przytrzymanie.
  - „Szczegóły” na karcie: pełna tabela walki, wkład w bossa, pełne odkrycie przedmiotu (modal).
- Zawsze na wierzchu: cena, ilość, stan (włączone, czas, postęp), błąd blokujący akcję, przycisk akcji.
- Nic nie znika: tekst zdjęty z wierzchu ma swoje miejsce za jednym z tych wejść.
- Jedna treść w jednym miejscu. Nie powtarzamy tego samego w (i) i w dymku karty, w tytule i w treści ani w modalu i
  w toaście zaraz po nim.

## 2. Limity tekstu

Liczymy znaki widoczne, bez tagów, po wstawieniu przykładowych wartości: nick 20, przedmiot 28, potwór i boss 24,
NPC 16, obszar 20, gildia 24, liczba 6, klawisz 6, inne 12. Liczy `Logic/TextCaps` (powierzchnie i limity w
`TextCaps.SURFACES`). Model szerokości: litera 0,56 em, spacja 0,3 em, symbol 1 em. Limit obowiązuje pl i en.
Liczbę zdań sprawdza tylko w (i); „jedno zdanie” przy toaście i powitaniu NPC to zasada pisania.

- Przycisk: 18, jedna linia, bez zawijania. Zakładka: 12; całe terminy ze słownika gry mogą być dłuższe
  (`TextCaps.TERMS`, dziś tylko „Błogosławieństwa” u alchemika), pasek zakładek je mieści albo przewija.
- Tytuł okna: 22, jedna linia. Tytuł modala: 28. Nagłówek sekcji: 24 (nazwa panelu HUD: 20). Linia zwiniętej
  sekcji: 36. Etykieta: 20 plus wartość.
- Linia w oknie (stan, `.short`): 60, jedna linia.
- HUD:
  - linia (wpis tropiciela, panel, drużyna, prowadzenie): 32;
  - dymek elementu: 48, jedna linia (nazwa i stan);
  - kafelek ☰ i przycisk paska: 18 razem z klawiszem.
- Komunikaty:
  - toast: 60, jedno zdanie (na PC najwyżej 2 linie, na telefonie 3);
  - alarm: 28;
  - baner: 56, jedna linia na PC;
  - karta: linia 40 i najwyżej 2 przyciski;
  - zaproszenie: 60.
- Modal: treść 90, bez powtarzania tytułu; „Więcej ▸” 240; przycisk 14.
- (i): 240, najwyżej 3 zdania, bez list. „Więcej ▸” w oknie: 300.
- Dymki:
  - skrócony dymek przedmiotu: najwyżej 10 linii po 60;
  - dymek paska umiejętności: najwyżej 5 linii po 60;
  - skrót umiejętności i węzła: 60; próg: 48.
- Rozmowy:
  - powitanie NPC: 60, jedno zdanie (reszta w `.info` za (i));
  - strona rozmowy (oferta p1–p4, oddanie `.done` i `.doneN`, kwestia NPC): 140, ciąg dalszy za „Dalej ▸”;
  - odpowiedź gracza: 44.
- Pozostałe:
  - karta samouczka: 80, osobno dla PC, dotyku i telefonu;
  - wskazówka ekranu ładowania: 80;
  - kwestia przerywnika: 140;
  - placeholder pola: 20;
  - nazwa klawisza: 18.

## 3. Jak piszemy

- Bez długiego myślnika (U+2014). Zamiast niego: dwukropek, przecinek albo dwa zdania.
- Bez rad w komunikatach („spróbuj ponownie”, „możesz grać dalej”).
- Bez opisu sterowania poza samouczkiem i listą klawiszy („kliknij”, „najedź”, „przeciągnij”, „prawy klik”).
- W toastach bez klawiszy i nazw okien („(K)”, „w oknie Umiejętności”).
- Długą nazwę własną piszemy raz, potem symbol (◆ zamiast „Smoczej Waluty”).
- Liczby piszemy cyframi, jednostki skrótem (s, min, m, %). Ułamek ma znak języka z `format.decimal` („1,5 s” po
  polsku, „1.5 s” po angielsku).
- „Lv N” na plakietkach i ramkach (decyzja 2026-10-21), „poziom N” w zdaniach.
- Jedno słowo na jedną rzecz: Plecak, Umiejętności, Mapa, Questy (przycisk, okno, grupa tropiciela), Cele (nagłówek
  tropiciela), Zlecenia, Sklep (kupiec NPC; Handel to wymiana między graczami), Smoczy Sklep, Smocza Waluta (◆ przy
  liczbach), Pancerz (statystyka; Zbroja to część ekwipunku), miejsce na postać, Menu ☰, Ustawienia. Nazewnictwo
  questów czeka na potwierdzenie właściciela. Nowe słowo wchodzi tylko przez dopisanie go tutaj.
- pl i en zmieniamy razem, z tymi samymi placeholderami.

## 4. Zwijanie

- Większa część okna to `Section`:
  - otwarta: nagłówek „▾ Tytuł”;
  - zwinięta: „▸ Tytuł” i jedna linia podsumowania.

  Cały nagłówek jest przyciskiem: 32 px na PC, co najmniej 44 na dotyku. Jest jeden poziom zwijania.
- Stan jest zapisany na koncie: `account.settings.sections`, a dla tropiciela `account.settings.trackerFold`.
  Domyślny stan każdej sekcji jest w `Data/Folds/<obszar>.luau` jako `true` / `false` albo `{ pc = …, phone = … }`.
  Wybór gracza wygrywa na każdym urządzeniu.
  - `phone` to układ telefonu (`PhoneLayout.Compact`: dotyk i niski ekran), `pc` to reszta, także tablet.
  - Obszary: `Hud` (HUD), `Gear` (plecak, umiejętności, usługi, sklepy), `World` (świat i społeczność), `Menu` (menu
    gry i ustawienia). Każde id jest jedno w całym `Data/Folds`; powtórzone id to błąd przy wczytaniu.
  - Na koncie zostaje tylko wybór różny od domyślnego; klik, który na tym urządzeniu nic nie zmienia, nic nie zapisuje.
  - Nagłówek, który nie jest `Section` (panel HUD, grupa ustawień), bierze ten sam stan i zapis z
    `Section.state(scope, id)`.
- `Details` („Więcej ▸”) służy tylko dłuższemu tekstowi pod krótką linią. Stan trwa do końca sesji.
- Domyślnie otwarte jest to, czego okno dotyczy. Zwinięte jest wszystko, czego nie trzeba do głównej akcji.
- HUD:
  - grupy tropiciela jak w decyzjach: fabuła i śledzone poboczne rozwinięte; zlecenia łowieckie, dnia i tygodnia oraz
    osiągnięcia zwinięte;
  - panele wydarzeń (boss świata, wydarzenie świata, Krwawy Księżyc, turniej, arena): na PC rozwinięte, póki trwają,
    na telefonie jedna linia;
  - gdy w kolumnie brakuje miejsca, panele same zwijają się do linii, a potem chowają za „+N”.
- Okna:
  - Plecak: Statystyki otwarte, Zestawy i tytuł zwinięte (decyzja 2026-11-10). Statystyki pochodne w czterech
    sekcjach: Ofensywa otwarta; Defensywa, Zasoby i Inne zwinięte.
  - Umiejętności: krótki opis otwarty; „Koszt i odnowienie”, „Przełomy” i „Zmiany z kierunków” (linia „Działa: 1 z 3”)
    zwinięte.
  - Ustawienia: Dźwięk, Grafika i kamera, Walka i Interfejs otwarte; Łup i handel, Społeczność i Skróty klawiszowe
    zwinięte; na dotyku bez Skrótów klawiszowych.
  - Dziennik: historia i ukończone wątki zwinięte.
  - Mapa: legenda zwinięta na telefonie, sklepy NPC zwinięte.
  - Gildia: dziennik, ustawienia i „Jak zdobywać EXP gildii” zwinięte.
  - Krwawy Księżyc: zasady i nagrody zwinięte.
  - Tablica zleceń: blok polowań zwinięty na telefonie; zwinięty ma w nagłówku „Gotowe: n · Do przyjęcia: n”.
  - Rankingi: podium zwinięte na telefonie.
  - Bestiariusz: regiony zwinięte na telefonie.
  - Linię podsumowania zastępuje tytuł, który sam mówi, co czeka: „Ukończone (n)” w dzienniku, wybrany region w
    bestiariuszu, liczniki bloku polowań. Bez podsumowania są sekcje, w których nic nie czeka: podium rankingów (ci
    sami gracze stoją w tabeli), historia dziennika, legenda i sklepy NPC na mapie, dziennik, herb i uprawnienia
    gildii, źródła EXP gildii, zasady Krwawego Księżyca, grupy ustawień.

## 5. HUD

- Każde miejsce w HUD pochodzi z `Logic/HudZones` (PC, tablet) albo `Logic/PhoneHud` (telefon). W plikach
  `Screens/Hud` nie wpisujemy nowych pikseli.
- Strefy PC:
  - lewy górny róg: postać (portret, Auto, rząd efektów: 9 ikon i „+N”), pod nią drużyna i miejsce na kwestie NPC;
  - góra, środek: pasmo celu (ramka celu z efektami, pasek bossa lochu, panel areny), pod nim pas wiadomości
    (propozycja, pytanie do właściciela);
  - prawy górny róg: sześć przycisków, minimapa, belka prowadzenia, rząd „coś czeka”;
  - prawa kolumna: panele i tropiciel, do podłogi;
  - prawy dolny róg: jedna karta naraz (pytanie do właściciela);
  - dół: pasek akcji, linia rzucania, pasek EXP;
  - lewy dolny róg: czat;
  - środek ekranu należy do walki, nic tam nie stoi na stałe.
- Nic nie wchodzi na pasmo celu i nic nie schodzi poniżej podłogi kolumny. Gdy brakuje miejsca, element zwija się do
  linii, potem chowa za „+N” (lista na jedno kliknięcie), a komunikat czeka w kolejce.
- Telefon: strefa gałki (lewy dół) i łuk umiejętności (prawy dół) są wolne od wszystkiego innego (lewy stos nad
  strefą gałki: propozycja, pytanie do właściciela). Cele dotyku mają co najmniej 44; atak, umiejętności, ☰, sprint i
  wierzchowiec mają 52.
- Okno, które zasłania element HUD, chowa go do swojego zamknięcia (`HudCover`). Pasek akcji, paski portretu i czat
  zostają.

## 6. Komunikaty

- Wszystko, co wyskakuje (alarm, zaproszenie, karta, baner, toast, kwestia NPC), idzie przez jedną kolejkę
  (`UI/Notify`, `Logic/NoticeQueue`) i ma jedno miejsce. `Toast.push` i `Announcement.push` zostają, ale prowadzą do
  tej kolejki.
- Kolejność: alarm > gotowość > zaproszenie do grupy > oferta areny > inne zaproszenia > nagroda bossa > przedmiot
  legendarny > wynik walki > lepszy przedmiot > baner > toast > kwestia NPC.
- Naraz:
  - PC: alarm, baner, 2 toasty, 1 karta i 1 zaproszenie;
  - telefon: 1 komunikat oraz 1 karta albo zaproszenie.
- Czas:
  - toast 3,5 s (błąd 4,5 s);
  - baner 5 s, mityczny 8 s;
  - boss świata 15 s na czerwono (decyzja);
  - alarm do końca rzucania;
  - karta do swojego terminu.
- Ten sam tekst w ciągu 10 s to jeden wpis „×N”. Ten sam błąd pokazujemy najwyżej raz na 10 s.
- W walce czekają: toasty informacyjne (do 10 s), ogłoszenia z innych serwerów, kwestie NPC i karta „lepszy
  przedmiot” (do 30 s; ogłoszenia: propozycja, pytanie do właściciela). Potem przepadają. Błędy i alarmy nigdy nie
  czekają.
- Ogłoszenia serwera idą tylko banerem, bez kopii w czacie (decyzja).
- Nic nie staje na pasku tytułu okna (decyzje 2026-10-31, DESIGN §23). Przy otwartym oknie toast i baner ogłoszenia
  (także bossa świata) stoją nad oknem, a gdy tam brak miejsca, pod jego paskiem tytułu, jak dziś; nie czekają na
  zamknięcie okna. Toast osiągnięcia czeka, aż okno się zamknie, a gdy okno otworzy się w trakcie, zjeżdża pod pasek
  tytułu. Napis w pasku tytułu zamiast tytułu (`WindowManager.Notice`) i baner wstrzymany do zamknięcia okna to
  propozycje planu, pytanie UI 8 do właściciela.

## 7. Okna

- Ramka okna pochodzi z `Logic/WindowFrame`: `rect` (nagłówek, ✕, treść, stopka), `clampDrag` (przeciąganie na PC),
  `pair` (usługa obok plecaka). Dymki z `Logic/Popover` (`place`).
- Nagłówek ma 52 na PC i 44 na telefonie. Tytuł mieści się w jednej linii (Large 24 na PC, Body 20 na telefonie). ✕ ma
  co najmniej 44 i stoi w prawym rogu. Esc zamyka. Naraz otwarte jest jedno okno główne (`WindowRules`).
- Na dotyku okno zaczyna się pod paskiem Robloxa (`Scale.TopBar`). Na PC przeciągnięte okno trzyma nagłówek co
  najmniej 8 pod paskiem i co najmniej 80 px na ekranie.
- Usługa i plecak: na PC stoją obok siebie. Na dotyku (telefon i tablet) usługa ma w nagłówku przycisk „Plecak”, a
  plecak przycisk „◂ <usługa>”.
- Treść:
  - odstęp od brzegu 22 na PC, 14 na telefonie;
  - 8 między elementami, 14 między sekcjami;
  - gdy treść się nie mieści, ma jedno przewijanie w pionie, a główny przycisk stoi w przypiętej stopce (52).
- Jeden wygląd na typ:
  - nagłówek sekcji: `Section`;
  - wiersz listy: 48, dwulinijkowy 64;
  - zakładki: 44, przewijane w poziomie, gdy się nie mieszczą;
  - pole tekstowe: 52;
  - przycisk: 52 (40 tylko na PC).
- Modal: tytuł w nagłówku z ✕, treść do 90, „Więcej ▸”, przyciski w stopce. Wysokość najwyżej ekran minus pasek
  Robloxa minus 16, reszta się przewija.
- Zaproszenia (grupa, pojedynek, handel, gildia, znajomy, arena, gotowość) mają jeden wygląd, `Components/Prompt`:
  ikona, jedna linia, ✓ po prawej, ✕, pasek czasu.
- Dymki i (i):
  - stoją w bezpiecznym obszarze, 8 od krawędzi;
  - odbijają się nad albo pod kotwicę (`Logic/Popover`);
  - nigdy nie stoją na kotwicy ani na przycisku akcji;
  - na dotyku stoją po drugiej stronie niż dotknięty slot.

## 8. Rozmiary (Theme)

- Używamy tylko tokenów `Theme` i modułów układu. Istniejących wartości nie zmieniamy, nowe dopisujemy.
- TextSize:
  - Caption 15 tylko dla etykiet WERSALIKAMI;
  - Small 17 to najmniejszy tekst zdań;
  - Body 20: treść okien i toasty;
  - Large 24: tytuły okien;
  - Title 30; Hero 64.

  Bez `TextScaled` w tekstach.
- Size:
  - dotyk i przyciski: MinTouch 44, ButtonHeight 52 (ButtonHeightSmall 40 tylko na PC), IconButton 52,
    InputHeight 52;
  - okna i listy: WindowHeader 52, WindowHeaderCompact 44, RowHeight 48, RowHeightTall 64 (dwie linie), SlotSize 64,
    TabHeight 44, SectionHeader 32;
  - HUD: PanelLine 32, HudLine 52;
  - szerokości: TooltipWidth 340, InfoTipWidth 320, ModalWidth 520.
- Padding: Tiny 4, Small 8, Medium 14, Large 22, Huge 36. HUD: margines 22, odstęp 8, ikona 52 (`Logic/HudStack`).

## 9. Jak to sprawdzamy (bez Studio)

- `textcaps.spec`: każdy klucz pl i en mieści się w limicie swojej powierzchni i nie ma długiego myślnika. Mapę kluczy
  buduje `tests/TextScan.luau` z kodu. Reguły i listę „do skrócenia” każdego pakietu trzyma `tests/fixtures/textcaps`.
  Lista „do skrócenia” może tylko maleć.
- `hudzones.spec`, `phonehud.spec`, `hudlayout.spec`: prostokąty HUD z tych samych modułów, których używa gra. Ekrany:
  PC 1920×1080, 1366×768 i 1280×720 (oraz 4:3, niskie okno, ultrawide), telefony 844×390, 667×375 i 932×430, pasek
  Robloxa 0, 36 i 58 px. Pas wiadomości mieści linię alarmu (`HudZones.MESSAGE.alert`, 44). Dzisiejsze kolizje stoją
  na liście `KNOWN` w `hudzones.spec`, stany z niższym pasem wiadomości na liście `THIN` tamże, a okna poza zasadami
  na liście `RATCHET` w `uiframe.spec`; te listy mogą tylko maleć.
- Pozostałe specy:
  - `topband.spec`, `noticequeue.spec`: pas wiadomości i kolejka;
  - `uiframe.spec`: okna, modale, dymki;
  - `gearlayout.spec`, `worldlayout.spec`: okna na PC i telefonie;
  - `sectionfold.spec`: każda sekcja ma domyślny stan;
  - `tutorial.spec`: samouczek wskazuje istniejące przyciski.
- Nowy tekst: wybierz powierzchnię i zmieść się w jej limicie. Nowa sekcja: dopisz id w `Data/Folds`. Nowy element
  HUD: daj mu miejsce w `HudZones` albo `PhoneHud`.
- Przegląd na ekranie robi właściciel. Nie piszemy list „do sprawdzenia w Studio”.
