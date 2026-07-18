# Kauppakohtainen tuotehaku (R36) — design

## Tavoite

S-ryhmän tuotehaku näyttää käyttäjän oman myymälän (esim. "S-market
Kommila Varkaus") valikoiman ja hinnat — ei kovakoodatun edustajakaupan.
Ensimmäisellä käytöllä myymäläksi valitaan automaattisesti lähin laitteen
sijainnista; valinnan voi aina vaihtaa käsin, ja se muistetaan
ketjukohtaisesti. Listan ryhmittely säilyy ketjun nimellä (R30) —
myymälävalinta vaikuttaa vain hakuun ja hintoihin.

## Tausta ja todennetut löydökset (2026-07-18)

- `SKaupatCatalog` käyttää nyt yhtä kovakoodattua storeId:tä
  (`513971200`, eräs Prisma) kaikille S-ryhmän ketjuille. Hinnat ja
  valikoima ovat myymäläkohtaisia — todennettu: sama maito 1,09 €
  Kommilassa vs 0,95 € oletus-Prismassa.
- Myymälähakemisto ilman avainta: `GET
  https://www.s-kaupat.fi/myymalat?query=<nimi>` (selain-User-Agent,
  kuten muutkin S-kaupat-kutsut) palauttaa SSR-HTML:n, jonka upotetussa
  JSONissa on `StoreInfo`-tietueet: `id`, `slug`, `name`, `brand`
  (`prisma`/`s-market`/`sale`/`alepa`/`abc`/…), osoite (katu, postinumero,
  paikkakunta) ja aukioloajat. **Ei koordinaatteja.**
- Tuotehaun GraphQL (`RemoteFilteredProducts`) ottaa jo `storeId`:n —
  Kommilan id:llä (`708276035`) haku toimii sellaisenaan.

## Ratkaisu

### SKaupatStoreDirectory (uusi)

`searchStores(query: String) async throws -> [StoreLocation]` — hakee
`/myymalat?query=` ja poimii SSR-HTML:stä StoreInfo-JSON-tietueet
(regex-poiminta + JSONSerialization, samaan tapaan kuin KRautaCatalog
parsii flight-dataa). Suodatus ketjuun tehdään `brand`-kentällä.

`StoreLocation`: `id`, `name`, `brand`, `street`, `city`.

### Valinnan muisti (SelectedStores)

App Group -UserDefaults: ketjunimi → `{id, name}` (esim. `"S-market"` →
`{"708276035", "S-market Kommila Varkaus"}`). Laitekohtainen — ei synkata
perheelle (rajaus; perhesynkka mahdollinen myöhemmin).

### Automaattinen ensivalinta (lähin myymälä)

Kun kauppanäkymässä valitaan S-ryhmän ketju eikä sille ole muistettua
myymälää:

1. Laitteen sijainti (`LocationOnce`, on jo olemassa).
2. `CLGeocoder` reverse geocode → paikkakunta.
3. `searchStores(query: paikkakunta)` → suodata valittuun ketjuun.
4. Kandidaattien osoitteet (≤ 10) forward-geokoodataan (`CLGeocoder`),
   lähin valitaan etäisyydellä.
5. Valinta talletetaan ja käyttäjälle näytetään mikä valittiin
   ("Myymälä: S-market Kommila Varkaus — vaihda napauttamalla").

Jos sijaintilupa puuttuu, geokoodaus epäonnistuu tai paikkakunnalta ei
löydy ketjun myymälää → avataan käsivalintasheet.

### Käsivalinta (myymäläsheet)

Kauppanäkymässä S-ryhmän ketjun ollessa valittuna näkyy valitun myymälän
nimi; napautus avaa sheetin: hakukenttä ("Hae myymälää…"), tulokset
(nimi + osoite), napautus valitsee ja muistaa. Sama sheet toimii
ensivalinnan fallbackina.

### Tuotehaku

`SKaupatCatalog.search` lukee storeId:n muistista. S-ryhmän haku vaatii
valitun myymälän: ennen valintaa ei näytetä tuloksia, vaan valinta
tehdään ensin (automaatti yrittää heti, sheet fallbackina). Muut
providerit eivät muutu.

### Virhetilat

- Myymälähaku ei vastaa → sheetissä "Myymälöitä ei saatu haettua —
  yritä uudelleen".
- Muistettu myymälä lakkaa toimimasta (haku palauttaa virheen/tyhjää
  id:llä) → valinta nollataan ja pyydetään valitsemaan uudelleen.

### Testit

- Yksikkö: SSR-parsinta tallennetulla fixturella; brändisuodatus;
  lähin-valintalogiikka mock-etäisyyksillä (logiikka erillään
  verkosta ja CoreLocationista, ShoppingListLogic-hengessä).
- Live-integraatio (`LiveCatalogTests`-malli): `searchStores("kommila")`
  palauttaa id:n 708276035; tuotehaku sillä palauttaa tuloksia.
- UI: myymäläsheet UITEST-ympäristömuuttujasyötteellä ilman verkkoa (R18).

## Vaihe 2 — ei tässä toteutuksessa

- K-ruoka: sama malli (lähin + käsivalinta) `kr-api`:n
  `stores/search`-rajapinnalla KRuokaWebEnginen läpi.
- Valtakunnallisen indeksin ketjut (Tokmanni, Puuilo, Motonet, Gigantti):
  ei muutosta — rajapinnoissa ei ole myymäläkohtaista valikoimaa.

## Rajaukset

- Myymälävalinta on laitekohtainen, ei perheelle synkattava.
- Ryhmittely ja tuotteiden kauppanimi listalla säilyvät ketjutasolla
  ("S-market"), R30 ei muutu.
