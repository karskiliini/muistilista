# Kohta 4 — App Store Connect vaihe vaiheelta

Kirjaudu **appstoreconnect.apple.com** (sama Apple-tunnus kuin kehittäjätili).
Tämä on se osa jota en voi tehdä puolestasi (vaatii sinun kirjautumisesi ja
"Submit"-napin painamisen). Kaikki liitettävä sisältö on valmiina alla.

## A. Luo sovellus (kertaalleen)
1. **Apps → + → New App.**
2. Platform: **iOS**. Name: **Ostoslista**. Primary language: **Finnish**.
   Bundle ID: **fi.maaranen.ostoslista**. SKU: mikä tahansa uniikki, esim.
   `ostoslista-001`. User Access: Full.

## B. Version-sivun kentät (liitä `metadata.md`:stä)
- **Promotional Text** → metadata.md "Promootioteksti".
- **Description** → metadata.md "Kuvaus".
- **Keywords** → metadata.md "Avainsanat".
- **Support URL** → oma tuki-URL (pakollinen; esim. GitHub-repo tai sähköpostisivu).
- **Marketing URL** → valinnainen.
- **App Store -kuvat (6.9"):** raahaa `docs/app-store/`:
  - `screenshot-01-list-6.9.png`
  - `screenshot-02-shopping-6.9.png`
  (vähintään 1 vaaditaan; 3–10 suositellaan — voit tehdä lisää
  `app-store-checklist.md`:n komennolla.)

## C. General / App Information
- **Subtitle** → metadata.md "Alaotsikko".
- **Category:** Primary = **Shopping** (Ostokset).
- **Content Rights:** jos kysytään kolmannen osapuolen sisällöstä, ks. huom alla.

## D. App Privacy (pakollinen ennen submitia)
1. **Data Collection:** valitse pääosin **"Data Not Collected"** —
   ostoslista on käyttäjän omassa iCloudissa, sijainti on on-device.
2. Jos haluat tarkkuutta: ilmoita **Search History** → *App Functionality*,
   *Not linked to identity*, *Not used for tracking* (hakusanat menevät
   kauppojen palvelimille). Muuten "Not Collected".
3. **Privacy Policy URL** (pakollinen): julkaise `privacy-policy.md` julkiseen
   osoitteeseen (esim. GitHub Pages / oma sivu) ja liitä URL.

## E. Age Rating
Täytä kyselyn kaikki kohdat "None" → todennäköisesti **4+**.

## F. Build
- Version-sivulla **Build → +** → valitse juuri lataamasi buildi (**1.34.0 (2)**).
  (Näkyy vasta kun lataus on käsitelty, tyypillisesti 5–30 min.)
- **Export Compliance:** on jo hoidettu (`ITSAppUsesNonExemptEncryption=false`)
  → ei kysy erikseen.

## G. Hinnoittelu
- **Pricing and Availability** → hinta (esim. **Free**) ja maat.

## H. Lähetä
- **Add for Review → Submit.** Ensimmäinen arviointi kestää tyypillisesti
  1–3 vrk.

---

⚠️ **Muista kohta "Tärkeät riskit" (`app-store-checklist.md`):** kauppadatan
scrape/epäviralliset rajapinnat (S-kaupat, K-ruoka, Gigantti, Motonet, Puuilo,
Tokmanni, K-Rauta) voivat aiheuttaa hylkäyksen (App Review 5.2.2) tai
käyttöehto-ongelmia julkisessa jakelussa. Tämä on syytä ratkaista ennen
submitia — päätös on sinun.
