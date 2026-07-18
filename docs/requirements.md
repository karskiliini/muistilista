# Ostoslista — vaatimusrekisteri

Tämän rekisterin sopimus: kaikki vaatimukset yhdessä toteutettuna tuottavat
täsmälleen sen sovelluksen, joka meillä on (ja sen suunnitellut osat).
Ylläpito: `.claude/skills/requirements` -skilli jokaisella promptilla.

Tilat: ✅ toteutettu · 🔄 työn alla · 📋 suunniteltu

## Toiminnalliset vaatimukset

- **R1** ✅ Sovellus on natiivi iOS-sovellus (SwiftUI) nimeltä "Ostoslista",
  ja sen käyttöliittymä on suomeksi.
- **R2** ✅ Sovelluksessa on yksi litteä ostoslista — ei kategorioita eikä
  useita listoja.
- **R3** ✅ Listan rivillä on nimi, ostettu-tila, lisäysaika ja kappalemäärä
  (kokonaisluku, vähintään 1, oletus 1).
- **R4** ✅ Tuote lisätään listan yläreunan tekstikentästä ("Lisää tuote…")
  rivinvaihdolla. Syöte siistitään reunavälilyönneistä; tyhjä syöte ohitetaan.
  Lisäyksen jälkeen kenttä tyhjenee ja säilyttää fokuksen.
- **R5** ✅ Rivin napautus vaihtaa ostettu-tilan. Ostetut rivit näkyvät
  harmaina ja yliviivattuina listan lopussa; ostamattomat ensin. Kummassakin
  ryhmässä vanhin ensin.
- **R6** ✅ Edistyminen näkyy muodossa "ostetut / kaikki" (esim. "3 / 8").
  Kun lista on ryhmitelty kaupoittain (R30), luku näkyy kunkin kauppa­ryhmän
  otsakkeessa.
- **R7** ✅ Työkalurivin painike "Tyhjennä ostetut" poistaa kaikki ostetut
  rivit kerralla. Painike on estetty, kun ostettuja ei ole.
- **R8** ✅ Rivin voi poistaa vetämällä vasemmalle (järjestelmän
  pyyhkäisypoisto) — tämä toimii kaikilla riveillä. Poiston voi tehdä myös
  rivin pitkän painalluksen valikosta ("Poista tuote"). (Määrän säätö R9
  toimii samalla rivillä vaakavedolla.)
- **R9** ✅ Kappalemäärän säätö vedolla: ostamattoman rivin vaakaveto rivin
  rungosta säätää määrää — oikealle nostaa, **vasemmalle laskee heti** —
  yhden askeleen per 36 pt, minimi 1; siniseen "× N" -pilleriin päivittyvä
  lukema. Sormen nosto tallentaa. Ostetun rivin määrää ei voi säätää.
  Levossa rivi näyttää "× N" kun N > 1.
  Määrää voi säätää myös vetoeleen ulkopuolella: rivin pitkä painallus
  avaa valikon (lisää/vähennä), tuotenäkymässä on askellin, ja VoiceOver
  säätää määrää pyyhkäisemällä (saavutettava vaihtoehto eleelle).
- **R10** ✅ Lista säilyy laitteella sovelluksen sulkemisen ja
  uudelleenkäynnistyksen yli.
- **R11** ✅ iOS-etusivulle on tarjolla pieni widget, joka näyttää
  ostettavana olevien (ruksaamattomien) tuotteiden määrän. Se päivittyy kun
  sovellus siirtyy taustalle, ja vähintään 30 minuutin välein.
- **R35** 🔄 Widgetin napautus avaa sovelluksen suoraan päänäkymään
  (ostoslistaan) — ei koskaan tyhjää tai mustaa ruutua.
- **R12** ✅ Lista synkkautuu käyttäjän omien laitteiden välillä hänen
  iCloud-tilinsä kautta. Muutokset saapuvat automaattisesti hiljaisella
  push-ilmoituksella — laite päivittää itsensä ilman käyttäjän toimia.
