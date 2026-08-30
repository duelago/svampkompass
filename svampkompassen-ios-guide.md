# Kompilera och installera Svampkompassen på iPhone

Snabbguide för att bygga appen från källkod och köra den på din egen iPhone. Du har redan Xcode, så det mesta handlar om att sätta upp Flutter-verktygen och koppla ditt utvecklarkonto.

Repo: https://github.com/duelago/svampkompass

---

## 1. Installera Flutter SDK

1. Ladda ner Flutter från [flutter.dev](https://flutter.dev) (eller `git clone https://github.com/flutter/flutter.git -b stable`).
2. Lägg till Flutters `bin`-mapp i din PATH, t.ex. i `~/.zshrc`:
   ```bash
   export PATH="$PATH:$HOME/flutter/bin"
   ```
3. Kör i terminalen:
   ```bash
   flutter doctor
   ```
   Den listar exakt vad som saknas (t.ex. licenser att godkänna) innan du går vidare.

## 2. Installera CocoaPods

iOS-beroenden i Flutter hanteras via CocoaPods:
```bash
sudo gem install cocoapods
```
(eller `brew install cocoapods` om du kör Homebrew)

## 3. Klona repot och hämta paket

```bash
git clone https://github.com/duelago/svampkompass
cd svampkompass
flutter pub get
```

## 4. Öppna projektet i Xcode och koppla ditt utvecklarkonto

Öppna **`ios/Runner.xcworkspace`** — inte `.xcodeproj`. Om du öppnar fel fil saknas CocoaPods-beroendena och du får konstiga byggfel.

I Xcode: markera `Runner` i projektträdet → fliken **Signing & Capabilities** → logga in med ditt Apple ID och välj ditt utvecklarteam, så att appen kan signeras för din enhet.

## 5. Kontrollera platsbehörighet i Info.plist

Appen bygger på GPS/kompass, så `ios/Runner/Info.plist` måste innehålla en nyckel som `NSLocationWhenInUseUsageDescription` med en förklarande text. Saknas den kraschar appen direkt när den försöker läsa positionen.

Kolla att den finns i filen (öppna `ios/Runner/Info.plist`). Om den saknas, lägg till:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Appen behöver din position för att visa kompassriktning till svampställen.</string>
```

## 6. Anslut din iPhone och kör appen

1. Anslut telefonen via USB och tryck **"Lita på den här datorn"** på skärmen.
2. Välj din enhet som mål i Xcode (eller kör `flutter run` i terminalen från projektmappen).
3. Första gången du kör appen behöver du godkänna utvecklarcertifikatet: **Inställningar → Allmänt → VPN och enhetshantering**.

## 7. Mer permanent installation

Så länge du har ett aktivt Apple Developer-konto räcker det att köra appen via Xcode/`flutter run` — den ligger kvar installerad på telefonen (omsignering krävs normalt efter ett år, beroende på kontotyp).

Vill du bygga en release-version:
```bash
flutter build ios --release
```
Eller arkivera i Xcode via **Product → Archive** om du vill distribuera vidare, t.ex. via TestFlight.

---

**Kontakta mig** om `flutter doctor` klagar på något du inte kan lösa, eller om appen kraschar direkt vid start — då är det troligen just platsbehörigheten i Info.plist.
