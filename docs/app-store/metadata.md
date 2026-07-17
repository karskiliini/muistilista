# App Store -tekstit (luonnos)

Kopioi nämä App Store Connectiin. Merkkirajat suluissa.

## Nimi (≤30)
Ostoslista

## Alaotsikko (≤30)
Kauppakohtainen ostoslista

## Avainsanat (≤100, pilkuin, ei välilyöntejä)
ostoslista,kauppa,ruokakauppa,perhe,jaettu,lista,hinnat,widget,ruokaostokset,muistilista,ostokset

## Promootioteksti (≤170)
Ryhmittele ostokset kaupoittain, näe hinnat ja yhteissummat, ja jaa lista perheelle iCloudissa. Muutokset näkyvät heti kaikilla laitteilla.

## Kuvaus
Ostoslista pitää ruokaostokset järjestyksessä ja jaettuna koko perheelle.

• Ryhmittely kaupoittain — jokainen kauppa omana osionaan, ostamattomat ensin.
• Hinnat ja yhteissummat — kauppakohtaiset summat ja kaikkien kauppojen yhteissumma.
• Tuotehaku kaupasta — hae tuote nimellä ja saat hinnan ja tuotetiedot suoraan listalle (tuetut kaupat).
• Vedä ja järjestä — järjestä tuotteet ja siirrä ne kaupasta toiseen vetämällä.
• Perhejako iCloudissa — jaa sama lista perheenjäsenille; muutokset synkkautuvat heti, ja saat ilmoituksen kun joku muu muokkaa listaa.
• Kotinäytön widget — näet listan yhdellä silmäyksellä avaamatta sovellusta.
• Nopea vapaateksti — kirjoita mitä tahansa, ei pakollisia kenttiä.

Tiedot tallentuvat omaan iCloudiisi. Ei mainoksia, ei tilejä.

## Tukisivun URL
(täytä oma tuki-/yhteydenotto-URL — esim. GitHub-repo tai sähköpostisivu)

## Tietosuojaseloste-URL
(pakollinen — julkaise docs/app-store/privacy-policy.md julkiseen osoitteeseen ja liitä URL tähän)

## App Privacy (nutrition labels) -vastaukset
- Kerätäänkö dataa? Käytännössä ei kehittäjän toimesta:
  - Sijainti: käytetään lähimmän K-ruokakaupan valintaan, EI kerätä/lähetetä kehittäjälle → "Not Collected" (käyttö on on-device).
  - Ostoslistan sisältö: tallentuu käyttäjän omaan iCloudiin (CloudKit private DB), ei kehittäjän palvelimille.
  - Tuotehaku: hakusanat lähetetään kauppojen palvelimille haun suorittamiseksi. Jos App Store Connect kysyy, ilmoita "Search History → App Functionality, Not Linked to identity, No tracking".
- Seuranta (tracking): Ei.