- **R13** 🔄 Listan voi jakaa perheenjäsenille, joilla on omat Apple ID:t,
  ja kaikki osapuolet voivat lisätä, ruksata, säätää ja poistaa rivejä
  samasta listasta. Jako käynnistetään työkalurivin "Jaa perheelle"
  -napista (Applen jakonäkymä, kutsu esim. Viesteillä); kutsun hyväksyntä
  avaa saman listan vastaanottajan appiin. Löydettävyys: nappi näyttää
  ikonin lisäksi tekstin "Jaa perheelle" kunnes lista on jaettu; jaon
  jälkeen näkyy pelkkä ikoni. (Toteutus valmis 16.7.2026 —
  tila vaihtuu ✅:ksi kun päästä päähän -testi perheenjäsenen laitteella
  on tehty; jakelu vaatii R15:n TestFlightin.)
- **R14** ✅ Sama sovellus toimii myös Macilla (mm. tuotteiden helppoon
  kirjoittamiseen ja monilaiteympäristön testaamiseen) sekä iPadilla, samaa
  listaa synkaten.
- **R15** ✅ Sovellus jaellaan perheen puhelimiin TestFlightin kautta.
- **R19** ✅ Listan voi pakottaa päivittymään vetämällä listaa alaspäin
  (pull-to-refresh). Päivityksen valmistuttua lista palaa paikalleen
  pehmeästi animoiden — myös sormen ollessa yhä alhaalla — eikä koskaan
  hyppää; vieritysasento säilyy. Päivityksen voi käynnistää myös
  työkalurivin päivityspainikkeesta ja näppäimistöllä ⌘R (Macin
  ensisijainen tapa). Macissa lista päivittyy automaattisesti lisäksi
  minuutin välein ajettavalla varmistushaulla.
- **R20** ✅ Synkka ei koskaan monista rivejä pysyvästi: kahdentuneet
  tietueet siivotaan automaattisesti, ja kaikki laitteet päätyvät samaan
  lopputulokseen (deterministinen säilyjän valinta).
- **R21** ✅ Sovelluksen päänäkymän oikeassa alakulmassa näkyy aina
  versionumero pienellä tekstillä (semanttinen versiointi, esim. "v1.5.0").
  Versio päivitetään aina kun feature tai bugikorjaus valmistuu
  (`.claude/skills/version-bump`).
- **R22** ✅ Kun lista muuttuu toiselta laitteelta tulleella päivityksellä,
  laite näyttää ilmoitusbannerin (toast), joka kertoo mitä tapahtui
  (esim. "+ maito · ~ leipä · – 1 rivi") — myös sovelluksen ollessa
  etualalla. Ilmoituksen napautus avaa sovelluksen. Omista, samalla
  laitteella tehdyistä muutoksista ei ilmoiteta.
- **R31** ✅ Rivit pidetään tiiviinä: erillistä "⋯"-toimintonappia **ei ole**
  (poistettu käyttäjän pyynnöstä — vei liikaa tilaa). Sen toiminnot löytyvät
  muualta: määrän säätö vedolla (R9), poisto oikealle pyyhkäisemällä (R8) ja
  kaupan vaihto drag handlesta vetämällä (R32). Vasemman laidan drag handle on
  **kapea** (vie vähän tilaa) mutta riittävän korkea tartuttavaksi.
  Tuotteen siirto kauppaan jota ei vielä ole listalla tapahtuu lisäämällä
  tuote siihen kauppaan kauppahaun kautta (R23); drag-veto kohdistuu listalla
  jo näkyviin kauppoihin ja "Ei kauppaa" -vyöhykkeeseen.
