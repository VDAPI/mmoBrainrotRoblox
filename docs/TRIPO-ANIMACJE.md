# Modele 3D z kośćmi i animacjami w Tripo (potwory, bossowie, NPC, wierzchowce)

Stan na 2026-10-12. Ten plik uzupełnia `PORADNIK-GRAFIKA.md` (§3 „Model 3D”). Broń robisz jak dotąd: bez kości i animacji.

## 1. Kolejność (najważniejsze w jednym miejscu)

```
szkic (jest) → Image to 3D → Smart Low Poly → tekstura 1024 → Auto Rig → animacje z biblioteki → eksport FBX → folder model/
                                  ^ najpierw redukcja, potem kości (odwrotnie psuje wagi)
```

Potem import do Roblox robi sesja kodu (S116) i powtarzalny prompt `docs/sessions/IMPORT-MODELI.md`. Ty klikasz tylko dwie rzeczy w Studio (§6).

**Zacznij od trzech modeli testowych:** `wolf` (czworonóg), `bandit` (człowiek), `carrionCrow` (ptak). Zrób je do końca, odpal import i zobacz w grze. Dopiero gdy działa, rób resztę. Tak nie stracisz kredytów na 24 modele z tym samym błędem.

## 2. Krok po kroku w Tripo

Nazwy przycisków w Tripo czasem się zmieniają; szukaj odpowiedników.

1. **Image to 3D**: wrzuć `szkic/<id>.png`. Jeśli model wyszedł krzywy (zrośnięte nogi, brak ogona), wygeneruj jeszcze raz, zanim zrobisz cokolwiek dalej.
2. **Smart Low Poly** (albo Reduce) do liczby trójkątów z tabeli w `PORADNIK-GRAFIKA.md` §4 (np. wilk 5–8 tys., boss 15–20 tys.). **Zawsze przed kośćmi.**
3. **Tekstura** 1024 px (małe potwory 512 px). Styl: lekko malowany, jak ikony.
4. **Auto Rig**: wybierz typ szkieletu z tabeli w §4. Dla ludzi i humanoidów wybierz nazewnictwo kości **Mixamo** (jeśli Tripo pyta o „spec”), wtedy pasują też animacje z Mixamo. Dla zwierząt zostaw domyślne.
5. **Sprawdź kości**: obróć model w podglądzie i puść dowolną animację chodu. Jeśli łapa ciągnie za sobą tułów albo ogon się rozrywa, zrób rig jeszcze raz (czasem pomaga inny typ szkieletu) albo zgłoś model jako „bez kości” (§5).
6. **Animacje z biblioteki**: dodaj klipy z §3. Wszystkie **w miejscu** (in place, bez przesuwania się do przodu): grę porusza serwer, animacja tylko macha nogami.
7. **Eksport: FBX**, z kośćmi i animacjami. Jeśli Tripo eksportuje wszystkie klipy w jednym pliku, zapisz jeden plik. Jeśli każdy klip osobno, zapisz każdy osobno (nazwy w §3).
8. Pliki do `modele_3d/potwory/<id>/model/` (NPC: `modele_3d/npc/<id>/model/`, wierzchowce: `modele_3d/wierzchowce/<id>/model/`). Teksturę (PNG), jeśli jest osobno, obok, pod tą samą nazwą.

## 3. Jakie animacje i jak je nazwać

Gra zna te sloty. Wystarczą pogrubione; resztę gra zastąpi sama (bieg → chód, drugi atak → pierwszy, rzucanie → atak).

| Slot | Kiedy gra go puszcza | Pętla | Długość |
|---|---|---|---|
| **`idle`** | stoi | tak | 2–4 s |
| **`walk`** | idzie | tak | 1 s |
| `run` | goni gracza | tak | 0,6–0,8 s |
| **`attack1`** | zwykły atak | nie | 0,6–1,0 s |
| `attack2` | specjalny atak (skok wilka, szarża dzika, uderzenie w ziemię) | nie | 0,8–1,5 s |
| `cast` | czar (szaman, kapłan, strzał łucznika) | nie | 0,8–1,2 s |
| **`hit`** | dostał cios | nie | 0,3–0,5 s |
| **`death`** | umiera, kończy leżąc na ziemi | nie | 1–2 s |
| `spawn` | pojawia się (bossowie, przyzwane) | nie | 1–2 s |
| `roar` | tylko bossowie: zmiana fazy | nie | 1,5–2,5 s |

