# DESIGN-17: sklep premium, VIP, rankingi, arena i wydarzenia PvP (S120–S132)

Kontrakt dla sesji S120–S132. Właściciel (ProjektG, 2026-10-13) przyjął rekomendacje z `PROPOZYCJA.md` (VIP bez EXP, rankingi przez wspólne tabele Roblox, arena z kolejką globalną i fallbackiem, eventy zsynchronizowane zegarem UTC) i dopisał przedmioty do sklepu: peleryna przyciągająca potwory, +10 miejsc w każdym plecaku, mikstura pełnego leczenia (z ograniczeniami z `KATALOG.md`, zaakceptowane „na razie git”). Sesje idą **po S119** w kolejce DALEJ. Kod w chwili pisania: `3a1ee36` (S87); S88–S119 są w planie (`docs/sessions/S88..S119.md`), więc nazwy i linie mogą się przesunąć. **Wygrywa kod.**

Ten plik trafia do repo jako `docs/DESIGN-17.md`. Odejście od niego = linia w `docs/DECYZJE.md` i poprawka tego pliku w tym samym commicie.

## 0. Zasady wspólne

1. Wszystkie zasady fazy gameplay z `CLAUDE.md` i reguły z DESIGN-15 §0 (Locale PL+EN, `--!strict`, liczby tylko w `Data/*` i `Config.luau`, `Logic`/`Data` bez API Roblox, losowość przez `Logic/Rng`, serwer autorytetem, remote'y z typami i rate-limitem w `Net/Definitions.luau`, `scripts/check` zielony, DECYZJE, SESJE, PROGRESS, commit `SXX: …`, push). Bez uruchamiania gry i bez instrukcji testów w Studio (wyjątek §0.1 DESIGN-16 dotyczy tylko S110–S119).
2. **Bez pay2win** (twarda zasada, test `tests/paywall.spec.luau` od S120, każda kolejna sesja go rozszerza): nic kupionego za Robux ani Smocze Odłamki nie daje statów, EXP, złota, dropu, materiałów ulepszania ani błogosławieństw. Dozwolone: wygląd, wygoda (miejsce, czas, teleport), szybsza farma tylko przez Płaszcz Przynęty (§3) i leczenie poza walką z graczami i bossami (§3). Rankingi i arena **nie** mogą zależeć od zakupów.
3. **Pieniądze i paragony:** każdy zakup produktu idzie przez istniejący `MonetizationService` (`ProcessReceipt` idempotentny przez `account.purchases[receiptId]`, `NotProcessedYet`, gdy profil niegotowy). Nowe produkty rejestrują handler `MonetizationService.RegisterProduct(key, handler)`. Id produktów/przepustek w `Data/Products` = `0` (placeholder; symulacja tylko w Studio, na żywym serwerze odmowa `premium.error.notConfigured`). Właściciel wkleja id z Creator Hub; ostatnia wiadomość sesji mówi, które id są potrzebne.
4. **Usługi Roblox między serwerami** (DataStore, OrderedDataStore, MemoryStore, MessagingService, TeleportService) tylko w nowych modułach serwera z `pcall`, ponowieniami (wzór `src/server/Market/Retry.luau`, `KeyStore.luau`) i **atrapą w pamięci**, gdy brak dostępu do API (Studio bez „Enable Studio Access to API Services”, Lune). Gra na jednym serwerze działa zawsze; funkcje między serwerami to dodatek. Limity: zapis wyniku gracza do rankingu najwyżej raz na 60 s na klucz (i przy wyjściu), odczyt top 100 jednej tablicy najwyżej raz na 5 min na serwer, kolejka areny: odpytywanie co 3–5 s z rozrzutem. Liczby w `Config`.
5. **Księga balansu (S83):** liczby tempa i ekonomii (np. nagrody Żetonów, ceny sklepu areny, nagrody eventów) w modułach z `BALANCE_MODULES` albo `NOT_BALANCE` z powodem. `Data/Products` zostaje `NOT_BALANCE` („sekret”). Poziomy 1–20 zamrożone (`ALLOWED_1_20_DIFFS`): te sesje nie zmieniają EXP ani dropu, więc różnic być nie powinno.
6. **Wiki:** eksport tylko z listy dozwolonych. `Data/Products`, ceny w Robux, id produktów i kody nigdy. Jedyny moduł eksportera czytający `Products` to `tools/WikiData/Premium.luau` (przepustki i usługi bez cen); S131 może go rozszerzyć o nowe przepustki i rodzaje przedmiotów, nadal bez cen i id. `WIKI_KEYS_ALLOW` opisany w SESJE.
7. **Zapis:** nowe pola z wartościami domyślnymi przez mechanizm uzupełniania (`Logic/AccountSchema`, `DataService`, `CharacterFactory`); migracja tylko przy przebudowie kształtu, numer = następny po ostatnim w kodzie, z testem.
8. Nic nie udaje działania. Produkt bez id na żywym serwerze pokazuje „Wkrótce” zamiast przycisku kupna; funkcja między serwerami bez dostępu do usług pokazuje stan „tylko ten serwer” zamiast pustej listy.
9. **Telefon i PC:** każde nowe okno działa dotykiem (wzór istniejących okien, `UI/Device`, `UI/Scale`), ma przycisk w `GameMenu` i ewentualny klawisz w `Data/Keybinds` (tylko z wolnych liter; sprawdź, co zajęły S88–S119).

## 1. Sklep premium: katalog i okno (S120)

- **`Data/Products`** dostaje kategorie: wpis `SHOP` ma pole `cat: "scroll" | "service" | "consumable" | "backpack"` i opcjonalne `dailyLimit`, `weeklyLimit`, `unavailable`. Okno `PremiumShop` przebudowane na zakładki: **Waluta** (paczki odłamków), **Przepustki** (gamepassy + VIP od S121), **Przedmioty** (zwoje, usługi, plecaki premium, od S122 Eliksir Pełni i Płaszcz Przynęty), **Kosmetyki** (garderoba; od S123 tygodniowa oferta), **Wierzchowce** (tylko gdy `Premium.mountOffers()` niepusta, S97). Lewy panel zakładek na PC, poziome zakładki na telefonie; saldo Smoczych Odłamków stale na górze z przyciskiem „Doładuj”.
- **Zwój Ochrony:** limit dzienny 5 → **1** (`dailyLimit = 1`). Cena bez zmian.
- **Tooltip i potwierdzenie** przy każdym zakupie za odłamki (nazwa, co daje, cena, saldo po zakupie). Zakup za Robux: natywne okno Roblox.
- **`tests/paywall.spec.luau`** (nowy): przechodzi po `Products.shop`, `Products.passes`, przyszłych `Products.subscriptions`, `Products.starterPacks` i `Data/Cosmetics` i sprawdza, że żaden wpis nie wskazuje przedmiotu z bonusami/statami, materiału ulepszania, błogosławieństwa, mikstury EXP ani waluty złota; lista dozwolonych rodzajów jest jawna w teście.
- `Premium.luau` (Logic) zbiera reguły zakupu (`canBuy(entry, account, now)`), żeby okno i serwer liczyły to samo.

## 2. VIP i przepustki (S121)

- **VIP = subskrypcja Roblox** (Experience Subscriptions: `MarketplaceService:GetUserSubscriptionStatusAsync`, `PromptSubscriptionPurchase`, zdarzenie zmiany statusu; sesja sprawdza aktualne API w dokumentacji przez komentarz i kod z `pcall`, bo API może się różnić). Cena subskrypcji ustawiana w Creator Hub (Roblox używa progów cenowych), w kodzie tylko `Products.subscriptions = { { key = "vip", subscriptionId = "", enabled = true } }`. Istniejąca przepustka `vip` zostaje jako **„VIP na zawsze”** z `enabled = false` (właściciel może ją włączyć); `MonetizationService.HasVip(player)` = aktywna subskrypcja **lub** przepustka `vip`. Atrybut `Vip` jak dziś.
- **Korzyści VIP** (`Config.Vip`): 
  - `dailyShards = 15`: pierwsze wejście danego dnia UTC z aktywnym VIP dodaje 15 odłamków (konto, `account.vip.shardDay`), toast;
  - tytuł „VIP” (wpis w `Data/Titles` z `req = { kind = "vip" }`), kolorowy nick i złota ramka czatu (już są: sprawdź `ChatService`/nameplate);
  - +1 kolejka u alchemika (już jest);
  - aukcja: `auctionExtraListings = 5`, `auctionFeeMul = 0.5` (opłata od sprzedaży; kaucja bez zmian);
  - darmowy powrót do miasta: działanie `stone_return` bez zużycia kamienia co `freeRecallCooldown = 600` s (przycisk w oknie VIP i w menu; ten sam serwerowy kod teleportu co kamień, te same blokady walki);
  - `freeRespawnsPerDay = 1`: przycisk natychmiastowego odrodzenia za 0 raz dziennie (`account.vip.respawnDay`);
  - **kosmetyk miesiąca:** `Data/Cosmetics` wpisy z `obtain = { vipMonth = "YYYYMM" }` (6 sztuk na miesiące 2026-11 … 2027-04); gracz z aktywnym VIP w danym miesiącu dostaje go na zawsze przy pierwszym wejściu w tym miesiącu (`account.vip.months[YYYYMM] = true`).
  - **Bez** EXP, złota, dropu, statów.
- **Nowe przepustki** (`Products.passes`, id 0):
  - `pockets` „Kieszenie Kupca” (249 R$): **+10 miejsc w każdym plecaku** (także bez plecaka: 20 → 30). Jedno miejsce w kodzie liczy pojemność (`Inventory`/`Config.DefaultCapacity` + plecak): dodaj `+ Products.POCKETS_SLOTS` przy przepustce. Utrata przepustki niemożliwa (gamepass jest na zawsze), ale admin może ją zabrać: wtedy przedmioty ponad pojemność zostają, tylko nie da się dokładać (sprawdź, jak dziś działa zmiana plecaka na mniejszy, i zrób tak samo).
  - `slot4`, `slot5` „Miejsce na postać” (99 / 149 R$): `Config.MaxCharacters = 5`, `Config.FreeCharacters = 3`; slot 4 wymaga `slot4`, slot 5 wymaga `slot5` (i `slot4`). Wybór postaci pokazuje zablokowane sloty z przyciskiem zakupu. Postać na slocie 4/5 po utracie przepustki zostaje grywalna (nie blokujemy dostępu do kupionej postaci; blokujemy tylko tworzenie).
  - `wardrobePlus` „Garderoba+” (79 R$): 5 zapisanych zestawów wyglądu (`account.outfits`, zapis/wczytanie w oknie garderoby). Bez przepustki: 1 zestaw.
- **Okno VIP** (`VipWindow`): lista korzyści, status (aktywny do / nieaktywny), przycisk subskrypcji, darmowy powrót z licznikiem, kosmetyk miesiąca.
- Drugi zestaw buildu **już jest za darmo** (S58, `SwitchBuildSet`): nie sprzedajemy go.

## 3. Przedmioty użytkowe premium (S122)

- **Eliksir Pełni** (`potion_full`, nowy przedmiot w `Data/Items/Consumables`, stackowalny, związany z kontem/postacią: **nie da się go sprzedać, wystawić ani wymienić**): przywraca 100% HP i many (i energii, jeśli klasa ją ma). Sprzedawany w paczkach (`potion_full_5` za 120 SO, `potion_full_20` za 400 SO). Reguły (`Config.FullElixir`): `cooldown = 180` s (własny, nie wspólny z miksturami), `dailyLimit = 10` użyć na postać i dzień UTC, **zablokowany**: w pojedynku i na arenie (`DuelService`/`ArenaService`), w lochu bossa (`DungeonService.InRun` albo mapa `dungeon_*`), w czasie blokady PvP (otrzymał/zadał obrażenia graczowi w ostatnich 15 s, ten sam licznik co przełącznik PvP), w trakcie Krwawego Księżyca (S129) i turnieju (S130). Slot: używany z plecaka i z dowolnego slotu mikstury (gracz może go podpiąć jak miksturę), z czytelnym komunikatem, czemu nie działa.
- **Płaszcz Przynęty** (usługa czasowa, nie przedmiot w plecaku): `account.lure = { untilTs, on }`; kupno `lure_1h` (150 SO) i `lure_7d` (990 SO) dodaje czas do `untilTs` (czas rzeczywisty, płynie także offline). Włącz/wyłącz w oknie sklepu, w menu i przyciskiem na HUD (ikona z pozostałym czasem). Działanie (`LureService`, `Config.Lure`): co `interval = 8` s zwykłe potwory (nie Elita, nie Elita II, nie boss, nie potwory wydarzeń świata) w promieniu `radius = 25` st. od gracza, które nikogo nie atakują i są w zasięgu poziomu gracza (`|lvl potwora − lvl gracza| <= levelGap = 10`), dostają aggro na gracza, najwyżej `maxPulled = 6` potworów aktywnie walczących z graczem naraz. **Nie działa:** w mieście, w jaskiniach i lochach (`biome` cave/crypt/dungeon), w czerwonej strefie, na arenie, w czasie Krwawego Księżyca, na wierzchowcu, gdy gracz nie żyje. Wygląd: peleryna z `Util/CosmeticLook` (ciemnoczerwona, lekki dym), widoczna dla innych; nie zajmuje slotu kosmetyku (nakłada się na strój, ma pierwszeństwo przed peleryną stroju, gdy włączony). **Zero statów.**
- Oba wchodzą do zakładki „Przedmioty” S120 i do `paywall.spec` jako jawnie dozwolone wyjątki z opisem ograniczeń.
- Blokady: `Logic/UseBlocks` + `src/server/UseGuards.luau` (S122); S126/S127/S129/S130 rejestrują powody `arena` / `bloodMoon` / `tourney` (`UseGuards.register`, instrukcja w `docs/SESJE.md` → S122 „Jak dopiąć blokadę”).

## 4. Kosmetyki 2, oferta tygodnia, paczki startowe (S123)

- **Nowe rodzaje kosmetyków** w `Data/Cosmetics` (`Kind` += `"frame"` ramka portretu, `"chatframe"` ramka czatu, `"title"` tytuł kupowany, `"emote"` emotka/gest, `"levelup"` efekt awansu, `"dye"` barwnik koloru stroju). Każdy ma podgląd w garderobie i działa w grze (ramka w portrecie HUD i oknie gracza, ramka czatu w ChatService, emotka z koła emotek / komendy `/e nazwa`, efekt awansu przy `LevelService`). Ok. 30 nowych kosmetyków (proceduralne wyglądy, placeholdery zgodne z poważnym tonem).
- **Tytuły kupowane** dodawane do `Data/Titles` z `req = { kind = "cosmetic", id = … }` (jeden picker tytułów, bez dwóch systemów).
- **Oferta tygodnia** (`Logic/WeeklyOffer.luau`, czysta): 4 kosmetyki wybrane deterministycznie z puli `weekly = true` przez `Logic/Rng` z ziarnem = numer tygodnia (poniedziałek 00:00 UTC, ta sama definicja tygodnia co tygodniowe questy S98), jeden z nich `−30%`. Ten sam wynik na każdym serwerze bez komunikacji. Zakładka „Kosmetyki” pokazuje ofertę u góry z licznikiem do zmiany.
- **Paczki startowe** (`Products.starterPacks`, Developer Products, raz na konto: `account.packs[key] = true`): „Paczka Wędrowca” (199 R$: 500 SO + peleryna + pet), „Paczka Bohatera” (799 R$: 2 200 SO + aura + przepustka Kieszenie Kupca jako nadanie w profilu, `account.grantedPasses.pockets = true`, honorowane przez `HasPass`). Po zakupie znikają ze sklepu.
- **Barwnik** to zwykły kosmetyk na zawsze (30–60 SO), nie zużywalny „30 za sztukę” z KATALOG.md; działa jako osobny krok po nałożeniu stroju (S132 przepnie go na stroje klas).
- **Kosmetyki paczek startowych** są tylko w paczkach (`obtain = { pack }`), nie w zwykłym sklepie: „peleryna” Paczki Wędrowca to strój z peleryną (`outfit_wayfarer`, rodzaju „peleryna” nie ma), pet to chart (`pet_hound`), aura Paczki Bohatera to Aura Męstwa (`aura_valor`).
- **Zrobione w S123:** `Logic/CosmeticRules`, `Logic/WeeklyOffer`, `Data/Emotes`, `EmoteService` (remote `PlayEmote`, atrybut modelu `Emote`, komenda `/e`), atrybuty gracza `CosmeticFrame` / `CosmeticChatFrame` / `CosmeticLevelUp`, `Products.starterPacks`, `account.packs`, `account.grantedPasses`, `MonetizationService.GrantProfilePass`, `Titles.contextOf`. S128 dopisze ramki i tytuły areny jako kosmetyki z `obtain` (cena 0), S131 przejrzy ceny.

## 5. Rankingi (S124–S125)

- **`LeaderboardService`** (nowy) + `src/server/Leaderboard/` (`Stores.luau`: OrderedDataStore/MemoryStore z atrapą, `Cache.luau`: top 100 na tablicę odświeżane co `Config.Leaderboard.refresh = 300` s) + `Logic/Leaderboard.luau` (czysta: kodowanie wyniku, tygodnie, dzielenie na strony) + `Data/Leaderboards.luau` (definicje tablic).
- **Klucz wpisu** `"<userId>_<slot>"`, metadane (imię postaci, klasa, tag gildii, poziom) w osobnym DataStore `Config.Leaderboard.metaStore` aktualizowanym razem z wynikiem (odczyt metadanych top 100 hurtowo i w cache).
- **Tablice S124:**
  - `level` (wszystkie klasy) i `level_<klasa>` (4 tablice): wynik = `level × 10^10 + reszta`, gdzie reszta = `floor(exp / expToNext × 10^9)` dla poziomu < 100, a dla 100: `10^10 − 1 − reachedAtUnix` (kto pierwszy, ten wyżej). `character.reached100At` zapisywany przy awansie na 100 (nowe pole).
  - **Sala Sław** (`hof_<klasa>`): pierwsze 10 postaci każdej klasy, które osiągnęły 100. DataStore `UpdateAsync` na jednym kluczu na klasę (lista max 10, wpis raz na zawsze). W mieście: tablica Sali Sław (plansza z SurfaceGui, wzór tablic/szyldów miasta) przy ratuszu oraz cokoły z imionami.
  - Wpis aktualizowany przy awansie poziomu i przy wyjściu z gry, najwyżej raz na 60 s na klucz. Postacie z flagą admina/testową pomijane (`Config.Leaderboard.excludeAdmins = true`). Usunięcie postaci usuwa jej wpis.
- **Okno „Rankingi”** (`RankingsWindow`, klawisz domyślnie `J` jeśli wolny; S124: J zajęte przez S97, więc `R`; przycisk w menu HUD): zakładki tablic, filtr klasy, top 100 z przewijaniem, wiersz „Ty: #pozycja” (z cache) albo „poza top 100: poziom X”, czas ostatniego odświeżenia. Ta sama zawartość na planszy w mieście (top 10).
- **S125:** 
  - `exp_week` (MemoryStore SortedMap na klucz tygodnia, TTL 8 dni): wynik = EXP zdobyty w tym tygodniu (z potworów, questów i wydarzeń; przyrost wysyłany partiami co 60 s). Koniec tygodnia: top 3 na każdym przedziale poziomów (`brackets = { {1,19}, {20,44}, {45,69}, {70,100} }`, przedział wg poziomu postaci w chwili ostatniego zapisu; osobna SortedMap na przedział) dostaje tytuł „Najpilniejszy tygodnia” na 7 dni (`character.timedTitles`) i odłamki 100/50/25 pocztą. Wypłatę robi pierwszy serwer, który zdobędzie blokadę (`UpdateAsync` na kluczu `"paid_<tydzień>"`), idempotentnie.
  - `guild` (tablica gildii: suma poziomów 10 najwyższych członków, aktualizowana przez `GuildService` przy zmianie składu/awansie, z limitem zapisów).
  - **Eksport na wiki (opcjonalny):** `tools/rankings_fetch` (Lune lub Node) czyta top 100 przez Roblox Open Cloud (OrderedDataStore API) i zapisuje `wiki/src/data/rankings.json`; workflow GitHub co godzinę **tylko gdy** istnieje sekret `ROBLOX_OPEN_CLOUD_KEY` (inaczej krok pomija się na zielono). Strona wiki „Rankingi” pokazuje dane albo informację „ranking dostępny w grze”. Ostatnia wiadomość sesji mówi właścicielowi, jak dodać klucz.
  - **Doprecyzowania S125 (kod, kontrakt dla S126–S131):** przedziały, nagrody i źródła w `Data/Leaderboards`
    (`WEEK_BRACKETS`, `WEEK_REWARDS`, `WEEK_SOURCES`: potwory, bossowie, zadania, zlecenia, wydarzenia; nigdy admin);
    tydzień w `character.expWeek = { week, exp, b }`, do SortedMap `exp_week_<tydzień>_<przedział>` idzie suma
    bezwzględna `{ s, m, cid }` z maksimum w `UpdateAsync` (nie przyrosty), metadane w wartości (bez `metaStore`); EXP po
    premii, także na 100. poziomie (`LevelService.ExpGained`); tytuł do `weekStart(W + 1) + 7 dni`. Wypłata: blokada
    `paid_<tydzień>` w `Config.Leaderboard.payoutStore` z przejęciem po `payoutLockStale`, oznaczenie przed wysyłką.
    Poczta: `Parcel.shards?` i `Parcel.timedTitle? = { id, untilTs }` tylko od `system` / `admin`. Tytuły czasowe:
    `Data/Titles` `req = { kind = "timed" }`, `character.timedTitles`, `TitleService.GrantTimed(player, id, untilTs)`.
    Gildia: `LeaderboardService.SubmitGuild`, remis dla starszej gildii. Wiki: `tools/rankings_fetch.luau` (Lune),
    workflow `rankings.yml`, zmienna repozytorium `ROBLOX_UNIVERSE_ID`.

## 6. Arena (S126–S128)

- **`ArenaService`** (nowy; `DuelService` zostaje dla towarzyskich pojedynków na zaproszenie) + `Data/Arena.luau` + `Logic/Elo.luau` (czysta) + `Logic/ArenaRules.luau` (czysta: przedziały, sezon, progi, nagrody).
- **Przedziały poziomów:** `{20,39}`, `{40,59}`, `{60,79}`, `{80,100}`; poniżej 20 arena rankingowa niedostępna. Dobór tylko w obrębie przedziału.
- **Zasady walki 1v1 (S126):** do 2 wygranych rund, runda max `roundTime = 180` s (remis rundy przy końcu czasu: wygrywa ten z wyższym % HP), pełne HP/mana/cooldowny na start rundy, **3 mikstury na mecz** (licznik na HUD), Eliksir Pełni zablokowany, błogosławieństwa zawieszone na czas meczu (efekt nie liczy się, czas płynie normalnie, sprawdź `BlessingService`), wierzchowce zakazane (S96 już blokuje `zone.arena`), `modPvP` jak w grze. Wyjście/rozłączenie = przegrana meczu.
- **Blokady S122:** S126 rejestruje mecz jako drugi warunek powodu `arena` (`UseGuards.register("arena", …, "ArenaService")`), S127 serwer areny (`ServerMode.get() == "arena"`); powód `arena` nie jest w `UseBlocks.PENDING`, więc nic stamtąd nie zdejmuje.
- **Rating:** Elo, start `1000`, `K = 32` (pierwsze 10 meczów sezonu `K = 48`), minimum 0. `character.arena = { season, rating, wins, losses, peak, played, tokens, daily = { day, n }, vs = { day, [oppKey] = n }, history, last }` (S126: `history` = 10 ostatnich meczów do okna, `last` = sezon zamknięty miękkim resetem, z niego S128 płaci nagrody). Mecz z tym samym przeciwnikiem więcej niż `sameOpponentDaily = 3` razy dziennie nie zmienia ratingu ani bilansu (komunikat przed meczem).
- **Sezon miesięczny:** id `"YYYYMM"` (UTC). Nowy sezon: rating miękko resetowany `1000 + (rating − 1000) × 0.5` przy pierwszym wejściu w nowym sezonie, nagrody za poprzedni wg `peak` (S128). Progi: Brąz < 1100, Srebro 1100–1299, Złoto 1300–1499, Diament 1500–1699, Mistrz ≥ 1700.
- **Ranking areny:** tablica `arena_<season>_<przedział>` w `LeaderboardService` (S124) z wynikiem = rating.
- **S126 (lokalnie):** NPC **Mistrz Areny** (`arenamaster`) przy Ristalle + okno `ArenaWindow` (rating, próg, sezon, historia 10 meczów, przycisk „Do kolejki 1v1”). Kolejka **na tym serwerze**, dobór po przedziale i ratingu (rozszerzanie okna ±100 co 15 s). Mecz na piasku Ristalle (te same punkty startu co pojedynki; kolejka meczów, gdy arena zajęta, wzór `DuelService.queue`). Widzowie na trybunach.
  - **Zrobione w S126:** potwierdzenie gotowości (15 s) i kara za odmowę (5 min) działają już w kolejce lokalnej (S127 przejmuje ten sam przebieg). Id przedziałów `"20_39"`, `"40_59"`, `"60_79"`, `"80_100"`, tryb `"1v1"` (S128 `"3v3"`), tablica `<board>_<sezon>_<przedział>` (`arena_202611_40_59`). Zejście z piasku przegrywa rundę, wyjście z gry mecz. Interfejsy dla S127/S128/S130: `docs/SESJE.md` → S126.
- **S127 (globalnie):** `src/server/Arena/Matchmaker.luau` (MemoryStore SortedMap `ArenaQueue_<mode>_<przedział>`: wpis `{ key, rating, jobId, t }`, TTL 120 s, odnawiany) i `src/server/Arena/ServerMode.luau` (`ServerMode.get(): "world" | "arena" | "tournament"`, z `TeleportData`/rekordu meczu w MemoryStore przy `game.PrivateServerId ~= ""` i `PrivateServerOwnerId == 0`). Serwer, który pierwszy zdobędzie parę (atomowo przez `UpdateAsync` na wpisach), robi `TeleportService:ReserveServer(placeId)`, zapisuje rekord meczu `ArenaMatch_<id>` (kod serwera, gracze, tryb, przedział, TTL 10 min) i wysyła MessagingService `ArenaMatch` do serwerów obu graczy; każdy serwer teleportuje swojego gracza (`TeleportAsync` z `ReservedServerAccessCode` i `TeleportData = { arenaMatch = id, returnJob = game.JobId }`). **Serwer areny** (`ServerMode = "arena"`) buduje tylko małą mapę areny (nowy układ `arena_pit`: piasek, trybuny, dwa punkty startu; bez całego świata), ładuje profile normalnie (to ta sama gra, ProfileStore przenosi blokadę sesji), prowadzi mecz zasadami S126, zapisuje wynik w profilach, potem odsyła graczy: najpierw `TeleportToPlaceInstance(placeId, returnJob)`, przy błędzie zwykły `Teleport` na dowolny publiczny serwer. Gracz nie pojawia się w mieście arenowego serwera (spawn na punkcie startu).
  - **Zrobione w S127:** tryb zarezerwowanego serwera z rejestru MemoryStore `ReservedServers[PrivateServerId] = { mode, ref }` (zapis zaraz po `ReserveServer`), `TeleportData` tylko jako zapas, serwer bez wiedzy o trybie startuje jako świat. Wpis kolejki opakowuje bilet S126 (`{ key, ticket, jobId, state, match?, claimUntil? }`, sort key = rating). Para z jednego serwera gra na Ristalle bez teleportu. Powrót przez `TeleportAsync` z `ServerInstanceId = returnJob` (z `TeleportData`), potem dowolny publiczny, na końcu kick z tekstem. Szczegóły: `docs/SESJE.md` → S127.
  - **Fallback:** brak dostępu do MemoryStore/Teleport (Studio) albo nikt w kolejce globalnej przez `globalWait = 45` s → propozycja walki lokalnej (jeśli na serwerze ktoś czeka) albo dalsze czekanie. W Studio cały przepływ działa lokalnie (symulacja teleportu = mecz na Ristalle).
  - Gracz w kolejce może dalej grać (nie w lochu); powiadomienie „Znaleziono przeciwnika: akceptuj w 15 s”. Odrzucenie = 5 min kary kolejki.
- **S128 (3v3, Żetony, sklep, nagrody):**
  - 3v3: kolejka drużyny (grupa 3 osób z tego samego przedziału, lider zapisuje) i pojedynczych (dobierani w trzy). Mecz 1 runda, max 240 s, wygrywa drużyna z żywymi; przy końcu czasu suma % HP. Osobny rating `rating3` w `character.arena`, tablica `arena3_<season>_<przedział>`.
  - **Żetony Areny** (`character.arena.tokens`): wygrana 1v1 = 10, przegrana 4, 3v3 wygrana 12, przegrana 5; **pierwsze 3 mecze dnia** ×2. Limit tygodniowy `tokensWeekCap = 600`.
  - **Sklep areny** u Mistrza Areny (za Żetony): kosmetyki areny (ramki, tytuły, aura „Gladiatora”), błogosławieństwa (te same co w grze, do Heroicznej rzadkości, ceny w `Data/Arena`, w księdze balansu), Kamienie Powrotu. Bez przedmiotów z bonusami.
  - **Nagrody sezonu** (pocztą przy pierwszym wejściu w nowym sezonie, wg `peak`): Brąz: tytuł sezonu; Srebro: + ramka; Złoto: + aura sezonu; Diament: + 150 SO; Mistrz: + 300 SO i tytuł „Mistrz Areny <sezon>”. Top 10 przedziału na koniec sezonu: posąg na tablicy Sali Sław areny (S124 plansza).

## 7. Krwawy Księżyc (S129)

- **Harmonogram globalny** (`Logic/Schedule.luau`, czysta: następne wystąpienie z listy tygodniowych slotów UTC; `Data/ScheduledEvents.luau`): Krwawy Księżyc we **wtorek i czwartek 19:00 UTC**, 30 min. Wszystkie serwery liczą to samo z zegara (`os.time()` UTC, bez komunikacji). Ogłoszenia 10 min i 1 min przed oraz na starcie (`AnnounceService`), licznik na HUD.
- W czasie wydarzenia **wszystkie cztery otwarte regiony** (Łąki, Duskwood, Spalone Pustkowia, Lodowe Szczyty, bez miasta) mają wymuszoną **czerwoną strefę** (przez `ZoneService`, ta sama ścieżka co jaskinie), czerwone niebo (`RegionLightController`), elity pojawiają się częściej (`eliteMul = 1.5`). Miasto zostaje zielone; jaskinie i lochy bez zmian. Wydarzenia świata S101 nie startują w trakcie (lub kończą się przed).
- **Punkty** (`BloodMoonService`, `character.bloodMoon = { id, points, kills = { [victimKey] = n } }`): zabicie gracza 10 pkt (0, gdy ofiara ma ≥ 8 poziomów mniej; ta sama ofiara liczy się max 2 razy), Elita 1, Elita II 5; śmierć 0 (bez kary). **Ranking per region** (gdzie zdobyto punkty) w MemoryStore SortedMap `BloodMoon_<id>_<region>`, TTL 2 dni; okno wyników na żywo (top 10 + ty).
- **Nagrody** po końcu (pocztą, idempotentnie po `id` wydarzenia): udział (≥ 5 pkt): 20 Żetonów Areny + błogosławieństwo Unikatowe; top 100 regionu: tytuł „Krwawy” na 7 dni; top 10: + ramka „Krwawego Księżyca”; top 1: + 100 SO i ogłoszenie na wszystkich serwerach (MessagingService). Brak dostępu do MemoryStore → ranking tylko tego serwera (jasno opisany w oknie).
- Komenda admina do wymuszenia startu/końca na serwerze testowym.
- **Blokady S122:** zarejestruj powód `bloodMoon` w `UseGuards` (`UseGuards.register("bloodMoon", …, "BloodMoonService")`) i zdejmij go z `UseBlocks.PENDING` w tym samym commicie (test `premiumuse.spec` tego pilnuje).

## 8. Turniej Czempiona (S130)

- **Sobota 19:00 UTC** (slot w `Data/ScheduledEvents`). Zapisy od 18:00 do 18:50 UTC u Mistrza Areny lub w `ArenaWindow` (z każdego serwera; lista zapisów w MemoryStore SortedMap `Tourney_<data>_<przedział>`, max `cap = 32` na przedział, kolejność zgłoszeń, pierwszeństwo wyższego ratingu przy przepełnieniu).
- **Jeden zarezerwowany serwer na przedział** (`ServerMode = "tournament"`): o 18:55 serwer-organizator (blokada `UpdateAsync` na kluczu turnieju) rezerwuje serwery i ogłasza kody przez MessagingService; zapisani dostają zaproszenie (akceptuj w 2 min) i teleport. Serwer turniejowy buduje `arena_pit` z 4 polami walki i lobby z trybunami, prowadzi **drabinkę pojedynczej eliminacji 1v1** (bo w jednym serwerze: brak problemu wielu serwerów), zasady meczu jak S126 (do 2 wygranych), wolne losy przy nieparzystej liczbie, nieobecny = walkower. Widzowie: przegrani zostają jako widzowie albo wracają przyciskiem.
- **Nagrody** (pocztą + ogłoszenie na wszystkich serwerach): zwycięzca przedziału: tytuł „Czempion Vaelthorn” na 7 dni, unikalna aura czempiona (na zawsze), posąg na tablicy Sali Sław (wpis tygodnia, 4 ostatnie tygodnie), 200 SO; finalista: 100 SO + ramka; półfinaliści: 50 SO; każdy uczestnik: 30 Żetonów.
- Za mało zapisanych (< 4 w przedziale) → turniej w tym przedziale odwołany, komunikat.
- W Studio: symulacja turnieju na jednym serwerze z botami-atrapami w testach (`Logic/Bracket.luau`, czysta drabinka z testami).
- **Blokady S122:** zarejestruj powód `tourney` w `UseGuards` (`UseGuards.register("tourney", …)`) i zdejmij go z `UseBlocks.PENDING` w tym samym commicie.

## 9. Audyt, wiki, ceny (S131)

- Wiki: artykuły „Sklep premium” (co jest, czego nie sprzedajemy, bez cen w Robux i bez id), „VIP”, „Rankingi”, „Arena”, „Krwawy Księżyc”, „Turniej Czempiona”; dane areny (progi, zasady, sklep areny) z `Data/Arena` przez nowy eksporter na liście dozwolonych.
- `paywall.spec` rozszerzony o wszystko z S120–S130; test „nic za Robux nie wpływa na rankingi” (wynik rankingu liczony tylko z poziomu/EXP/ratingu).
- Przegląd cen odłamków (wartość paczek vs ceny), analityka zakupów (`Analytics` istniejący) i lejka (wejście do sklepu, zakupy, VIP), komendy admina: nadaj/zabierz VIP, przepustkę, ustaw rating, wymuś wydarzenie/turniej, reset tygodnia.
- Lista „co właściciel musi ustawić w Creator Hub” (`docs/SKLEP-ID.md`): wszystkie produkty, przepustki, subskrypcja, ceny proponowane, gdzie wkleić id.

## 9a. Wygląd klas (S132)

Prośba właściciela z 2026-10-13 (wątek animacji, przeniesiona tutaj): wygląd postaci zależny od klasy, a garderoba ma różne stroje. Dziś postać to awatar Roblox gracza, a strój z garderoby jest tylko nakładany na niego (DESIGN.md §6, `Util/CosmeticLook`).

- **Domyślny wygląd klasy** (`Data/ClassLooks.luau`, nowy): dla każdej klasy zestaw ubrania i akcesoriów: darmowe przedmioty z katalogu Roblox (id assetów, gra zakłada je przez `HumanoidDescription` bez kupowania) **albo** modele właściciela z Tripo jako akcesoria (hak `assets/ClassLooks/<id>.rbxm`, wzór `WeaponLooks.assets`), z działającym fallbackiem proceduralnym z części (jak dzisiejsze stroje `Util/CosmeticLook`), gdy id = 0 albo brak pliku. Wojownik: płyty i peleryna; Kapłan: szata z kapturem i symbolem; Łowca: skórznia, kaptur, kołczan; Mag: szata z wysokim kołnierzem, pas z księgą.
- **Proporcje:** postać zawsze R15 o standardowych proporcjach (skale z `HumanoidDescription` ustawiane na domyślne), żeby animacje S110–S119 wyglądały dobrze; awatary Rthro i nietypowe skale nie przechodzą do gry.
- **Kreator postaci:** gracz wybiera tylko **twarz, kolor skóry i fryzurę** (listy w `Data/ClassLooks`: ok. 8 twarzy, 10 odcieni skóry, 12 fryzur z darmowego katalogu lub proceduralnych); resztę daje klasa. Zapis `character.look = { face, skin, hair }` (nowe pole z domyślnymi; istniejące postacie dostają domyślne wartości, okno „Zmień wygląd” raz za darmo, potem za złoto u fryzjera/lustra w mieście albo za odłamki: decyzja sesji, bez pay2win).
- **Garderoba:** kosmetyk `outfit` dostaje pole `class: string?` (`nil` = wspólny dla wszystkich klas). Założony strój **podmienia** ubranie klasy (nie nakłada się na awatar). Każda klasa ma w garderobie: strój domyślny (darmowy), 2 stroje z gry (boss/quest, `obtain`), 3–4 za Smocze Odłamki; wspólne stroje dalej działają. Zestawy Garderoby+ (S121) zapisują też wybór stroju klasy.
- **Opcja „Pokaż mój awatar Roblox”** w ustawieniach (`account.settings.robloxAvatar = false`): gdy włączona, postać używa awatara gracza w proporcjach R15 (skale przycięte do standardu), a stroje z garderoby nakładają się jak dziś. Inni gracze widzą to, co wybrał właściciel postaci.
- **Później (nie w tej serii):** zbroja z ekwipunku zmienia wygląd jak w Margonem. S132 tylko zostawia w `Data/ClassLooks` miejsce na warstwy wg slotu (`layers = { chest?, head?, … }`) i opisuje to w DECYZJE.
- Podgląd w kreatorze i garderobie (obracany model, wzór istniejącego podglądu garderoby), PC i telefon. Wiki: stroje klas (bez cen w Robux).

## 10. Kolejność sesji

| Sesja | Treść |
|---|---|
| S120 | Sklep premium: katalog z kategoriami, nowe okno z zakładkami, Zwój Ochrony 1/dzień, `paywall.spec` |
| S121 | VIP jako subskrypcja (korzyści, okno VIP, kosmetyk miesiąca), przepustki: Kieszenie Kupca, sloty postaci 4–5, Garderoba+ |
| S122 | Eliksir Pełni i Płaszcz Przynęty (LureService) |
| S123 | Kosmetyki 2 (ramki, ramki czatu, tytuły, emotki, efekty awansu, barwniki), oferta tygodnia, paczki startowe |
| S124 | Rankingi 1: LeaderboardService, poziom (wszyscy i klasy), Sala Sław, okno Rankingi, plansza w mieście |
| S125 | Rankingi 2: tygodniowy EXP z nagrodami, ranking gildii, eksport na wiki (opcjonalny Open Cloud) |
| S126 | Arena 1: ArenaService, Mistrz Areny, mecze 1v1 lokalnie, Elo, sezony, ranking areny |
| S127 | Arena 2: kolejka globalna (MemoryStore), serwery areny (ReserveServer), powrót, fallback |
| S128 | Arena 3: 3v3, Żetony Areny, sklep areny, nagrody sezonu |
| S129 | Krwawy Księżyc: harmonogram UTC, czerwone regiony, punkty, ranking per region, nagrody |
| S130 | Turniej Czempiona: zapisy globalne, serwer turniejowy, drabinka, nagrody, posąg |
| S131 | Audyt: wiki, paywall, ceny, analityka, admin, lista id do Creator Hub |
| S132 | Wygląd klas: domyślne stroje klas, kreator (twarz, skóra, fryzura), stroje klasowe w garderobie, opcja awatara Roblox |