- **R32** ✅ Tuotteita voi järjestellä ja siirtää vetämällä rivin vasemman
  laidan drag handlesta. Vedon aikana:
  - **haamu-esikatselu** (nimi, kuva, määrä) seuraa sormea; lisäksi
    tuntopalaute (haptic) noston, pudotuksen ja ✓-merkinnän yhteydessä;
  - **kategorian sisällä**: rivi valuu elävästi sormen osoittamaan uuteen
    positioon ja muut rivit tekevät tilaa reaaliajassa;
  - **toiseen kategoriaan**: itse ele-rivi pysyy omassa osiossaan (himmenee),
    ja **himmennetty esikatselu­rivi valuu kohdekaupan osioon** sormen kohtaan.
    Näin siksi että jos ele-rivi itse siirtyisi toiseen `List`-osioon, SwiftUI
    loisi solun uudelleen ja **peruisi vedon** (pudotus katosi, näytti
    jäätymiseltä). Pudotuksessa siirto viedään dataan. Järjestys tallentuu
    pysyvästi (`sortOrder`).
  - **Jokaisella rivillä on drag handle.** Vapaatekstituotteen voi järjestellä
    ja siirtää toiseen kauppaan; **kauppasidonnaisen (katalogi)tuotteen voi
    järjestellä vain oman kauppansa sisällä** — se ei voi vaihtaa kauppaa
    (vedettäessä muihin kauppoihin se pysyy omassaan).
  - **"Ei kauppaa" -pudotusvyöhyke** on aina näkyvissä alimpana vedon aikana,
    joten vapaatuotteen voi aina pudottaa takaisin kaupattomaksi;
  - pudotuksen jälkeen näkymä keskittyy siirrettyyn tuotteeseen.
  Kaupan vaihdon lukitus koskee myös vanhoja katalogirivejä jotka on tallennettu
  ennen `fromCatalog`-lippua: tuote katsotaan kauppasidonnaiseksi jos sillä on
  lippu, katalogihinta tai kuvia (`canChangeStore`).
  **Toteutus:** oma `DragGesture` (ei SwiftUI:n `.draggable`/`.dropDestination`
  -paria, joka ei koskaan käynnistynyt tämän `List`in sisällä). Sormen sijainti
  ja rivikehykset luetaan **samassa `.global`-koordinaatistossa** (List-solun
  ele ja kehysten luku eivät sopineet nimetystä koordinaatistosta, mikä esti
  sekä pudotuksen että haamun näkymisen).
  **Kriittistä: sormen kohde hit-testataan vedon alussa otettuun kiinteään
  slot-tilannekuvaan (`dragSlots`), EI elävään layoutiin.** Aiemmin elävä
  layout aiheutti sen että kun rivi siirtyi toiseen osioon, koko lista
  relayouttautui → sormen osumakohta muuttui → rivi poukkoili osioiden välillä
  → sovellus jäätyi. Kiinteä tilannekuva tekee kohteesta puhtaan funktion
  sormen sijainnista, joten rivi voi valua vapaasti ilman takaisinkytkentää. Rivikehykset säilytetään **viittaustyyppisessä varastossa**
  (ei `@State`), jottei niiden päivitys (joka tapahtuu joka animaatioruudulla —
  esim. pudotuksen jousi tai määrän veto) aja `body`:ä uudelleen loputtomassa
  silmukassa, mikä jäädytti sovelluksen. Varmennettu regressiotesteillä (drop-
  ja määränveto-eleen jälkeen sovellus vastaa yhä).
  **Varmennettu automaattisilla UI-testeillä** (`OstoslistaUITests`), jotka
  simuloivat painallus-ja-veto-eleen emulaattorissa: vapaa tuote siirtyy
  kauppaan, järjestyy ryhmänsä sisällä, palautuu kaupattomaksi, eikä
  kauppasidonnaisella tuotteella ole handlea.
- **R30** ✅ Lista on ryhmitelty kaupoittain: jokainen kauppa on oma osionsa
  (otsakkeessa kaupan nimi ja ostetut/kaikki-luku). Kaupan alaosassa näkyy
  sen tuotteiden yhteenlaskettu hinta (hinta × määrä), ja aivan listan
  lopussa kaikkien kauppojen yhteissumma. Kauppaosiossa voi olla myös
  hinnattomia vapaatuotteita (manuaalisesti lisättyjä, tiettyyn kauppaan
  kuuluvia) — ne eivät kasvata summaa mutta kertovat mistä kaupasta tuote
  haetaan. Ilman kauppaa lisätyt tuotteet ovat omassa "Muut"-ryhmässään.
