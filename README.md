# Vaelthorn

MMORPG na Roblox w stylu Margonem, tylko w 3D. Kod w Luau, synchronizowany do Roblox Studio przez Rojo.

## Instalacja (Windows, jednorazowo)

1. **Rokit** (menedżer narzędzi): w PowerShell
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
   Zamknij i otwórz terminal ponownie.
2. W folderze repozytorium:
   ```powershell
   rokit install
   ```
   Instaluje wersje z `rokit.toml`: rojo, wally, wally-package-types, stylua, selene, luau-lsp, lune.
3. **Plugin Rojo w Studio**: `rojo plugin install` (albo z Creator Store: „Rojo”).
4. **VS Code** (opcjonalnie): zainstaluj polecane rozszerzenia z `.vscode/extensions.json`
   (Luau Language Server, StyLua, Selene).

Paczki Wally (`Packages/`, `ServerPackages/`) są w repozytorium, więc `wally install` nie jest potrzebne.
Po zmianie `wally.toml`: `wally install`, potem
`wally-package-types --sourcemap sourcemap.json Packages/` i to samo dla `ServerPackages/`.

## Uruchomienie

1. W folderze repozytorium: `rojo serve`
2. Roblox Studio → nowy Baseplate (lub Twój opublikowany place) → zakładka Plugins → Rojo → **Connect**.
3. **Play**. Pojawi się ekran wyboru postaci.

### Zapisywanie danych

Bez dostępu do DataStore gra używa pamięci tymczasowej (ostrzeżenie w Output i na ekranie wyboru postaci),
a dane znikają po zakończeniu testu. Żeby dane się zapisywały:

1. Opublikuj place (File → Publish to Roblox).
2. Game Settings → Security → **Enable Studio Access to API Services**.

### Komendy admina

W Studio każdy jest adminem. Na serwerach live: dopisz swoje UserId do `AdminUserIds` w
`src/shared/Config.luau` (numer z adresu profilu `roblox.com/users/<id>/profile`).
W czacie wpisz `/help`, żeby zobaczyć listę komend. Panel developerski (**F2** albo złoty przycisk „DEV” na
ekranie) ma te same komendy w zakładkach; poza Studio też wymaga UserId w `Config.AdminUserIds`. Pełna lista komend
z argumentami: `docs/ARCHITECTURE.md` §11.

### Test wielu graczy

Studio → Test → Clients and Servers → liczba graczy 2 → Start.

## Sprawdzanie kodu

```powershell
.\scripts\check.ps1
```
Kolejno: StyLua (format), Selene (lint), sourcemap Rojo, luau-lsp (typy), testy Lune.
Przy pierwszym uruchomieniu pobiera `globalTypes.d.luau` (definicje API Roblox dla luau-lsp).
Na Linux/macOS/CI: `bash scripts/check.sh`.

Formatowanie automatycznie: `stylua src tests`.

## Dokumentacja

- `docs/DESIGN.md` – zasady gry i liczby
- `docs/ARCHITECTURE.md` – architektura techniczna
- `docs/PROGRESS.md` – postęp, decyzje, instrukcje testów po każdej sesji
- `CLAUDE.md` – zasady dla Claude Code
