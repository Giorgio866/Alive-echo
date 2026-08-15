# CodeCompanion

App Android con AI locale, **modelli a scelta da Hugging Face**, compilazione in-app e **immagini uncensored in-app**.

## Cosa gira sul telefono

- Editor + chat AI (GGUF)
- Ricerca Hugging Face: scegli repo e file
- Esecuzione Python / JavaScript
- Generazione immagini dopo download modello (Janus ONNX / SD ONNX)
- Nessun filtro extra sulle immagini nell'app

## Build APK

```bash
cd android-app
export ANDROID_HOME=$HOME/android-sdk
./gradlew assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`  
Download branch: `dist/CodeCompanion-debug.apk`

## Immagini

1. Scheda **Modelli** → cerca es. `janus onnx` oppure usa Janus Pro 1B
2. **Scarica e carica** (può richiedere minuti e tanta RAM)
3. Scheda **Immagini** → prompt → **Genera**
