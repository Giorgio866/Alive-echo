# HACCP Cucina

App Android Flutter per la gestione operativa HACCP in **cucina** e **pizzeria**.

## Funzionalità

- **Temperature CCP** — punti di misura (frigo, freezer, abbattitore, banco caldo) con range, letture giornaliere e segnalazione fuori range
- **Pulizie / sanificazione** — checklist giornaliere e settimanali con firma operatore
- **Lotti e tracciabilità** — merci in ingresso, scadenze, allergeni, stato “aperto” con use-by
- **Scansione documenti** — fotocamera/galleria per DDT, certificati e formazione (archivio locale)
- **Etichette termiche** — layout ESC/POS e stampa Bluetooth (stampanti 58 mm)
- **Dashboard** — riepilogo controlli mancanti, alert e azioni rapide

I dati restano **offline sul dispositivo** (SQLite + file locali).

## APK Android pronto

File installabile (release):

- `haccp_cucina/dist/HACCP-Cucina.apk`

### Installazione sul telefono

1. Copia `HACCP-Cucina.apk` sul telefono (USB, Drive, email, ecc.)
2. Apri il file e consenti **origini sconosciute** se richiesto
3. Installa e apri **HACCP Cucina**

> Nota: l’APK è firmato con la chiave **debug** di sviluppo (ok per prova interna). Per Play Store serve una keystore di release.

### Rigenerare l’APK

```bash
cd haccp_cucina
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk dist/HACCP-Cucina.apk
```

## Requisiti

- Flutter 3.32+ / Dart 3.8+
- Android 6.0+ (API 23), consigliato dispositivo con fotocamera e Bluetooth

## Avvio

```bash
cd haccp_cucina
flutter pub get
flutter run
```

Build release Android:

```bash
flutter build apk --release
```

## Stampante termica

1. Accoppia la stampante ESC/POS nelle impostazioni Bluetooth di Android
2. In app: **Altro → Impostazioni → Cerca stampanti accoppiate**
3. Compila l’etichetta in **Altro → Etichette termiche** e premi **Stampa**

## Test

```bash
cd haccp_cucina
flutter test
```

## Struttura

```
lib/
  data/          # modelli, SQLite, repository
  features/      # schermate (home, temperature, pulizie, lotti, documenti, etichette)
  services/      # scansione documenti, stampa termica, settings
  providers/     # Riverpod
  theme/         # tema Material 3
```
