# Faza wyglądu: stan (gałąź `wyglad`)

> Krótki stan sesji W. Plan i oceny: `docs/WYGLAD.md`. Dziennik: `docs/wyglad/SESJE-W.md`. Decyzje: `docs/wyglad/DECYZJE-W.md`.

## Stan

W01 (kod): profil wyglądu każdej mapy (`Data/MapLooks`), Future + Soft w `default.project.json`, bloom / promienie / głębia ostrości / chmury / niebo w `WorldController`, trzy poziomy grafiki, kamera „z góry”, suwak odczucia trafień (wstrząs + hitstop).
W01 (Studio): liczby map i jaskini Mchów nastrojone na zrzutach, niebo Boru i Pustkowi (`assets/Sky`), Soft zostaje, kamera z góry sprawdzona pod ziemią, koszt `low` / `high` zmierzony. Czeka na ocenę właściciela („W01: OK” w `docs/WYGLAD.md` §6).

## Niedokończone

- W01: jaskinie i komnaty poza Jaskinią Mchów mają tylko wspólną korekcję pod ziemią (+0,04 jasności); własne kolory każdej jaskini (§4.3) w W21–W24.
- W01: malowane niebo na 4 pory (`docs/wyglad/ZAKUPY.md`); Łąki, miasto i Szczyty na niebie miejsca.
- W01: pusta przestrzeń za brzegiem mapy widoczna przy horyzoncie jako szare pasmo, zanim streaming wczyta dalszy teren (tło gór / dalekie LOD w sesjach map W12–W20).
- W01: `ModelStreamingMode` / LOD `StreamingMesh` dla punktów orientacyjnych (D2) i `RenderFidelity` siatek (D3): do zrobienia przy przebudowie map (W12+).
- W01: automatyczny poziom `low` na telefonie przy pierwszym wejściu (W29).
