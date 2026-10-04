# Sesja poprawek (szablon)

> Skopiuj ten plik do Claude Code, wklej swoje błędy w sekcję „Błędy” i wyślij. Możesz też wysłać listę błędów w wątku projektu, a dostaniesz gotowy prompt.

Jesteś Claude Code w projekcie **Vaelthorn** (Roblox MMORPG, Luau, Rojo). To **sesja poprawek** po testach właściciela.

## Zasady
1. Przeczytaj `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/PROGRESS.md`; `docs/DESIGN.md` tylko w częściach dotyczących błędów.
2. **Nie testuj w Roblox Studio.** Dla każdego błędu: znajdź przyczynę w kodzie (czytaj logikę, przepływ remote'ów, dane), napraw u źródła, nie objawowo. Jeśli błąd dotyczy czystej logiki, dodaj test w `tests/`, który by go wykrył.
3. Gdy opis jest niejasny, napraw najbardziej prawdopodobną przyczynę i dopisz w PROGRESS, co założyłeś.
4. Jeśli przy okazji zauważysz inny oczywisty błąd tego samego rodzaju, napraw go i wypisz.
5. Na koniec: `scripts/check`, aktualizacja `docs/PROGRESS.md` (sekcja „Poprawki <data>”: błąd → przyczyna → poprawka → jak sprawdzić), przenieś naprawione z „Zgłoszone błędy”, commit `fix: ...` na `main`, `git push origin main`, podsumowanie w 5–10 liniach.

## Błędy
<!-- Wklej poniżej. Najlepiej: co robiłeś, co się stało, czego się spodziewałeś, błąd z Output w Studio (czerwony tekst). -->
1. 
2. 
3. 
