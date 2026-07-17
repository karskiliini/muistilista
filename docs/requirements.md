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
- **R12** ✅ Lista synkkautuu käyttäjän omien laitteiden välillä hänen
  iCloud-tilinsä kautta. Muutokset saapuvat automaattisesti hiljaisella
  push-ilmoituksella — laite päivittää itsensä ilman käyttäjän toimia.
- **R13** 🔄 Listan voi jakaa perheenjäsenille, joilla on omat Apple ID:t,
  ja kaikki osapuolet voivat lisätä, ruksata, säätää ja poistaa rivejä
  samasta listasta. Jako käynnistetään työkalurivin "Jaa perheelle"
  -napista (Applen jakonäkymä, kutsu esim. Viesteillä); kutsun hyväksyntä
  avaa saman listan vastaanottajan appiin. (Toteutus valmis 16.7.2026 —
  tila vaihtuu ✅:ksi kun päästä päähän -testi perheenjäsenen laitteella
  on tehty; jakelu vaatii R15:n TestFlightin.)
- **R14** ✅ Sama sovellus toimii myös Macilla (mm. tuotteiden helppoon
  kirjoittamiseen ja monilaiteympäristön testaamiseen) sekä iPadilla, samaa
  listaa synkaten.
- **R15** 📋 Sovellus jaellaan perheen puhelimiin TestFlightin kautta.
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
- **R31** ✅ Rivin pitkän painalluksen valikossa on "Siirrä kauppaan"
  -alavalikko, joka tarjoaa pudotuslistan tuetuista kaupoista (sekä "Ei
  kauppaa"). Valinta siirtää tuotteen sen kaupan ryhmään (R30). Tämä on
  tapa siirtää tuote kauppaan, jota ei vielä ole listalla.
- **R32** ✅ Tuotteen voi siirtää toiseen kauppaan myös vetämällä: rivin
  vasemmassa laidassa on drag handle, josta tuotteen voi raahata ja pudottaa
  toisen kaupan osioon (otsake korostuu pudotuskohteena). Pudotuksen jälkeen
  näkymä keskittyy siirrettyyn tuotteeseen. Pitkä painallus avaa edelleen
  context-menun (drag handle erottaa vedon painalluksesta).
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
  (`/api/suggestions`, kuva Broman-CDN:stä tuotekoodilla). Loput kaupat
  eivät ole appista rakennettavissa (selvitetty 17.7.2026): **K-ruoka**
  (K-Citymarket/K-Supermarket/K-Market) on Cloudflaren bottisuojauksen
  takana — vain oikea selain läpäisee, URLSession saa 403/haaste; sen
  kauppahaku sijainnilla toimisi periaatteessa (POST /kr-api/stores/search
  {latitude,longitude}) mutta jää suojauksen taakse. **Lidl** ei myy ruokaa
  verkossa (vain tarjoukset), joten haettavaa katalogia ei ole. K-ruokan
  ainoa avoin reitti on virallinen **Kesko-API**, joka vaatii käyttäjän
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
  yksikkötestattu ja riippumaton tallennuskehyksestä.
- **Rajaukset:** ei kategorioita, ei useita listoja, ei käyttäjäkohtaisia
  oikeuksia jaon sisällä, ei Android-versiota.
