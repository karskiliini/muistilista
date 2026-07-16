# Kauppakatalogi ja hyllypaikat — design

**Päiväys:** 2026-07-17
**Status:** Hyväksytty (kaupat: K-ryhmä, S-ryhmä, Lidl, K-Rauta, Puuilo,
Motonet, Tokmanni, ABC; Kesko-avain: käyttäjä rekisteröityy)

## Tavoite

Tuotteen lisäykseen VALINNAINEN kauppapolku: valitse kauppa, hae/valitse
tuote, listalle tallentuu kauppa + hyllypaikka. Vapaasanalisäys ei muutu
millään tavalla (R4 säilyy: kirjoita ja rivinvaihto).

## Periaatteet

- `CatalogProvider`-protokolla eristää ketjukohtaiset rajapinnat: kaupat,
  tuotehaku (kategorioittain tarkentuva), tuotteen hyllypaikka jos saatavilla.
- Hyllypaikka on best-effort-dataa. Universaali täydentäjä on **perheen
  hyllymuisti**: käyttäjä voi napauttaa tuotteelle käytävän kerran, ja
  (tuote, kauppa) → hyllypaikka muistetaan ja synkkautuu perheelle listan
  jakohierarkian mukana.
- Katalogit haetaan käytön mukaan ja välimuistitetaan laitteelle (24 h TTL).
  Yöllinen esilataus (cron/BGTask) lisätään vain jos haku osoittautuu
  hitaaksi — YAGNI.

## Vaiheet

- **A — runko ilman rajapintoja (toteutetaan heti):** kauppa-nappi
  hakukentän oikeassa laidassa → lomake: kauppa (muistaa viimeisimmän,
  ehdottaa aiemmin käytettyjä), tuotenimi, valinnainen hyllypaikka.
  Hyllymuisti täyttää hyllypaikan automaattisesti kun (tuote, kauppa)
  tunnetaan. Listarivillä toinen rivi: "kauppa · hyllypaikka".
  Malli: CDShoppingItem += storeName?, shelfLocation?; uusi CDShelfMemory
  (productKey, storeName, shelfLocation, updatedAt, list-suhde → jaetaan
  perheelle CKSharen mukana).
- **B — Kesko (virallinen API):** developer.kesko.fi -avain; kaupat +
  tuotehaku kategorioineen K-ruokakauppoihin; hyllypaikka jos rajapinta
  antaa. Avain gitignoroituun Secrets.xcconfig-tiedostoon.
- **C — S-kaupat (epävirallinen GraphQL):** Prisma/S-market/Alepa.
  Hauras; toteutus eristetään providerin taakse ja rikkoutuminen saa
  pudottaa vain katalogihaun, ei kauppalisäystä.
- **D — muut ketjut (Motonet, Tokmanni, Puuilo, K-Rauta):** kunkin
  verkkokaupan hakupäätepisteet tutkitaan erikseen; lisätään provider
  kerrallaan. Ilman provideria ketju toimii vaiheen A manuaalipolulla.

## Ei muutu / rajaukset

Vapaasanalisäys, ruksaus, määräveto, poisto, synkka, widget. Ei
hintatietoja, ei ostoskorin arvoa, ei mainoksia.
