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
- **R6** ✅ Listan otsakkeessa näkyy edistyminen muodossa
  "ostetut / kaikki" (esim. "3 / 8").
- **R7** ✅ Työkalurivin painike "Tyhjennä ostetut" poistaa kaikki ostetut
  rivit kerralla. Painike on estetty, kun ostettuja ei ole.
- **R8** ✅ Rivin veto vasemmalle poistaa sen (järjestelmän pyyhkäisytoiminto).
  Jokaisen rivin oikeassa laidassa on pieni vasemmalle osoittava
  nuolivihje (`‹`) kertomassa tästä.
- **R9** ✅ Kappalemäärän säätö vedolla: ostamattoman rivin veto oikealle
  rivin rungosta aloittaa säädön — siniseen "× N" -pilleriin päivittyvä
  lukema kasvaa yhden askeleen per 36 pt vaakavetoa ja pienenee samassa
  vedossa vasemmalle palattaessa, minimi 1. Sormen nosto tallentaa. Ostetun
  rivin määrää ei voi säätää. Levossa rivi näyttää "× N" kun N > 1.
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
- **R23** 🔄 Tuotteen voi VALINNAISESTI lisätä kaupan kautta: hakukentän
  oikeassa laidassa on kauppa-nappi, josta valitaan kauppa. Kauppavalinta on
  pudotusvalikko kiinteästä, ryhmitellystä listasta tuettuja kauppoja
  (S-ryhmä, K-ryhmä, muut) — käyttäjä ei voi lisätä omia kauppoja. Viimeisin
  valinta muistetaan. Kun valittu kauppa on S-ryhmää, tuotenimen kirjoittaminen
  hakee automaattisesti kaupan valikoimasta: tulokset näyttävät hinnan,
  vertailuhinnan, kategorian ja kuvan, ja tuotteen voi napauttaa listalle.
  Muille kaupoille käytetään vapaasanalisäystä samassa lomakkeessa.
  Kaikki kaupat, joilla on suoraan appista kutsuttava rajapinta, on
  toteutettu ja live-varmennettu (on-device-integraatiotestit): S-ryhmä
  (s-kaupat GraphQL), Puuilo (Algolia, avain haetaan dynaamisesti sivulta
  koska se vanhenee) ja Tokmanni (Klevu, klusteri eucs11). Kaksi kauppaa
  jäi aitojen esteiden taakse: **K-Rauta** on Next.js-palvelinpohjainen
  (suora `/api/search/v2` vastaa 500 ilman tuntemattomia otsakkeita,
  client-suodatus käyttää server-componenteja joita ei voi kaapata, ja
  hinnat/saatavuus tulevat erillisistä kutsuista) — sitä ei voi rakentaa
  luotettavasti eikä varmentaa, joten sitä ei toteuteta rikkinäisenä.
  **Kesko** (K-ruokakaupat) vaatii käyttäjän ilmaisen developer.kesko.fi
  -avaimen. Näille kahdelle käytetään vapaasanalisäystä. Vapaasanalisäys
  päänäkymässä ei muutu tästä millään tavalla.
- **R26** ✅ Kaupasta lisätyistä tuotteista listalla näkyy pikkukuva, hinta
  ja kauppa/hyllypaikka; info-napista avautuu tuotenäkymä jossa kuva(t),
  hinta, kauppa, hyllypaikka ja kuvaus (jos saatavilla). Vapaasanatuotteilla
  ei ole mitään extraa — pelkkä nimi.
- **R25** 🔄 Hyllypaikan lähde riippuu kaupasta: ne kaupat jotka tarjoavat
  hyllypaikan rajapinnassaan (esim. Motonet, rautakaupat), näyttävät sen
  suoraan katalogituloksessa ja tallentavat sen riville. Ne jotka eivät
  tarjoa (ruokakaupat S/Kesko), näyttävät kategorian, ja oikea hyllypaikka
  tulee perheen hyllymuistista (R24). Ruokakatalogin hinnat ovat
  viitteellisiä (edustava kauppa). Vapaasanalisäys ei muutu eikä monimutkaistu
  tästä millään tavalla. Ketjukohtaiset tuotekatalogit (K-ryhmä ensin)
  haetaan rajapinnoista käytön mukaan ja välimuistitetaan; haku tarkentuu
  kategorioita napauttamalla. (Vaihe A toteutettu; katalogit B–D työn alla.)
- **R24** ✅ Perheen hyllymuisti: kun tuotteelle annetaan hyllypaikka
  kaupassa (käsin tai katalogista), pari (tuote, kauppa) → hyllypaikka
  muistetaan, synkkautuu perheelle ja esitäytetään seuraavalla kerralla —
  kaikissa kaupoissa, myös ilman katalogirajapintaa.

## Ei-toiminnalliset vaatimukset ja rajaukset

- **R16** ✅ Vähimmäisversio iOS 17.0.
- **R17** ✅ Ei kolmannen osapuolen riippuvuuksia. Xcode-projekti generoidaan
  XcodeGenillä (`project.yml`), eikä generoitua projektia committoida.
- **R18** ✅ Listalogiikka (järjestys, syötteen siistintä, määrälaskenta) on
  yksikkötestattu ja riippumaton tallennuskehyksestä.
- **Rajaukset:** ei kategorioita, ei useita listoja, ei käyttäjäkohtaisia
  oikeuksia jaon sisällä, ei Android-versiota.
