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
  samasta listasta. (iCloud/CKShare-jako; kutsu sovelluksen jakonapista.)
- **R14** ✅ Sama sovellus toimii myös Macilla (mm. tuotteiden helppoon
  kirjoittamiseen ja monilaiteympäristön testaamiseen) sekä iPadilla, samaa
  listaa synkaten.
- **R15** 📋 Sovellus jaellaan perheen puhelimiin TestFlightin kautta.
- **R19** ✅ Listan voi pakottaa päivittymään vetämällä listaa alaspäin
  (pull-to-refresh). Päivityksen valmistuttua lista palaa paikalleen
  pehmeästi animoiden — myös sormen ollessa yhä alhaalla — eikä koskaan
  hyppää; vieritysasento säilyy. Päivityksen voi käynnistää myös
  työkalurivin päivityspainikkeesta ja näppäimistöllä ⌘R (Macin
  ensisijainen tapa).

## Ei-toiminnalliset vaatimukset ja rajaukset

- **R16** ✅ Vähimmäisversio iOS 17.0.
- **R17** ✅ Ei kolmannen osapuolen riippuvuuksia. Xcode-projekti generoidaan
  XcodeGenillä (`project.yml`), eikä generoitua projektia committoida.
- **R18** ✅ Listalogiikka (järjestys, syötteen siistintä, määrälaskenta) on
  yksikkötestattu ja riippumaton tallennuskehyksestä.
- **Rajaukset:** ei kategorioita, ei useita listoja, ei käyttäjäkohtaisia
  oikeuksia jaon sisällä, ei Android-versiota.
