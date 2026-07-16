# Ostoslista

Yksinkertainen iOS-ostoslistasovellus (SwiftUI + Core Data/CloudKit),
generoidaan XcodeGenillä (`project.yml`). Buildi-, testi- ja
asennuskomennot: katso `README.md`.

## Vaatimusrekisteri — pakollinen joka promptilla

`docs/requirements.md` on sovelluksen vaatimusten ainoa totuus: kaikki
vaatimukset yhdessä toteutettuna tuottavat täsmälleen tämän sovelluksen.

**Jokaisen käyttäjäpromptin kohdalla**, joka lisää, muuttaa tai poistaa
sovelluksen käyttäytymistä: käytä `requirements`-skilliä
(`.claude/skills/requirements/SKILL.md`) — vertaa promptia rekisteriin ja
lisää/päivitä/poista vaatimus samassa käänteessä kuin itse muutos.
Jos prompti on jo katettu, mainitse vastaava R-numero vastauksessa.

## Käytännöt

- Speksit: `docs/superpowers/specs/`, suunnitelmat: `docs/superpowers/plans/`.
- Generoitua `Ostoslista.xcodeproj`:ää ei committoida; aja
  `xcodegen generate` muutosten jälkeen (binääri:
  `/opt/homebrew/Cellar/xcodegen/2.45.4/bin/xcodegen`).
- Listalogiikka pidetään `ShoppingListLogic`issa tallennuskehyksestä
  riippumattomana ja yksikkötestattuna.
