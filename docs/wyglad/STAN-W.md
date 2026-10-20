# Faza wyglądu: stan (gałąź `wyglad`)

> Krótki stan sesji W. Plan i oceny: `docs/WYGLAD.md`. Dziennik: `docs/wyglad/SESJE-W.md`. Decyzje: `docs/wyglad/DECYZJE-W.md`.

## Stan

W01 (kod): profil wyglądu każdej mapy (`Data/MapLooks`), Future + Soft w `default.project.json`, bloom / promienie / głębia ostrości / chmury / niebo w `WorldController`, trzy poziomy grafiki, kamera „z góry”, suwak odczucia trafień (wstrząs + hitstop).
W01 (Studio): liczby map i jaskini Mchów nastrojone na zrzutach, niebo Boru i Pustkowi (`assets/Sky`), Soft zostaje, każda jaskinia i komnata bossa w swoim kolorze (§4.3), noc w mieście jaśniejsza, kamera z góry sprawdzona pod ziemią, koszt `low` / `high` zmierzony. Ocena właściciela: W01: OK (2026-10-17); następna W02.

W02: zestaw zasobów (`Data/Kit`, `Assets.Kit`, `/kit`), darmowe drzewa, krzaki i skały na Łąkach, malowana skała gór Łąk, lista zakupów i zasady importu. Ocena właściciela: W02: OK (2026-10-17).

W11: plan wszystkich map (`docs/wyglad/MAPY.md`, `docs/wyglad/mapy/*.md`), ocena właściciela: W11: OK (2026-10-17, rekomendacje 1–5, mapy wolno przebudować całe); następna W08.

W08: własny `Animate` (lokomocja z `Data/Locomotion`, przenikanie chód/bieg, skok, upadek, lądowanie, wspinanie, pływanie, warianty bezczynności), IK stóp; klipy jeszcze domyślne Roblox. Czeka na ocenę właściciela.

W09: ciało Roblox „Base Body - Dawson” z dynamiczną głową dla wszystkich, fryzury z katalogu w kolorze kreatora, broda na nowej głowie. Czeka na ocenę.

W10: kreator postaci (8 twarzy, brwi, zarost, 12 fryzur, 12 kolorów włosów, 12 skór, budowa, malunki), zakładki, podgląd z obrotem i zbliżeniem. Czeka na ocenę.

W17 (część 1): skały Pustkowi w rdzy i bazalcie, dymiący Szczyt Kuźni w osi traktu. Czeka na ocenę.

W19 (część 1): sosny Szczytów z zestawu (oszroniona zieleń). Czeka na ocenę.

W15 (część 1): drzewa Boru z zestawu (ciemne liście), rzadsza atmosfera. Czeka na ocenę.

W13 (część 1): wzgórze młyna wyżej, spalony młyn z Tripo z dymem, horyzont Łąk (szczyty, Bór, mury miasta). Czeka na ocenę.

W12 (części 1–2): pierścień horyzontu (Łąki, Bór z Pradrzewem, wulkan Pustkowi, Szczyty); Iglica Ciernia i posąg Pani z Cierniem z Tripo w mieście, drzewa z zestawu, iglica świątyni, okna nocą, kolor słońca z porą dnia. Czeka na ocenę.

W14 / W16 / W18 / W20 (części 1, 2026-10-18/19): sekrety i brakujące rekwizyty z tabel planów map (Łąki, Bór bez krwi, Pustkowia `AshenGen/Details`, Szczyty `FrostpeakGen/Details`). Czeka na ocenę.

W21–W24 (sekrety jaskiń z planów): wszystkie punkty „Sekrety” i „dodać” z `laki.md`, `bor.md`, `pustkowia.md`, `szczyty.md` w kodzie. Strojenie światła jaskiń na oko czeka na Studio.

W25 / W26: 47 modeli Tripo w grze (`Data/MonsterAssets`, modele w miejscu w `Assets.Monsters`); 27 dwunożnych z klipami (`Data/MonsterClips`, `client/Anim/BoneClips`), 20 czworonogów i latających ruszanych całym ciałem (`Gait_Body`). Brak: własne klipy czworonogów, ataki z bronią zamiast Zombie Attack, modele bossów bez Tripo (Vaelgrath i inne z listy).