Bossowie mają dodatkowo po jednym klipie na swój atak, nazwanym jak atak w grze (Grimrok: `sweep`, `leap`, `whirlwind`). Brakujące zastąpi `attack2`.

NPC: `idle` i `talk` (gest rozmowy), opcjonalnie `wave` (macha, gdy podchodzisz) i `work` (kowal kuje, rybak łowi).

**Nazwy plików:**
- jeden plik ze wszystkim: `model/<id>.fbx` (np. `model/wolf.fbx`);
- klipy osobno: `model/<id>.fbx` (model z kośćmi) i `model/<id>@<slot>.fbx` (np. `model/wolf@walk.fbx`, `model/wolf@attack1.fbx`).

Jeśli w bibliotece Tripo nie ma pasującego klipu (np. dziobanie kruka), weź najbliższy i dopisz w `model/uwagi.txt` jedno zdanie, co chciałeś. Sesja importu może dorobić brakujące ruchy w kodzie.

### 3a. Gdy w Tripo nie ma ataku (albo innego ruchu)

Najlepiej **Mixamo** (darmowe, dużo ataków mieczem, toporem, pięścią, czarów) dla postaci człekokształtnych:
1. Z Tripo eksportuj model **po redukcji, z teksturą**, z kośćmi Mixamo albo bez kości (FBX).
2. mixamo.com → Upload Character → ten FBX (jeśli prosi o znaczniki: podbródek, nadgarstki, łokcie, kolana, pachwina).
3. Wybierz animacje (np. „Sword And Shield Slash” → `attack1`, „Great Sword Slash” → `attack2`, „Hit Reaction” → `hit`, „Dying” → `death`), zaznacz **In Place**.
4. Download FBX: pierwsza **With Skin** (zapisz jako `<id>.fbx`), kolejne **Without Skin** (`<id>@<slot>.fbx`).
Wtedy wszystkie klipy są na jednym szkielecie. Zwierząt Mixamo nie obsługuje: dla nich brakujący ruch zrobi import (niżej).

Jeśli klipu nie ma wcale, prompt `IMPORT-MODELI.md` zrobi prosty klip sam w Studio (zamach, cios, powrót) do opublikowania, a gra po S117 i tak pochyli model przy ciosie.

## 4. Typ szkieletu dla każdego modelu (Łąki)

| Folder | Typ w Auto Rig | Klipy obowiązkowe + specjalne | Uwagi |
|---|---|---|---|
| `wolf` | czworonóg (quadruped) | + `attack2` skok, `run` | |
| `lynx` | czworonóg | + `attack2` skok, `run` | |
| `boar` | czworonóg | + `attack2` szarża, `run` | |
| `brownBear` | czworonóg | + `attack2` uderzenie łapami w ziemię | może stanąć na tylnych łapach w `attack2` |
| `rabbit` | czworonóg | `idle`, `walk` (kicanie), `hit`, `death` | nie atakuje |
| `swampToad` | czworonóg | + `attack2` plucie (jak `cast`) | jeśli rig się nie uda: „bez kości” (§5) |
| `carrionCrow` | ptak (avian) | + `attack2` krzyk, lot jako `walk` | |
| `caveSpider` | ośmionóg (octopod) | + `attack2` plucie jadem | |
| `bandit` | człowiek (biped, Mixamo) | + `attack2` szerokie cięcie | broń w ręce jest częścią modelu |
| `goblinScout` | człowiek (biped, Mixamo) | + `attack2` skok z uderzeniem | |
| `goblinShaman` | człowiek (biped, Mixamo) | + `cast`, `attack2` (fala kości) | |
| `koboldMiner` | człowiek (biped, Mixamo) | + `attack2` uderzenie kilofem w ziemię | |
| `grimrok` (boss) | człowiek (biped, Mixamo) | wszystkie sloty + `roar`, `sweep`, `leap`, `whirlwind` | 15–20 tys. trójkątów |
| NPC (`anzelm`, `bartosz`, …) | człowiek (biped, Mixamo) | `idle`, `talk`, opcjonalnie `wave`, `work` | 4–7 tys. trójkątów |

