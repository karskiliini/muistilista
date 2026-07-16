# Ostoslista

Yksinkertainen iOS-ostoslistasovellus. SwiftUI + SwiftData, ei synkkausta —
lista elää puhelimessa.

## Kehitys

Projekti generoidaan XcodeGenillä:

    xcodegen generate        # luo Ostoslista.xcodeproj (gitignored)
    open Ostoslista.xcodeproj

## Testit

    xcodebuild -project Ostoslista.xcodeproj -scheme Ostoslista \
      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

## Puhelimeen asennus

Avaa projekti Xcodessa, valitse Signing & Capabilities -välilehdeltä oma
Personal Team, kytke iPhone kaapelilla ja paina Run. Ilmaisella Apple
ID:llä sovellus pitää allekirjoittaa uudelleen 7 päivän välein.