- **R29** ✅ Kauppanäkymän hakutulosriviä voi napauttaa (avaa detail-näkymän)
  TAI pyyhkäistä: vasemmalle pyyhkäisy lisää tuotteen suoraan listalle
  (1 kpl, ei detail-näkymän kautta), oikealle pyyhkäisy tarjoaa pikavalinnat
  useamman kappaleen lisäämiseen kerralla (2/3/6 kpl).
- **R28** 🔄 K-ruokakaupat (K-Citymarket/K-Supermarket/K-Market) haetaan
  laitteella olevan piiloselaimen (WKWebView) kautta, koska k-ruoka.fi on
  Cloudflaren takana eikä URLSession pääse läpi. Moottori esiladataan
  käynnistyksessä ja valitsee lähimmän kaupan laitteen sijainnista. Koko
  monimutkaisuus on eristetty omaan moduuliin (`KRuokaWebEngine`), joka ei
  sotke muuta koodia. Jos moottori ei toimi (Cloudflare kiristää, sivu
  muuttuu, ei verkkoa), Keskon dataa ei näytetä ja käyttäjälle kerrotaan
  selkeästi "K-ruoan tiedot eivät ole juuri nyt saatavilla".
- **R23** 🔄 Tuotteen voi VALINNAISESTI lisätä kaupan kautta: hakukentän
  oikeassa laidassa on kauppa-nappi, josta valitaan kauppa. Kauppavalinta on
  pudotusvalikko kiinteästä, ryhmitellystä listasta tuettuja kauppoja
  (S-ryhmä, K-ryhmä, muut) — käyttäjä ei voi lisätä omia kauppoja. Viimeisin
  valinta muistetaan. Kun valittu kauppa on S-ryhmää, tuotenimen kirjoittaminen
  hakee automaattisesti kaupan valikoimasta: tulokset näyttävät hinnan,
  vertailuhinnan, kategorian ja kuvan, ja tuotteen voi napauttaa listalle.
  Muille kaupoille käytetään vapaasanalisäystä samassa lomakkeessa.
  Jos päänäkymän hakukenttään on kirjoitettu tuotenimi kauppa-ikonia
  painettaessa, se siirtyy suoraan kauppanäkymän hakukentän tekstiksi (ja
  poistuu päänäkymästä). Kauppanäkymässä EI ole hyllypaikka-tekstikenttää:
  hyllypaikkaa ei kirjoiteta käsin, vaan se noudetaan kaupan omasta datasta
  (kaupat jotka sen tarjoavat) ja näytetään tuotteen ⓘ-näkymässä.
  Kaikki kaupat, joilla on rakennettavissa oleva haku, on toteutettu ja
  live-varmennettu (on-device-integraatiotestit hakevat oikeista
  rajapinnoista): S-ryhmä (s-kaupat GraphQL), Puuilo (Algolia, avain
  haetaan dynaamisesti sivulta koska se vanhenee), Tokmanni (Klevu,
  klusteri eucs11), K-Rauta (hakusivun HTML parsitaan; sisältää oikean
  hyllypaikan osasto+hyllynumero muodossa) ja Motonet
  (`/api/suggestions`, kuva Broman-CDN:stä tuotekoodilla).
  **Bottisuojauksen takana olevat kaupat käyttävät piilotettua WKWebView'ta**,
  joka läpäisee haasteen kuten Safari: **K-ruoka** (K-Citymarket/K-Supermarket/
  K-Market, Cloudflare) hakee tuotteet sivun kautta, ja **Gigantti** (Vercelin
  bottihaaste) hakee sivun kontekstissa lyhytikäisen allekirjoitetun Algolia-
  avaimen (`/api/algolia/signed-api-key`) ja kysyy sillä suoraan Algoliaa
  (indeksi `commerce_b2c_OCFIGIG`). Molemmat menevät `.unavailable`-tilaan jos
  suojaus/verkko pettää. **Näin kaikilla listan kaupoilla, joilla haku on
  mahdollinen, on haku** — ainoa poikkeus on **Lidl**, joka ei myy tuotteita
  verkossa (vain tarjoukset), joten haettavaa katalogia ei ole. K-ruokan
  virallinen avoin reitti olisi **Kesko-API**, joka vaatii käyttäjän
  ilmaisen
  developer.kesko.fi-avaimen — sille käytetään vapaasanalisäystä kunnes
  avain on annettu. Vapaasanalisäys päänäkymässä ei muutu tästä millään
  tavalla. Hakutulosriviä napauttamalla avautuu tuotteen detail-näkymä
  (kuva/hinta/merkki/hyllypaikka/kategoria/kuvaus), josta voi painaa +
  (lisää listalle) tai palata takaisin hakuun. Kun tuote lisätään
  kauppanäkymästä, kauppanäkymä animoituu pois (sulkeutuu) ja lista
  skrollaa juuri lisättyyn tuotteeseen, joka ilmestyy paikalleen
  animoituna. Viimeisin valittu kauppa säilyy oletuksena seuraavilla
  hauilla (ja käynnistysten yli).
