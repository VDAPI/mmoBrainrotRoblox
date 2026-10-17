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

W13 (część 1): wzgórze młyna wyżej, spalony młyn z Tripo z dymem, horyzont Łąk (szczyty, Bór, mury miasta). Czeka na ocenę.

W12 (części 1–2): pierścień horyzontu (Łąki, Bór z Pradrzewem, wulkan Pustkowi, Szczyty); Iglica Ciernia i posąg Pani z Cierniem z Tripo w mieście, drzewa z zestawu, iglica świątyni, okna nocą, kolor słońca z porą dnia. Czeka na ocenę.

## Niedokończone

- W01: malowane niebo na 4 pory (`docs/wyglad/ZAKUPY.md`); Łąki, miasto i Szczyty na niebie miejsca.
- W01: pusta przestrzeń za brzegiem mapy widoczna przy horyzoncie jako szare pasmo, zanim streaming wczyta dalszy teren (tło gór / dalekie LOD w sesjach map W12–W20).
- W01: `ModelStreamingMode` / LOD `StreamingMesh` dla punktów orientacyjnych (D2) i `RenderFidelity` siatek (D3): do zrobienia przy przebudowie map (W12+).
- W01: automatyczny poziom `low` na telefonie przy pierwszym wejściu (W29).
- W02: zestaw ma warianty tylko dla Łąk (`grass`); Bór, Pustkowia, Szczyty, miasto na klockach do czasu zakupów albo darmowych paczek (Quaternius) w sesjach map.
- W02: modele zestawu i materiały żyją w miejscu (`Assets.Kit`, `MaterialService`): właściciel zapisuje miejsce.
- W02: drzewa wypełnienia i krzaki na kliencie przy niskiej jakości bez osobnego przycięcia (koszt +0,3 ms na PC); sprawdzić na telefonie (W29).
- W08: klipy Mixamo (`KLIPY-RUCH.md`) do pobrania przez właściciela; potem konwersja, pomiar `stride`, ID w `Locomotion.clips`.
- W08: zrzuty i nagrania ruchu, pływanie i atak w biegu nie obejrzane wizualnie (Studio w tle nie renderuje).
- W09: A2 (ciało z Tripo + Avatar Setup), ładniejsze kształty strojów (C2), blizna i piegi na dynamicznej głowie, przenikanie strojów w ruchu i chwyt broni nie oglądane.
- W10: kolor oczu (oczy w teksturze dynamicznej głowy), malunki nieobejrzane na twarzy (pozycja na głowie z obliczeń), wygląd fryzur warstwowych w podglądzie przybliżony.
- W13: Z1 (nowa ścieżka), rekwizyty expowisk, kwiaty i rośliny wodne, kapliczka i bramy; młyn i horyzont nieobejrzane w Studio.
- W12: horyzont miasta nieobejrzany z murów (kolory, odległości do strojenia w `Data/Horizons`); pozostałe mapy dostaną wpis w swoich sesjach (W13+).
- W08: IK bez obniżania bioder (wymagałoby zmiany fizyki); warianty klasowe ruchu (pomysł).