W28 (części 1–2): liczby obrażeń (obrys, połysk, wyskok, dryf); okna i okna dialogowe otwierają się na sprężynie i zamykają tą samą drogą, wyskakujące karty wskakują; przyciski HUD z welonem przy najechaniu i wciśnięciem; pasek HP ze śladem straconego zdrowia i oddechem przy niskim HP; toasty wchodzą i gasną; obrysy HUD z tokenów. Nieobejrzane w Studio. Czeka na ocenę.

W13–W20 (części 2, kod, nieobejrzane): rekwizyty, postoje, roślinność i sekrety z planów czterech map (`MeadowsGen/Dressing`, `DuskwoodGen/Dress`, `AshenGen/Finish`, `FrostpeakGen/Scenery`). W03–W07: styl pilota na wszystkich klasach (8 nowych tekstur, `rockBurst`, `warCry`, `holyBurst`, `leafBurst`, swoosh). W27: 194 z 215 pętli otoczenia z ProSoundEffects (nieodsłuchane).

## Niedokończone

- W01: malowane niebo na 4 pory (`docs/wyglad/ZAKUPY.md`); Łąki, miasto i Szczyty na niebie miejsca.
- W01: pusta przestrzeń za brzegiem mapy widoczna przy horyzoncie jako szare pasmo, zanim streaming wczyta dalszy teren (tło gór / dalekie LOD w sesjach map W12–W20).
- W01: punkty orientacyjne ≥ 30 st. (`landmark:*`) są `Persistent` (W29); w grze nieobejrzane, czy model zagnieżdżony w modelu budowli zostaje za promieniem 512. `RenderFidelity` siatek (D3) nieskryptowalne: ustawić na modelach w `Assets.Kit` w Studio.
- W02: zestaw ma warianty tylko dla Łąk (`grass`); Bór, Pustkowia, Szczyty, miasto na klockach do czasu zakupów albo darmowych paczek (Quaternius) w sesjach map.
- W02: modele zestawu i materiały żyją w miejscu (`Assets.Kit`, `MaterialService`): właściciel zapisuje miejsce.
- W02: drzewa wypełnienia i krzaki na kliencie przy niskiej jakości bez osobnego przycięcia (koszt +0,3 ms na PC); sprawdzić na telefonie (W29).
- W08: zrzuty i nagrania ruchu, pływanie i atak w biegu nie obejrzane wizualnie (Studio w tle nie renderuje).
- W09: A2 (ciało z Tripo + Avatar Setup), ładniejsze kształty strojów (C2), blizna i piegi na dynamicznej głowie, przenikanie strojów w ruchu i chwyt broni nie oglądane.
- W10: kolor oczu (oczy w teksturze dynamicznej głowy), malunki nieobejrzane na twarzy (pozycja na głowie z obliczeń), wygląd fryzur warstwowych w podglądzie przybliżony.
- W15: Pradrzewo (model `forest_landmark_03`), płaczki, kamień kultu, ruiny kaplicy (modele Tripo); czerwony piaskowiec Urwisk (materiał w Studio).
- W17/W19: modele Tripo Bramy z Żeber, Skamieniałej Wywerny, kolosa, lodospadu, strażnic i gniazda harpii; rampa Z2 Szczytów i Szlak Popiołu (ruszają grupy).
- W03–W07, W13–W20, W27: nic nieobejrzane w Studio (podgląd przy następnym wolnym Studio).
- W13: Z1 (nowa ścieżka) próbowana i cofnięta: przelosowuje grupę wilków (−304, −81) aż do (−413, 238), co zmienia zlecenia łowieckie (S134k, `contracts_gen`, `quest_budget`) i daje stromiznę 36° przy brodzie (−32, −420); wymaga sesji z balansem albo stałego miejsca grupy. Też: rekwizyty expowisk, kwiaty i rośliny wodne, kapliczka i bramy; młyn i horyzont nieobejrzane w Studio.
- W12/W13: horyzonty miasta, Łąk, Boru, Pustkowi i Szczytów nieobejrzane w Studio (kolory, odległości do strojenia w `Data/Horizons`).
- W08: IK bez obniżania bioder (wymagałoby zmiany fizyki); warianty klasowe ruchu (pomysł).
