# Klipy ruchu postaci gracza (W08) z Mixamo

> Kopia: `Graphics\animacje\KLIPY-RUCH.md`. Lokomocja w grze: `src/shared/Data/Locomotion.luau` (do czasu nowych klipów grają domyślne klipy Roblox R15). Konwerter i publikacja jak dla ataków (`Graphics\animacje\PRZECZYTAJ.md`, kroki 1–3).

## Ustawienia pobierania (każdy plik tak samo)

- mixamo.com → Animations, postać domyślna **Y Bot**.
- **In Place** zaznaczone dla chodu, biegu, truchtu i pływania (gra sama przesuwa postać; klip ma iść w miejscu).
- Download: **FBX Binary**, **Without Skin**, **30 fps**, Keyframe Reduction **none**.
- Zapisz pod nazwą z kolumny „Plik” do `Graphics\animacje\gracz\fbx\ruch\`.
- Styl: poważne fantasy. Jeśli tytułu nie ma albo ruch jest „kreskówkowy” (podskakiwanie, machanie), weź najbliższy spokojny i zapisz pod tą samą nazwą; dopisz wybór w `gracz\fbx\ruch\uwagi.txt`.

## Lista (12 klipów)

| Pierw. | Plik | Szukaj w Mixamo | Stan w grze (`Locomotion.clips`) | Pętla |
|---|---|---|---|---|
| 1 | `ruch_idle.fbx` | Breathing Idle (zapas: Standing Idle) | `idle` | tak |
| 2 | `ruch_idle_rozgladanie.fbx` | Looking Around (krótkie rozejrzenie, bez obrotu stóp) | `idleVariants[1]` | nie |
| 2 | `ruch_idle_ramiona.fbx` | Weight Shift (zapas: Standing Idle 02) | `idleVariants[2]` | nie |
| 1 | `ruch_walk.fbx` | Walking (In Place) | `walk` | tak |
| 1 | `ruch_run.fbx` | Running (In Place; zapas: Standard Run) | `run` | tak |
| 3 | `ruch_jog.fbx` | Jogging (In Place); tylko jeśli przejście chód→bieg wygląda źle | (trucht, przyszły stan) | tak |
| 1 | `ruch_skok.fbx` | Jump (krótkie wybicie, bez lądowania; przytnij do momentu oderwania) | `jump` | nie |
| 1 | `ruch_upadek.fbx` | Falling Idle | `fall` | tak |
| 2 | `ruch_ladowanie.fbx` | Falling To Landing (tylko końcowe przysiad i wstanie) | `land` | nie |
| 2 | `ruch_wspinanie.fbx` | Climbing Ladder (zapas: Climbing Up Wall) | `climb` | tak |
| 2 | `ruch_plywanie.fbx` | Swimming (In Place) | `swim` | tak |
| 3 | `ruch_unoszenie.fbx` | Treading Water | `swimIdle` | tak |

## Co dalej

1. Ty: pobierz pliki z pierwszeństwem 1 (5 klipów, ok. 10 min), potem 2 i 3; napisz w wątku „przekonwertuj ruch”.
2. Claude: konwersja (`--loop` dla pętli, priorytet Idle / Movement, bez `Hit`), podgląd, wstawienie do Studio i obejrzenie na postaci, pomiar `stride` (bez ślizgu stóp), lista do publikacji w `ID-KLIPOW.md` → „Ruch”.
3. Ty: publikacja w Studio (prawy na `KeyframeSequence` → Save to Roblox), ID do `ID-KLIPOW.md`.
4. Claude: ID do `Data/Locomotion.clips` (domyślne klipy Roblox zostają w `fallback`).