- **R26** ✅ Kaupasta lisätyistä tuotteista listalla näkyy pikkukuva, hinta
  ja kauppa/hyllypaikka; info-napista avautuu tuotenäkymä jossa kuva(t),
  hinta, kauppa, hyllypaikka ja kuvaus (jos saatavilla). Vapaasanatuotteilla
  ei ole mitään extraa — pelkkä nimi.
  **Pikkukuva näkyy vain jos tuotteella on oikea kuva** (ei tyhjää
  paikkamerkkiä), ja **info-nappi vain jos tuotteella on aitoa katalogitietoa**
  (hinta/kuvaus/hyllypaikka/kuva) — pelkkä kauppaan sijoitettu vapaateksti­tuote
  ei näytä kumpaakaan, jolloin nimet linjautuvat siististi.
  **Rivit ovat matalia (paljon mahtuu näytölle):** hinta ja kauppa/hyllypaikka
  näkyvät **nimen alapuolella** pienellä tekstillä (ei oikeassa laidassa, jottei
  vie leveyttä), ja rivin pystymitta on tiivis.
- **R25** ✅ Hyllypaikan lähde riippuu kaupasta: kaupat jotka tarjoavat
  hyllypaikan (esim. K-Rauta) näyttävät sen hakutuloksessa ja tuotteen
  ⓘ-näkymässä. **Motonetilla** hyllypaikka on tuotesivulla mutta vaatii
  tavaratalon valinnan: käyttäjä valitsee Motonet-tavaratalonsa kerran
  aidossa Motonet-näkymässä (jossa on oma lähin-tavaratalo-toiminto), ja
  hyllypaikka ("Hyllypaikka 63, lattiapaikka") noudetaan tuotteen
  ⓘ-näkymään piiloselaimella. Valinta muistetaan ja käyttäjä voi vaihtaa
  sen. Ruokakaupoille (S/Kesko) näytetään kategoria. Ruokakatalogin hinnat
  ovat viitteellisiä. Kauppatuotteiden kuvat haetaan oikeista
  kuva-CDN:istä (S-kaupoilla s-cloud `w280h280@_q75` + webp). Vapaasanalisäys ei muutu eikä monimutkaistu
  tästä millään tavalla. Ketjukohtaiset tuotekatalogit (K-ryhmä ensin)
  haetaan rajapinnoista käytön mukaan ja välimuistitetaan; haku tarkentuu
  kategorioita napauttamalla. (Vaihe A toteutettu; katalogit B–D työn alla.)
- **R24** ✅ Hyllypaikkaa ei kirjoiteta käsin. Se tulee kaupan omasta
  datasta niille kaupoille jotka sen tarjoavat (esim. K-Rauta: osasto +
  hyllynumero) ja tallentuu tuotteelle. Muille kaupoille tuotteella ei ole
  hyllypaikkaa. (Aiempi käsin syötettävä perheen hyllymuisti poistettu.)

