// Vaelthorn Wiki — dane przykładowe (do podmiany na Data/* z gry)
window.VW = (function () {
  const rar = {
    common: { c: '#C9CED6', pl: 'Zwykły', en: 'Common' },
    uncommon: { c: '#4FD16B', pl: 'Niezwykły', en: 'Uncommon' },
    rare: { c: '#3D8BFF', pl: 'Rzadki', en: 'Rare' },
    epic: { c: '#B36BFF', pl: 'Epicki', en: 'Epic' },
    legendary: { c: '#FF9A2E', pl: 'Legendarny', en: 'Legendary' },
    mythic: { c: '#3FE0C8', pl: 'Mityczny', en: 'Mythic' }
  };
  const rarOrder = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];
  const slots = {
    weapon: { pl: 'Broń', en: 'Weapon' }, offhand: { pl: 'Tarcza', en: 'Off-hand' },
    head: { pl: 'Głowa', en: 'Head' }, chest: { pl: 'Tors', en: 'Chest' },
    hands: { pl: 'Dłonie', en: 'Hands' }, feet: { pl: 'Stopy', en: 'Feet' },
    ring: { pl: 'Pierścień', en: 'Ring' }, neck: { pl: 'Szyja', en: 'Neck' },
    material: { pl: 'Materiał', en: 'Material' }
  };
  const classes = {
    war: { pl: 'Wojownik', en: 'Warrior' }, mag: { pl: 'Mag', en: 'Mage' },
    hun: { pl: 'Łowca', en: 'Hunter' }, rog: { pl: 'Łotr', en: 'Rogue' },
    any: { pl: 'Każda klasa', en: 'Any class' }
  };
  const items = [
    { id: 'ostrze', rar: 'legendary', pl: 'Ostrze Popielnego Króla', en: 'Blade of the Ash King', slot: 'weapon', tpl: 'Miecz dwuręczny', ten: 'Two-handed sword', lvl: 34, cls: 'war', stat: 'atk', v: [128, 171], spd: 1.15, up: 7,
      b: [['+14% obrażeń od ognia', '+14% fire damage'], ['+6% szansy na trafienie krytyczne', '+6% critical hit chance'], ['Kradzież życia 2,1%', 'Life steal 2.1%']],
      f: ['„Król spłonął. Ostrze nie.”', '“The king burned. The blade did not.”'], from: 'straznik', ch: 0.04 },
    { id: 'kaptur', rar: 'epic', pl: 'Kaptur Wartownika', en: 'Warden’s Hood', slot: 'head', tpl: 'Kaptur, lekka zbroja', ten: 'Hood, light armor', lvl: 32, cls: 'any', stat: 'def', v: [86], up: 3,
      b: [['+120 punktów życia', '+120 health'], ['+4% odporności na mrok', '+4% shadow resistance']],
      f: ['„Widział wszystko. Nie zapamiętał nic.”', '“It saw everything. It remembered nothing.”'], from: 'straznik', ch: 1.2 },
    { id: 'pierscien', rar: 'rare', pl: 'Pierścień Mgły', en: 'Ring of Mist', slot: 'ring', tpl: 'Pierścień', ten: 'Ring', lvl: 30, cls: 'any', stat: null, up: 0,
      b: [['+3% szansy na unik', '+3% dodge chance'], ['+40 many', '+40 mana']], from: 'straznik', ch: 4.5 },
    { id: 'kosc', rar: 'common', pl: 'Kość kurhanowa', en: 'Barrow Bone', slot: 'material', tpl: 'Materiał rzemieślniczy', ten: 'Crafting material', lvl: 1, cls: 'any', stat: null,
      b: [], f: ['Krucha, ale kowale płacą za nią uczciwie.', 'Brittle, but smiths pay fairly for it.'], from: 'straznik', ch: 38 },
    { id: 'kamien', rar: 'uncommon', pl: 'Popielny Kamień', en: 'Ash Stone', slot: 'material', tpl: 'Materiał do ulepszania', ten: 'Upgrade material', lvl: 1, cls: 'any', stat: null,
      b: [], f: ['Ciepły w dłoni. Zawsze.', 'Warm in the hand. Always.'], from: 'straznik', ch: 12 },
    { id: 'tarcza', rar: 'epic', pl: 'Tarcza Ostatniej Straży', en: 'Shield of the Last Watch', slot: 'offhand', tpl: 'Tarcza', ten: 'Shield', lvl: 36, cls: 'war', stat: 'def', v: [210], up: 5,
      b: [['+8% szansy na blok', '+8% block chance'], ['+60 pancerza', '+60 armor']], f: ['„Brama padła. Ona nie.”', '“The gate fell. She did not.”'], from: 'pani', ch: 3.1 },
    { id: 'kostur', rar: 'legendary', pl: 'Kostur Szarego Proroka', en: 'Staff of the Grey Prophet', slot: 'weapon', tpl: 'Kostur', ten: 'Staff', lvl: 38, cls: 'mag', stat: 'atk', v: [96, 140], spd: 0.9, up: 2,
      b: [['+18% obrażeń od mrozu', '+18% frost damage'], ['+9% szybkości rzucania', '+9% cast speed'], ['+150 many', '+150 mana']],
      f: ['„Przepowiedział własny koniec. Nikt nie słuchał.”', '“He foretold his own end. No one listened.”'], from: 'pani', ch: 0.6 },
    { id: 'luk', rar: 'rare', pl: 'Łuk Wiatru Kurhanów', en: 'Barrowwind Bow', slot: 'weapon', tpl: 'Łuk', ten: 'Bow', lvl: 28, cls: 'hun', stat: 'atk', v: [70, 104], spd: 1.4, up: 4,
      b: [['+5% szansy na trafienie krytyczne', '+5% critical hit chance'], ['+2 m zasięgu', '+2 m range']], from: 'wrona', ch: 2.2 },
    { id: 'napiersnik', rar: 'rare', pl: 'Napierśnik Popielny', en: 'Ashen Breastplate', slot: 'chest', tpl: 'Napierśnik, ciężka zbroja', ten: 'Breastplate, heavy armor', lvl: 33, cls: 'war', stat: 'def', v: [240], up: 6,
      b: [['+5% odporności na ogień', '+5% fire resistance'], ['+90 punktów życia', '+90 health']], from: 'grabarz', ch: 1.8 },
    { id: 'buty', rar: 'uncommon', pl: 'Buty Wędrowca', en: 'Wanderer’s Boots', slot: 'feet', tpl: 'Buty', ten: 'Boots', lvl: 12, cls: 'any', stat: 'def', v: [34], up: 1,
      b: [['+4% szybkości ruchu', '+4% movement speed']], from: 'szkielet', ch: 6 },
    { id: 'amulet', rar: 'mythic', pl: 'Amulet Pradawnych', en: 'Amulet of the Elders', slot: 'neck', tpl: 'Amulet', ten: 'Amulet', lvl: 40, cls: 'any', stat: null, up: 0,
      b: [['+10% wszystkich obrażeń', '+10% all damage'], ['+8% wszystkich odporności', '+8% all resistances'], ['Odrodzenie: raz na 10 min', 'Rebirth: once per 10 min']],
      f: ['„Starszy niż kurhany. Starszy niż król.”', '“Older than the barrows. Older than the king.”'], from: 'pani', ch: 0.01 },
    { id: 'sztylet', rar: 'epic', pl: 'Sztylet Cienia', en: 'Shadow Dirk', slot: 'weapon', tpl: 'Sztylet', ten: 'Dagger', lvl: 31, cls: 'rog', stat: 'atk', v: [54, 78], spd: 1.8, up: 3,
      b: [['+12% obrażeń w plecy', '+12% backstab damage'], ['+3% szansy na trafienie krytyczne', '+3% critical hit chance']], from: 'grabarz', ch: 0.9 },
    { id: 'rekawice', rar: 'common', pl: 'Rękawice Kowala', en: 'Smith’s Gloves', slot: 'hands', tpl: 'Rękawice', ten: 'Gloves', lvl: 8, cls: 'any', stat: 'def', v: [18], up: 0,
      b: [], from: 'szkielet', ch: 9 }
  ];
  const M = (id, pl, en, lvl, rank, kind, el, zone, hp, dmg, arm, xp, resp, drop) => ({ id, pl, en, lvl, rank, kind, el, zone, hp, dmg, arm, xp, resp, drop });
  const monsters = [
    M('straznik', 'Strażnik Kurhanu', 'Barrow Warden', 34, 'elite', 'undead', 'shadow', 'kurhany', 18400, '210–265', 640, 4200, '6 min', 'ostrze'),
    M('pani', 'Pani Popiołów', 'Lady of Ashes', 38, 'boss', 'undead', 'fire', 'kurhany', 142000, '480–610', 1100, 38000, '2 h', 'amulet'),
    M('grabarz', 'Oszalały grabarz', 'Maddened Gravedigger', 33, 'normal', 'human', 'none', 'kurhany', 4100, '95–130', 260, 720, '2 min', 'sztylet'),
    M('szkielet', 'Kurhanowy szkielet', 'Barrow Skeleton', 31, 'normal', 'undead', 'shadow', 'kurhany', 3200, '88–112', 310, 610, '1 min', 'buty'),
    M('wrona', 'Upiorna wrona', 'Wraith Crow', 30, 'normal', 'beast', 'shadow', 'kurhany', 2100, '64–90', 150, 480, '1 min', 'luk'),
    M('wilk', 'Wilk Wrzosowisk', 'Heath Wolf', 4, 'normal', 'beast', 'none', 'osada', 180, '8–12', 10, 22, '30 s', null),
    M('dzik', 'Kłowy dzik', 'Tusked Boar', 7, 'normal', 'beast', 'none', 'osada', 340, '14–19', 24, 41, '30 s', 'rekawice'),
    M('herszt', 'Herszt Kłusowników', 'Poacher Chief', 11, 'elite', 'human', 'none', 'osada', 2900, '38–52', 90, 380, '5 min', 'buty'),
    M('szeptun', 'Szeptun', 'Whisperer', 14, 'normal', 'spirit', 'nature', 'las', 820, '30–41', 40, 120, '1 min', null),
    M('deboklak', 'Stary Dębołak', 'Old Oakbreaker', 19, 'elite2', 'beast', 'nature', 'las', 9600, '96–124', 260, 1650, '15 min', null),
    M('topielica', 'Topielica', 'Drowned Maiden', 21, 'normal', 'undead', 'frost', 'bagna', 1500, '52–70', 110, 240, '1 min', null),
    M('krolowa', 'Królowa Bagien', 'Bog Queen', 26, 'elite2', 'beast', 'nature', 'bagna', 15800, '150–190', 400, 2900, '20 min', 'pierscien'),
    M('ogar', 'Popielny ogar', 'Ash Hound', 24, 'normal', 'beast', 'fire', 'trakt', 1900, '60–82', 140, 300, '1 min', 'kamien'),
    M('rozbojnik', 'Rozbójnik z Traktu', 'Road Bandit', 23, 'normal', 'human', 'none', 'trakt', 1750, '55–76', 160, 280, '1 min', null),
    M('kapitan', 'Kapitan Spalonej Straży', 'Captain of the Burnt Watch', 29, 'elite', 'human', 'fire', 'trakt', 11200, '170–215', 520, 2400, '8 min', 'napiersnik'),
    M('krol', 'Popielny Król', 'The Ash King', 45, 'boss', 'undead', 'fire', 'cytadela', 410000, '900–1150', 1800, 120000, '6 h', 'amulet')
  ];
  const ranks = { normal: { pl: 'Zwykły', en: 'Normal', c: '#C9CED6' }, elite: { pl: 'Elita', en: 'Elite', c: '#E8C25A' }, elite2: { pl: 'Elita II', en: 'Elite II', c: '#FF9A2E' }, boss: { pl: 'Boss', en: 'Boss', c: '#E8665A' } };
  const kinds = { undead: { pl: 'Nieumarły', en: 'Undead' }, beast: { pl: 'Bestia', en: 'Beast' }, human: { pl: 'Człowiek', en: 'Human' }, spirit: { pl: 'Duch', en: 'Spirit' } };
  const elements = { none: { pl: 'Fizyczny', en: 'Physical', c: '#C9CED6' }, fire: { pl: 'Ogień', en: 'Fire', c: '#E8763A' }, frost: { pl: 'Mróz', en: 'Frost', c: '#7CC3F0' }, shadow: { pl: 'Mrok', en: 'Shadow', c: '#A88BE8' }, nature: { pl: 'Natura', en: 'Nature', c: '#7BC86A' } };
  const zones = [
    { id: 'osada', pl: 'Osada Wrzosowisko', en: 'Heathmoor', lv: '1–12', z: 'green', x: 18, y: 70 },
    { id: 'las', pl: 'Szepczący Bór', en: 'Whispering Wood', lv: '10–20', z: 'green', x: 30, y: 40 },
    { id: 'bagna', pl: 'Bagna Mgieł', en: 'Mistfen', lv: '18–26', z: 'yellow', x: 48, y: 72 },
    { id: 'trakt', pl: 'Popielny Trakt', en: 'Ash Road', lv: '22–30', z: 'yellow', x: 56, y: 42 },
    { id: 'kurhany', pl: 'Kurhany Wschodu', en: 'Eastern Barrows', lv: '30–38', z: 'red', x: 74, y: 28 },
    { id: 'cytadela', pl: 'Cytadela Popiołu', en: 'Ash Citadel', lv: '38–45', z: 'red', x: 86, y: 60 }
  ];
  const zoneTypes = {
    green: { c: '#4FD16B', pl: 'Strefa zielona', en: 'Green zone', dpl: 'Bezpieczna. Bez PvP.', den: 'Safe. No PvP.' },
    yellow: { c: '#E0C23B', pl: 'Strefa żółta', en: 'Yellow zone', dpl: 'PvP tylko za zgodą obu graczy.', den: 'PvP only if both players agree.' },
    red: { c: '#E8665A', pl: 'Strefa czerwona', en: 'Red zone', dpl: 'Pełne PvP. Każdy może zaatakować każdego.', den: 'Full PvP. Anyone can attack anyone.' }
  };
  const P = [100, 95, 90, 80, 70, 55, 40, 25, 12], G = [200, 400, 700, 1100, 1600, 2400, 3500, 5000, 7500], S = [1, 1, 2, 2, 3, 4, 5, 7, 10];
  const upgrade = P.map((p, i) => ({ to: i + 1, p, gold: G[i], stones: S[i], fail: i < 4 ? 'none' : i < 7 ? 'down' : 'break' }));
  const failT = {
    none: { c: '#4FD16B', pl: 'Bez straty', en: 'No loss' },
    down: { c: '#E0C23B', pl: 'Spadek o 1 poziom', en: 'Drops 1 level' },
    break: { c: '#D64A3E', pl: 'Ryzyko zniszczenia', en: 'May break' }
  };
  const pages = {
    home: 'Vaelthorn Wiki - Glowna.dc.html', items: 'Vaelthorn Wiki - Przedmioty.dc.html', item: 'Vaelthorn Wiki - Przedmiot.dc.html',
    monster: 'Vaelthorn Wiki - Potwor.dc.html', zone: 'Vaelthorn Wiki - Kraina.dc.html', upgrade: 'Vaelthorn Wiki - Ulepszanie.dc.html', search: 'Vaelthorn Wiki - Szukaj.dc.html',
    bestiary: 'Vaelthorn Wiki - Bestiariusz.dc.html', mage: 'Vaelthorn Wiki - Klasa Mag.dc.html', map: 'Vaelthorn Wiki - Mapa swiata.dc.html', ds: 'Vaelthorn Design System.dc.html'
  };
  const N = (id, b, col, tier, max, pl, en, dpl, den, parent, active) => ({ id, b, col, tier, max, pl, en, dpl, den, parent: parent || null, active: !!active });
  const tree = {
    branches: [{ id: 'frost', pl: 'Mróz', en: 'Frost', c: '#7CC3F0' }, { id: 'fire', pl: 'Ogień', en: 'Fire', c: '#E8763A' }, { id: 'arcane', pl: 'Arkana', en: 'Arcane', c: '#B36BFF' }],
    tierLvl: [1, 10, 20, 30], tierPts: [0, 5, 10, 15],
    nodes: [
      N('f1', 'frost', 0, 0, 5, 'Lodowy Pocisk', 'Frost Bolt', '+6% obrażeń Lodowego Pocisku na poziom.', '+6% Frost Bolt damage per rank.', null, true),
      N('f2', 'frost', 2, 0, 1, 'Lodowa Bariera', 'Ice Barrier', 'Tarcza pochłaniająca 12% maks. życia przez 8 s.', 'A shield absorbing 12% max health for 8 s.', null, true),
      N('f3', 'frost', 0, 1, 3, 'Odłamki', 'Shards', 'Lodowy Pocisk rozpryskuje się na 2 cele obok (20% obrażeń na poziom).', 'Frost Bolt splinters into 2 nearby targets (20% damage per rank).', 'f1'),
      N('f4', 'frost', 1, 1, 3, 'Zimny Umysł', 'Cold Mind', '-4% kosztu many zaklęć mrozu na poziom.', '-4% mana cost of frost spells per rank.'),
      N('f5', 'frost', 2, 1, 2, 'Kryształowa Skóra', 'Crystal Skin', '+5% pancerza na poziom, gdy Bariera jest aktywna.', '+5% armor per rank while Barrier is active.', 'f2'),
      N('f6', 'frost', 0, 2, 1, 'Lodowa Włócznia', 'Ice Lance', 'Przebija wszystkich wrogów w linii. Zamrożeni otrzymują podwójne obrażenia.', 'Pierces all enemies in a line. Frozen targets take double damage.', 'f3', true),
      N('f7', 'frost', 1, 2, 3, 'Szron', 'Rime', '+8% szansy na zamrożenie celu na poziom.', '+8% chance to freeze per rank.', 'f4'),
      N('f8', 'frost', 1, 3, 1, 'Wieczna Zima', 'Eternal Winter', 'Zamrożeni wrogowie spowalniają też sojuszników wroga w promieniu 5 m.', 'Frozen enemies also slow their allies within 5 m.', 'f7'),
      N('o1', 'fire', 0, 0, 5, 'Kula Ognia', 'Fireball', '+6% obrażeń Kuli Ognia na poziom.', '+6% Fireball damage per rank.', null, true),
      N('o2', 'fire', 2, 0, 1, 'Ognisty Krok', 'Flame Step', 'Skok o 8 m zostawiający płonący ślad.', 'Leap 8 m, leaving a burning trail.', null, true),
      N('o3', 'fire', 0, 1, 3, 'Żar', 'Embers', 'Kula Ognia podpala cel: 4% obrażeń na sekundę na poziom.', 'Fireball ignites: 4% damage per second per rank.', 'o1'),
      N('o4', 'fire', 1, 1, 3, 'Spopielenie', 'Incinerate', '+5% obrażeń krytycznych ognia na poziom.', '+5% fire critical damage per rank.'),
      N('o5', 'fire', 2, 1, 2, 'Płomienna Ścieżka', 'Burning Path', 'Ślad Ognistego Kroku trwa o 1 s dłużej na poziom.', 'Flame Step trail lasts 1 s longer per rank.', 'o2'),
      N('o6', 'fire', 0, 2, 1, 'Deszcz Popiołu', 'Ash Rain', 'Ognisty deszcz na obszarze 6 m przez 5 s.', 'Rain of fire over 6 m for 5 s.', 'o3', true),
      N('o7', 'fire', 1, 2, 3, 'Piromancja', 'Pyromancy', '+4% obrażeń od ognia na poziom.', '+4% fire damage per rank.', 'o4'),
      N('o8', 'fire', 1, 3, 1, 'Serce Popielnego Króla', 'Heart of the Ash King', 'Zabójstwa ogniem odnawiają 3% many.', 'Fire kills restore 3% mana.', 'o7'),
      N('a1', 'arcane', 0, 0, 5, 'Pocisk Arkany', 'Arcane Missile', '+5% obrażeń Pocisku Arkany na poziom.', '+5% Arcane Missile damage per rank.', null, true),
      N('a2', 'arcane', 2, 0, 1, 'Mignięcie', 'Blink', 'Teleport o 10 m w kierunku ruchu.', 'Teleport 10 m in your movement direction.', null, true),
      N('a3', 'arcane', 0, 1, 3, 'Skupienie', 'Focus', '+3% szansy na trafienie krytyczne na poziom.', '+3% critical hit chance per rank.', 'a1'),
      N('a4', 'arcane', 1, 1, 3, 'Przepływ Many', 'Mana Flow', '+6% regeneracji many na poziom.', '+6% mana regeneration per rank.'),
      N('a5', 'arcane', 2, 1, 2, 'Lustrzane Odbicie', 'Mirror Image', 'Po Mignięciu zostawia 1 kopię na poziom, która odciąga wrogów.', 'Blink leaves 1 decoy per rank that draws enemies.', 'a2'),
      N('a6', 'arcane', 1, 2, 1, 'Wyciszenie', 'Silence', 'Przerywa rzucanie zaklęć celu na 3 s.', 'Interrupts the target’s casting for 3 s.', 'a4', true),
      N('a7', 'arcane', 1, 3, 1, 'Przekroczenie', 'Transcendence', 'Przez 10 s zaklęcia nie kosztują many. Odnowienie 3 min.', 'For 10 s spells cost no mana. 3 min cooldown.', 'a6', true)
    ]
  };
  const loc = (o, lang) => (o ? (o[lang] ?? o.pl) : '');
  const nf = (n, lang) => Number(n).toLocaleString(lang === 'en' ? 'en-US' : 'pl-PL', { maximumFractionDigits: 2 });
  const mult = l => 1 + 0.07 * l;
  const statAt = (it, l) => (it.v ? it.v.map(x => Math.round(x * mult(l))) : null);
  const item = id => items.find(i => i.id === id);
  const monster = id => monsters.find(m => m.id === id);
  const zone = id => zones.find(z => z.id === id);
  const href = k => encodeURI(pages[k] || pages.home);
  const itemHref = id => href(id === 'ostrze' ? 'item' : 'items');
  return { tree, elements, rar, rarOrder, slots, classes, items, monsters, ranks, kinds, zones, zoneTypes, upgrade, failT, pages, loc, nf, mult, statAt, item, monster, zone, href, itemHref };
})();