**Elity (`_elite`, `_elite2`):** najpierw zrób zwykłą wersję. Gra robi Elitę z tego samego modelu (większa, z aurą i świecącymi oczami; rogi i runy z kodu są tylko na modelach z generatora). Osobny model Elity rób tylko wtedy, gdy szkic Elity mocno się różni; wtedy ma własne kości i te same nazwy klipów, w folderze `<id>_elite/model/`.

**Mixamo zamiast animacji Tripo (tylko ludzie):** jeśli animacje humanoidów z Tripo wyglądają słabo, wyeksportuj z Tripo model z kośćmi Mixamo bez animacji, wgraj go na mixamo.com (darmowe, konto Adobe), wybierz animacje („In Place” zaznaczone), pobierz każdą jako FBX „Without Skin” i zapisz jako `<id>@<slot>.fbx`.

## 5. Gdy kości się nie udają

Szlamy, duchy, drzewa, węże i dziwne kształty często nie dają się dobrze zriggować. Wtedy:
- wyeksportuj model **bez kości** (FBX albo GLB) jako `model/<id>.fbx` i dopisz w `model/uwagi.txt`: `bez kości`;
- gra poruszy go sama (podskok, kołysanie, pochylenie przy ataku), tak jak dziś pety. Wygląda dobrze przy szlamach i duchach, gorzej przy zwierzętach z nogami.

## 6. Co klikasz w Studio (resztę robi Claude)

Sesja importu sama ułoży model, gniazda, skalę, wpis w danych gry i sprawdzi animacje na zrzutach z Studio. Ty:
1. **Import 3D**: Studio → Import 3D → wskaż plik `model/<id>.fbx` (Rig Type: Custom albo R15 dla ludzi, jeśli Studio to podpowie; „Upload to Roblox” włączone). Możesz zaznaczyć kilka plików naraz.
2. **Publikacja klipów**: animacje zaimportowane z FBX trzeba opublikować na Twoim koncie (albo grupie gry): Animation Clip Editor → ⋯ → Publish to Roblox. Sesja importu powie dokładnie, które klipy i gdzie je znajdziesz, a potem sama wpisze ID.
3. **Save to File**: gotowy model (sesja przeniesie go do `ReplicatedStorage.Assets`) prawym przyciskiem → Save to File → do folderu `assets/...` w repo, pod nazwą, którą poda sesja. Dzięki temu model jest w repozytorium, a nie tylko w miejscu gry.

Import uruchamiasz, wklejając Claude Code plik `docs/sessions/IMPORT-MODELI.md` (po sesji S116), ze Studio otwartym. Możesz to robić za każdym razem, gdy dojdą nowe modele.

Wszystko wgrywasz z konta właściciela gry (albo grupy). Modele i animacje z cudzego konta nie wczytają się w grze.

## 7. Ile to kosztuje i co ma pierwszeństwo

Kredyty Tripo zużywa każde generowanie, redukcja, rig i animacja. Kolejność opłacalna dla gracza:
1. 3 modele testowe (§1);
2. potwory Łąk, które gracz widzi najczęściej: wilk, dzik, bandyta, goblin zwiadowca, ryś, królik;
3. Grimrok (boss) i NPC miasta;
4. reszta Łąk, potem Elity, potem kolejne krainy, gdy będą szkice.

Potwory bez modelu dalej wyglądają jak dziś (generator z części), więc gra działa w każdym momencie.
