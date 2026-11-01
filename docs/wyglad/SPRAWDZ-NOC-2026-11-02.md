# Do sprawdzenia w Studio: noc 1→2 listopada 2026

Lista dla laptopa (Studio przez MCP, bez myszy). Zmiany z chmury na `main`. Po każdym punkcie: działa / nie działa i co widać.

## Wieczne kamienie teleportu
1. Kup lub dostań Wieczny Kamień Mapy i użyj go. Sprawdź okno „Ustawić kamień na stałe? … Tego wyboru nie da się zmienić.”, a po teleporcie podpowiedź w plecaku: „Ustawiony na: …” i „Odpoczywa jeszcze N min”.
2. Użyj go od razu drugi raz. Ma wyskoczyć jeden toast z minutami, bez teleportu.
3. Wieczny Kamień Lochu: wybierz loch i potwierdź. Teleport ma trafić przed wejście, podpowiedź pokazać nazwę lochu. Kolejne użycie leci prosto, bez wyboru.
4. Ustaw kamień na mapę, na której stoisz. Ma być toast o ustawieniu, bez teleportu i bez odpoczynku.
5. U Mistrza Portali (Teodor) kup drugi Wieczny Kamień Mapy. Sprawdź treść pytania i czy kamień ląduje w osobnym slocie.
6. Spróbuj odłożyć wieczny kamień do depozytu. Ma być odmowa.
7. `/time +1800` albo odczekaj 30 min: kamień znów działa, także po ponownym wejściu do gry.

## Gesty (animacje Roblox)
1. `/e wave` (`/e machaj`), `/e point` (`/e wskaz`), `/e cheer` (`/e wiwat`): animacja Roblox, nie ruch z kodu.
2. `/e wave` i od razu idź: gest gaśnie płynnie. `/e cheer` i od razu atak: gest się urywa.
3. `/e wave` w biegu: ruch z kodu (sama ręka).
4. Test > 2 Players: drugi gracz widzi ten sam klip, raz.
5. `/e bow`, `/e sit`: bez zmian. Garderoba, zakładka Gesty: podgląd Pozdrowienia gra klip.
6. Na blokowym ciele klipy wyglądają dobrze? Gdy gest gra z kodu: `CharacterClips.status()`, wpis „failed” = id się nie wczytało.

## Wrony i sępy
1. Łąki, Krucze Pole: żadnej ozdobnej wrony w powietrzu ani na drzewach; Wrony Padlinożerne (potwory) są.
2. Martwe drzewa na reszcie Łąk, w Mrocznym Borze i na Pustkowiach: ptak na końcu gałęzi, nie w powietrzu. Szczególnie drzewa z modelem `tree:blackDead`.
3. Wrona przy Starym Drzewie Boru i sęp na żebrach Pustkowi (stoją przy modelach z zestawu, test ich nie sprawdza).

## Szczęka Vaelgratha
1. `/animlab mob vaelgrath idle`. Gdy pyska nie znajdzie, Studio wypisze teraz `[MeshJaw] … the side view` i mapę głowy z boku (czubek pyska po lewej): `#` ściany, `o` otwór wzięty za pysk, `.` inne szczeliny, `|` linia `from`.
2. Dostrój w `Data/BipedRigs.luau` `jaw("vaelgrath")`: `bridge` (ile komórek zęba nie dzieli pyska, domyślnie 3), `minColumns`, `gapMin`, `from`, `cells`. Obejrzyj `roar`, `bite`, `breath`, `deathDragon`: dolna szczęka rusza się cała, górna i czaszka stoją, nic się nie rwie.
3. Jeśli się nie da, wyślij mapę do chmury.
