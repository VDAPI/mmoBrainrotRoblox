# Dziennik sesji fazy wyglądu (W01–W29)

### W01 (kod, 2026-10-17, wątek „Wzorzec wyglądu gry”, chmura bez Studio)

**Co zrobiono**
- `Data/MapLooks` (nowy): wygląd mapy na presecie z `Data/Maps`; domyślny na zewnątrz i pod ziemią, nadpisania: miasto (cykl dnia i nocy, ciepłe słońce), Łąki (16,6, złote słońce), Bór (17,8, pochmurno, snopy światła), Pustkowia (17,6, zachód), Szczyty (8,5, zimny poranek). Pod ziemią bez promieni, chmur i głębi ostrości, mocniejszy bloom lamp.
- `WorldController`: stała godzina z `MapLooks` zastępuje cykl poza miastem (`TimeOfDay`, `HasDayNight`), `ColorShift_Top` (kolor słońca), kontrast i jasność korekcji, `VaelthornBloom`, `VaelthornSunRays`, `VaelthornFarBlur`, `Clouds` w `Terrain`, niebo z `ReplicatedStorage.Assets.Sky` (gdy jest), wszystko skalowane poziomem grafiki i odświeżane przy zmianie poziomu.
- `default.project.json`: `Lighting` Future, Soft, cienie, `ShadowSoftness` 0,2, skale otoczenia 1.
- Poziomy grafiki `low` / `medium` / `high` (`Config.Graphics`, opcja „Jakość grafiki” z trzema stanami, walidacja `SettingsService`), cząsteczki ×1/3 / ×0,7 / ×1 (`SettingsController`).
- Kamera „z góry” (`CameraController` nowy, `Config.Camera`, opcja „Kamera: Swobodna / Z góry”, `settings.cameraMode`).
- „Odczucie trafień (wstrząs i zatrzymanie)”: `settings.shake` skaluje też hitstop.

**Testy:** `tests/maplooks.spec.luau` (nowy: zakresy, pod ziemią bez promieni i chmur, cykl tylko w mieście, poziomy grafiki, zakres kamery); `tools/balance_reasons.luau` (`Data/MapLooks` = wygląd). Lune 7731 / 0, StyLua, luau-lsp i `wiki_keys_diff` zielone. Selene nie uruchomiony: w kontenerze nie pobiera API Roblox (blokada sieci); do sprawdzenia przy `scripts/check` na komputerze.

**Pliki:** `src/shared/Data/MapLooks.luau` (nowy), `src/client/Controllers/CameraController.luau` (nowy), `src/client/Controllers/{WorldController,SettingsController,AnimationController}.luau`, `src/client/UI/Screens/GameMenu.luau`, `src/server/Services/SettingsService.luau`, `src/shared/{Config,Types}.luau`, `src/shared/Logic/AccountSchema.luau`, `src/shared/Data/Localization/{pl,en}.luau`, `default.project.json`, `tests/maplooks.spec.luau`, `tools/balance_reasons.luau`, `CLAUDE.md`, `docs/DESIGN-16.md`, `docs/WYGLAD.md`, `docs/wyglad/*`.

**Dla właściciela**
- Zrzuty i strojenie w Studio robi osobna sesja na Twoim komputerze (patrz `docs/wyglad/STAN-W.md` → „Niedokończone”), potem Twoja ocena „W01: OK” albo co poprawić.
- Na mapach regionów nie ma już nocy (Twoja decyzja), więc zorza na Lodowych Szczytach i nocne świetliki na Łąkach się nie pokazują. Jeśli chcesz którąś mapę nocą, wystarczy zmienić jej godzinę w `Data/MapLooks`.