- **R36** 📋 Kauppahaku kohdistuu tiettyyn fyysiseen myymälään ketjuissa,
  joiden rajapinta on myymäläkohtainen (ensin S-ryhmä:
  Prisma/S-market/Sale/Alepa/ABC; myöhemmin K-ruoka): tuotehaku näyttää
  vain valitun myymälän valikoiman ja hinnat. Ensimmäisellä käytöllä
  myymäläksi valitaan automaattisesti lähin laitteen sijainnin perusteella;
  myymälän voi aina vaihtaa käsin hakemalla nimellä (esim. "S-market
  Kommila Varkaus"). Valinta muistetaan ketjukohtaisesti, eikä sitä
  tarvitse valita uudelleen. Listan ryhmittely säilyy ketjun nimellä (R30).
  Valtakunnallisen indeksin ketjut (Tokmanni, Puuilo, Motonet, Gigantti)
  hakevat kuten ennen.
- **R37** 📋 Ostoslistaa voi käyttää tekoälyavustajalla MCP:n kautta:
  assistentti (esim. Claude) voi lukea listan sekä lisätä, ruksata ja
  poistaa rivejä, jolloin ostoslistan voi laatia tekoälyllä keskustellen.
  (Arkkitehtuuri — palvelimen sijoituspaikka ja kytkentä CloudKit-synkkaan —
  päätetään erillisessä speksissä.)

- **R27** ✅ Sovellus seuraa kaatumisia: uncaught-poikkeukset, fataalit
  signaalit (SIGABRT/SIGSEGV/…) ja Core Datan tietovaraston latausvirheet
  tallennetaan App Group -tiedostoon (syy, versio, pino). Seuraavalla
  käynnistyksellä näytetään ilmoitus kaatumisen syystä ja "Kopioi tiedot"
  -painike. Lisäksi tietovaraston latausvirhe ei enää kaada sovellusta
  vaan kirjataan ja yritetään toipua (kanta rakennetaan uudelleen,
  data synkkautuu iCloudista).

## Ei-toiminnalliset vaatimukset ja rajaukset

- **R16** ✅ Vähimmäisversio iOS 17.0.
- **R17** ✅ Ei kolmannen osapuolen riippuvuuksia. Xcode-projekti generoidaan
  XcodeGenillä (`project.yml`), eikä generoitua projektia committoida.
- **R18** ✅ Listalogiikka (järjestys, syötteen siistintä, määrälaskenta) on
  yksikkötestattu ja riippumaton tallennuskehyksestä. Ele­pohjaiset
  vuorovaikutukset (kuten kaupan vaihto vetämällä, R32) varmennetaan
  XCUITest-UI-testeillä (`OstoslistaUITests`), jotka ajetaan emulaattorissa
  in-memory-tallennuksella (`-UITestReset`), jotta ne eivät koske oikeaa dataa
  eivätkä CloudKitiä. Testien tuotteet syötetään `UITEST_ITEMS`-
  ympäristömuuttujalla, jotta ne eivät riipu verkosta.
- **R33** ✅ Sovelluksella on oma app-ikoni (`Assets.xcassets/AppIcon`,
  1024×1024, täysin peittävä — ei alfaa, kuten iOS vaatii): vaalealla taustalla
  **keltainen post-it-lappu** (kevyt kallistus + pehmeä varjo), jonka päällä
  checklist-tyylinen aihe — valintaruutu vihreällä ✓, ostoskärry ja
  hintalappu, kunkin vieressä listarivi. Ikoni generoidaan koodista
  (`scripts/makeicon.swift`, CoreGraphics + SF Symbols) eikä sitä piirretä käsin.
- **R34** ✅ Sovellus on valmisteltu App Store -jakelua varten: Release-buildi
  kääntyy ja arkistoituu, `PrivacyInfo.xcprivacy` mukana (UserDefaults-syy
  CA92.1, ei seurantaa, ei kerättyä dataa), `ITSAppUsesNonExemptEncryption=false`
  (vain vakio-HTTPS), `LSApplicationCategoryType=public.app-category.shopping`,
  ja push-ympäristö on konfiguraatiokohtainen (`APS_ENVIRONMENT`: development
  Debugissa, production Releasessa/arkistossa). Varsinainen jakelu­allekirjoitus,
  App Store Connect -tietue ja CloudKit-skeeman vienti tuotantoon tehdään
  Applen työkaluilla (ks. `docs/app-store-checklist.md`).
- **Rajaukset:** ei kategorioita, ei useita listoja, ei käyttäjäkohtaisia
  oikeuksia jaon sisällä, ei Android-versiota.
