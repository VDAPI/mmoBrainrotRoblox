# Faza wyglądu: stan (gałąź `wyglad`)

> Krótki stan sesji W. Plan i oceny: `docs/WYGLAD.md`. Dziennik: `docs/wyglad/SESJE-W.md`. Decyzje: `docs/wyglad/DECYZJE-W.md`.

## Stan

W01 (kod): profil wyglądu każdej mapy (`Data/MapLooks`), Future + Soft w `default.project.json`, bloom / promienie / głębia ostrości / chmury / niebo w `WorldController`, trzy poziomy grafiki, kamera „z góry”, suwak odczucia trafień (wstrząs + hitstop).
W01 (Studio): liczby map i jaskini Mchów nastrojone na zrzutach, niebo Boru i Pustkowi (`assets/Sky`), Soft zostaje, każda jaskinia i komnata bossa w swoim kolorze (§4.3), noc w mieście jaśniejsza, kamera z góry sprawdzona pod ziemią, koszt `low` / `high` zmierzony. Ocena właściciela: W01: OK (2026-10-17); następna W02.

W02: zestaw zasobów (`Data/Kit`, `Assets.Kit`, `/kit`), darmowe drzewa, krzaki i skały na Łąkach, malowana skała gór Łąk, lista zakupów i zasady importu. Czeka na ocenę właściciela.

## Niedokończone

- W01: malowane niebo na 4 pory (`docs/wyglad/ZAKUPY.md`); Łąki, miasto i Szczyty na niebie miejsca.
- W01: pusta przestrzeń za brzegiem mapy widoczna przy horyzoncie jako szare pasmo, zanim streaming wczyta dalszy teren (tło gór / dalekie LOD w sesjach map W12–W20).
- W01: `ModelStreamingMode` / LOD `StreamingMesh` dla punktów orientacyjnych (D2) i `RenderFidelity` siatek (D3): do zrobienia przy przebudowie map (W12+).
- W01: automatyczny poziom `low` na telefonie przy pierwszym wejściu (W29).
- W02: zestaw ma warianty tylko dla Łąk (`grass`); Bór, Pustkowia, Szczyty, miasto na klockach do czasu zakupów albo darmowych paczek (Quaternius) w sesjach map.
- W02: modele zestawu i materiały żyją w miejscu (`Assets.Kit`, `MaterialService`): właściciel zapisuje miejsce.
- W02: drzewa wypełnienia i krzaki na kliencie przy niskiej jakości bez osobnego przycięcia (koszt +0,3 ms na PC); sprawdzić na telefonie (W29).
