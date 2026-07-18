# Vastaus App Review'lle — Guideline 2.1 (Information Needed)

Submission ID: `2bbb98a4-62c0-42ca-bb67-0e07dcc7c6e4`, Ostos 1.34.0 (iOS).

**Mitä teet:**

1. Avaa App Store Connect → Apps → Ostos → **App Review** -sivu →
   vastaa lähetyksen viestiketjuun: liitä molemmat videot
   (`review-recording-1-main-flow.mp4` ja
   `review-recording-2-searches-widget.mp4` tästä kansiosta) ja kopioi
   alla oleva englanninkielinen teksti.
2. Kopioi sama teksti myös **App Review Information → Notes** -kenttään
   tulevia lähetyksiä varten (Apple pyysi tätä erikseen).

**Videot** (kuvattu iPhone 12 minillä, iOS 26.5.2, 18.7.2026):

- `review-recording-1-main-flow.mp4` (2:19, 48 MB): tuore asennus —
  käynnistys kotinäytöltä, **ilmoituslupakysely** kohdassa 0:07, tyhjä
  lista → iCloud-synkka tuo rivit, vapaatekstilisäys, S-market- ja
  K-Market-haut hintoineen, tuotenäkymä, veto kauppojen välillä,
  ruksaukset ja summat.
- `review-recording-2-searches-widget.mp4` (2:42, 51 MB): pidempi
  sessio — vapaatekstirivit, K-Market- ja Motonet-haut (määrävalinta
  ×2), ruksaukset, summat, widgetin lisäys kotinäytölle; päättyy
  widgetiin "7 tuotetta ostettavana". (Alkuperäisestä leikattu pois
  lopun widget-napautus, joka avasi mustan ruudun — bugi kirjattu
  vaatimukseksi R35.)

**Ei videolla** (kerrotaan tekstissä rehellisesti): sijaintilupakysely
(iOS säilytti aiemman luvan uudelleenasennuksen yli, joten kysely ei
tullut näkyviin) ja iCloud-jakonäkymä. Halutessasi nämä saa talteen
~30 s lisäklipillä: Asetukset → Tietosuoja → Sijaintipalvelut →
Ostoslista → "Kysy ensi kerralla", sulje appi pakotetusti, nauhoita:
käynnistys → person+-nappi (jakonäkymä) → kauppahaku K-kaupasta →
sijaintikysely → valmis.

---

## Kopioitava vastaus (englanniksi)

```
Hello,

Thank you for the review. Here is the requested information. Two screen
recordings captured on a physical iPhone 12 mini (iOS 26.5.2) are
attached.

1. SCREEN RECORDINGS
Recording 1 begins with launching the app on a fresh install and shows:
the notification permission prompt at 0:07 (notifications tell the user
when a family member edits the shared list), the empty list populated
by iCloud sync, adding a free-text item, product search from S-market
and K-Market with live prices, the product detail view, dragging an
item between store sections, and checking items off with per-store and
grand totals. Recording 2 shows a longer session: free-text items,
K-Market and Motonet searches (with quantity selection), checking items
off, and adding the home screen widget, ending with the widget showing
the number of items left to buy.
The app has no account registration or login, no paid content or
subscriptions, and no public user-generated content: lists are private
and shareable only via the user's own iCloud with people they invite
(standard iCloud sharing sheet from the toolbar button).
One prompt is not on camera: location when-in-use. iOS retained the
previously granted permission across reinstall, so it did not reappear.
It is requested the first time the app picks the nearest K-chain store
for product search; purpose string: "Sijaintia käytetään lähimmän
K-ruokakaupan valintaan tuotehakuun." ("Location is used to select the
nearest K grocery store for product search."). Location is used only
on-device and is never collected.

2. DEVICES AND OS TESTED
- iPhone 12 mini (physical device), iOS 26.5.2
- iPhone 17 Pro Max simulator, iOS 26.5
- iPad Pro 13-inch simulator, iOS 26.5
Built with Xcode 26.6; minimum deployment target iOS 17.

3. PURPOSE AND TARGET AUDIENCE
Ostos is a shopping list app for Finnish households. Items are grouped
by store, prices and per-store totals are shown, and one list can be
shared with the family through the user's own iCloud so changes appear
on everyone's devices immediately. Target audience: Finnish consumers
and families. Free, no ads, no accounts, no data collection by the
developer.

4. SETUP AND ACCESS
No setup, login, credentials, or sample files are needed. Launch the
app and type items; use the store button to search a product by name
and add it with its price; drag items between store sections; tap items
to mark them bought; share via the toolbar button (iCloud); add the
widget from the home screen. iCloud sync works automatically when the
device is signed in to iCloud.

5. EXTERNAL SERVICES
Apple CloudKit (private database) for sync and private sharing, and
Apple Push Notifications for change notifications. Product search
queries the public product-search endpoints of Finnish retailers' own
online stores: S-kaupat, K-Ruoka, K-Rauta, Gigantti, Motonet, Puuilo,
Tokmanni. Only the user-typed search term is sent, and the returned
public product information (name, price, image) is shown. No
authentication services, payment processors, AI services, analytics,
or advertising SDKs.

6. REGIONAL DIFFERENCES
The app functions identically in all regions; there is no region-based
gating. The UI is in Finnish and store search covers Finnish retail
chains, so the app is primarily useful in Finland, but all core
features work anywhere.

7. REGULATED INDUSTRY / PROTECTED MATERIAL
The app does not operate in a regulated industry. No third-party
material is bundled; the app only displays publicly available product
information (name, price, image) from the retailers' public online
stores in direct response to a user search, with the retailer named as
the source.

Best regards,
Tero Maaranen
```
