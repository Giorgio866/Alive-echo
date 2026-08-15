# CodeCompanion

App Android con AI locale + **compilazione/esecuzione DENTRO l'app**.

## Cosa gira sul telefono

- Editor + chat AI (modelli HF GGUF)
- Esecuzione automatica:
  - **Python** (Skulpt)
  - **JavaScript** (WebView)

## Opzionale

Modalità **PC** per Java/Kotlin (`compile-server/`).

## Build APK

```bash
cd android-app
export ANDROID_HOME=$HOME/android-sdk
./gradlew assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## Uso

1. Installa l'APK
2. Scheda **Build** → modalità **Nell'app** (default)
3. Scrivi Python/JS → auto-compile
4. Carica un modello HF per l'AI
