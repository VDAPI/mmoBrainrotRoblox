--!strict
-- Polish strings. Every key must also exist in en.luau (checked by tests/locale.spec.luau).
-- Placeholders: {name} is replaced by Locale.T(key, { name = ... }).

return {
	-- Common
	["common.cancel"] = "Anuluj",

	-- Classes (DESIGN §4.2)
	["class.Warrior.name"] = "Wojownik",
	["class.Warrior.role"] = "Walka wręcz · Tank",
	["class.Warrior.desc"] = "Wojownik pierwszej linii z mieczem, toporem lub młotem. Siła napędza jego ciosy, a Energia umiejętności.",
	["class.Hunter.name"] = "Łowca",
	["class.Hunter.role"] = "Dystans · Trafienia krytyczne",
	["class.Hunter.desc"] = "Strzelec z łukiem lub kuszą. Zręczność wyostrza celność i zamienia strzały w trafienia krytyczne.",
	["class.Mage.name"] = "Mag",
	["class.Mage.role"] = "Obszarowe · Żywioły",
	["class.Mage.desc"] = "Mistrz ognia, lodu i błyskawic, który razi całe grupy wrogów. Intelekt wzmacnia zaklęcia opłacane Maną.",
	["class.Cleric.name"] = "Kapłan",
	["class.Cleric.role"] = "Leczenie · Wsparcie",
	["class.Cleric.desc"] = "Sługa światła: leczy, osłania sojuszników i karze wrogów świętą magią. Intelekt i Witalność.",

	-- Maps
	["map.city.name"] = "Vaelthorn",
	["map.unknown"] = "Nieznane ziemie",

	-- Character selection
	["charSelect.subtitle"] = "Wybierz postać",
	["charSelect.loading"] = "Wczytywanie postaci…",
	["charSelect.mockWarning"] = "Tryb testowy: brak dostępu do DataStore, postęp nie zostanie zapisany po tej sesji.",
	["charSelect.emptySlot"] = "Wolny slot",
	["charSelect.createButton"] = "Utwórz postać",
	["charSelect.play"] = "Graj",
	["charSelect.delete"] = "Usuń",
	["charSelect.classLevel"] = "{class} · Poziom {level}",
	["charSelect.created"] = "{name} wkracza do świata Vaelthorn.",
	["charSelect.deleted"] = "Postać {name} została usunięta.",
	["charSelect.create.title"] = "Nowa postać · slot {slot}",
	["charSelect.create.chooseClass"] = "Wybierz klasę",
	["charSelect.create.name"] = "Imię postaci",
	["charSelect.create.namePlaceholder"] = "{min}–{max} liter lub cyfr",
	["charSelect.create.checking"] = "Sprawdzanie dostępności…",
	["charSelect.create.available"] = "Imię dostępne",
	["charSelect.create.submit"] = "Utwórz",
	["charSelect.create.back"] = "Wróć",
	["charSelect.deleteModal.title"] = "Usuń postać",
	["charSelect.deleteModal.message"] = "Tej operacji nie da się cofnąć. Wpisz <b>{name}</b>, aby potwierdzić.",
	["charSelect.deleteModal.confirm"] = "Usuń na zawsze",

	-- HUD
	["hud.level"] = "Lv {level}",
	["hud.hp"] = "HP",
	["hud.mana"] = "Mana",
	["hud.energy"] = "Energia",
	["hud.menu.character"] = "Postać (C)",
	["hud.menu.inventory"] = "Plecak (B)",
	["hud.menu.skills"] = "Umiejętności (K)",
	["hud.menu.map"] = "Mapa świata (M)",
	["hud.menu.quests"] = "Questy (L)",
	["hud.menu.guild"] = "Gildia (G)",
	["hud.menu.party"] = "Grupa (P)",
	["hud.menu.menu"] = "Menu (Esc)",

	-- Windows
	["window.soon"] = "Wkrótce",
	["window.menu.title"] = "Menu",
	["window.character.title"] = "Postać",
	["window.inventory.title"] = "Plecak",
	["window.skills.title"] = "Umiejętności",
	["window.map.title"] = "Mapa świata",
	["window.quests.title"] = "Questy",
	["window.guild.title"] = "Gildia",
	["window.party.title"] = "Grupa",

	-- Game menu
	["menu.resume"] = "Wróć do gry",
	["menu.switchCharacter"] = "Zmień postać",
	["menu.language"] = "Język",

	-- Nameplates and notifications
	["nameplate.levelClass"] = "Lv {level} {class}",
	["toast.enterWorld"] = "Witaj w Vaelthorn, {name}!",

	-- Errors (server answers carry these keys)
	["error.badRequest"] = "Nieprawidłowe żądanie.",
	["error.busy"] = "Poczekaj, poprzednia akcja jeszcze trwa.",
	["error.confirmMismatch"] = "Wpisana nazwa się nie zgadza.",
	["error.internal"] = "Coś poszło nie tak. Spróbuj ponownie.",
	["error.network"] = "Problem z połączeniem. Spróbuj ponownie.",
	["error.notLoaded"] = "Twoje dane jeszcze się wczytują.",
	["error.rateLimited"] = "Za dużo żądań, zwolnij.",
	["error.slotEmpty"] = "Ten slot jest pusty.",
	["error.slotTaken"] = "Ten slot jest już zajęty.",
	["error.wrongPhase"] = "Nie możesz tego teraz zrobić.",
	["error.name.invalidUtf8"] = "Imię zawiera nieprawidłowe znaki.",
	["error.name.tooShort"] = "Imię musi mieć co najmniej {min} znaki.",
	["error.name.tooLong"] = "Imię może mieć najwyżej {max} znaków.",
	["error.name.invalidChars"] = "Dozwolone są tylko litery (także polskie) i cyfry.",
	["error.name.noLetter"] = "Imię musi zawierać co najmniej jedną literę.",
	["error.name.filtered"] = "To imię jest niedozwolone.",
	["error.name.filterFailed"] = "Nie udało się teraz sprawdzić imienia. Spróbuj ponownie.",
	["error.name.storeFailed"] = "Usługa imion jest niedostępna. Spróbuj za chwilę.",
	["error.name.taken"] = "To imię jest już zajęte.",

	-- Kicks (shown in both languages)
	["kick.loadFailed"] = "Nie udało się wczytać Twoich danych. Dołącz ponownie.",
	["kick.sessionEnded"] = "Sesja danych została zakończona (prawdopodobnie wszedłeś na inny serwer).",

	-- Admin commands
	["admin.denied"] = "Nie masz uprawnień do komend admina.",
	["admin.failed"] = "Komenda /{command} nie powiodła się, sprawdź output serwera.",
	["admin.needCharacter"] = "Najpierw wejdź do świata postacią.",
	["admin.help.header"] = "Komendy admina:",
	["admin.usage.help"] = "/help: lista komend admina",
	["admin.usage.gold"] = "/gold <ilość>: dodaj (lub odejmij, gdy ujemna) złoto aktywnej postaci",
	["admin.usage.shards"] = "/shards <ilość>: dodaj (lub odejmij) Smoczą Walutę na koncie",
	["admin.usage.wipe"] = "/wipe: usuń całe konto (wymaga /wipe confirm)",
	["admin.gold.ok"] = "Złoto {amount}, teraz {total}.",
	["admin.shards.ok"] = "Smocza Waluta {amount}, teraz {total}.",
	["admin.wipe.confirm"] = "To usunie WSZYSTKIE postacie i dane konta. Wpisz /wipe confirm w ciągu {seconds} s.",
	["admin.wipe.ok"] = "Konto wyczyszczone.",
}
