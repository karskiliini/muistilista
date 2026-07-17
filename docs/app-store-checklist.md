# App Store -julkaisun tarkistuslista

Tämä kuvaa mitä on jo tehty koodissa/konfiguraatiossa ja mitä sinun pitää
tehdä Applen työkaluilla. **Lue ensin kohta "Tärkeät riskit" — se on suurin
este julkaisulle.**

## Jo valmiina (koodi/konfiguraatio)

- Release-buildi kääntyy ja **arkistoituu** (`xcodebuild … archive` = ARCHIVE SUCCEEDED).
- Oma app-ikoni (1024×1024, peittävä, ei alfaa) — R33.
- `PrivacyInfo.xcprivacy` mukana (ei seurantaa, ei kerättyä dataa, UserDefaults-syy CA92.1).
- `ITSAppUsesNonExemptEncryption = false` → ei export-compliance-kysymystä joka latauksessa.
- `LSApplicationCategoryType = public.app-category.shopping`.
- Push-ympäristö konfiguraatiokohtainen: `development` (Debug), `production` (Release/arkisto).
- Versio 1.33.0, build 1. **Huom:** jokainen uusi lataus tarvitsee uuden buildinumeron
  (`CURRENT_PROJECT_VERSION` project.yml:ssä), version voi pitää samana.
  (Harkitse markkinointiversioksi `1.0` ensijulkaisuun.)

## Mitä sinun pitää tehdä (Apple)

1. **Apple Developer Program** — maksullinen jäsenyys ($99/v) tarvitaan jakeluun.
   Tili on jo tiimissä `37SJ6TU5RP`; varmista että ohjelma­jäsenyys on aktiivinen.
2. **CloudKit-skeema tuotantoon** — CloudKit Dashboard → containerin
   `iCloud.fi.maaranen.ostoslista` → **Deploy Schema Changes to Production**.
   Ilman tätä synkkaus ja perhejako eivät toimi App Store -käyttäjillä.
3. **Arkistoi ja jaa Xcodessa** (helpoin tapa hoitaa jakelu­allekirjoitus oikein):
   Xcode → Product → Archive → Organizer → **Distribute App → App Store Connect**.
   Tämä luo/valitsee Apple Distribution -sertifikaatin ja App Store -profiilin ja
   asettaa push-ympäristön automaattisesti `production`ksi.
4. **App Store Connect** → uusi sovellus (bundle id `fi.maaranen.ostoslista`):
   - nimi, alaotsikko, kuvaus, avainsanat, tukisivun URL;
   - **kuvakaappaukset** (vähintään 6.7" iPhone; Mac Catalystille erikseen jos julkaiset senkin);
   - **App Privacy** -tiedot (nutrition labels): sijainti (käytetään, ei kerätä),
     iCloud-tallennus (käyttäjän oma), hakusanat lähetetään kauppojen palvelimille;
   - **hinta** (ilmainen/maksullinen);
   - **Privacy Policy -URL** (pakollinen — tarvitset julkisen tietosuojaselosteen).
5. **Lähetä arviointiin.**

## Tärkeät riskit (ratkaise ennen lähetystä)

⚠️ **Suurin este: sovellus hakee tuotetietoja kauppaketjujen epävirallisista
rajapinnoista** (S-kaupat, Puuilo/Algolia, Tokmanni/Klevu, K-Rauta, Motonet) ja
näyttää **K-ruoan tiedot WKWebView'n kautta ohittaen Cloudflaren**. Se näyttää
myös kauppojen nimiä, hintoja ja tuotekuvia. Tähän liittyy:

- **Apple App Review -sääntö 5.2.2 (immateriaalioikeudet):** toisen yrityksen
  sisällön/API:n käyttö ilman lupaa johtaa usein hylkäykseen.
- **Kauppojen käyttöehdot:** epävirallisten rajapintojen ja scrape-tekniikoiden
  (etenkin Cloudflaren ohitus) käyttö rikkoo tyypillisesti niitä; rajapinnat
  voivat myös hajota koska tahansa.
- **Tavaramerkit:** kauppojen nimet/logot/hinnat ilman lupaa.

Aiemmin sovittiin että nämä ovat **henkilökohtaiseen käyttöön**. **Julkinen App
Store -jakelu muuttaa tilanteen** — henkilökohtaisen käytön peruste ei enää päde.

**Suositukset:**
- Hanki **viralliset luvat/API-avaimet** kauppaketjuilta (esim. Kesko/K-ruoka
  developer-API omalla avaimella, jonka jo rekisteröit), tai
- **Julkaise ilman kauppaintegraatioita** (pelkkä vapaatekstilista + ryhmittely +
  jako + widget) — silloin ei ole IP-/scrape-riskiä ja app menee helposti läpi;
  kauppahaku voi jäädä omaan käyttöön (esim. rajattuna build-flagilla), tai
- Pidä app **henkilökohtaisena** (ei App Storea) — asenna vain omille laitteille,
  kuten nyt.

Koodi/konfiguraatio on teknisesti valmis; tämä on liiketoiminta-/laillisuus­päätös
joka sinun pitää tehdä ennen kuin lähetän mitään arviointiin puolestasi.
