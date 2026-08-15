# CodeCompanion

App Android (**solo APK**) per assistenza alla programmazione con modelli GGUF da Hugging Face, in esecuzione locale sul telefono.

## Cosa fa

- Editor di codice
- Chat AI locale (via motore WebAssembly llama.cpp / wllama)
- Catalogo modelli HF (coding + uncensored + test)
- Download GGUF nella memoria dell'app
- Caricamento modello in AI direttamente da Hugging Face

## Limiti (voluti)

- Nessun PC remoto
- Nessuna compilazione automatica tipo Cursor
- Servono modelli piccoli (Q4, idealmente ≤ 1.5–2 GB) e un telefono con abbastanza RAM
- La prima volta serve internet per scaricare motore WASM + modello

## Build APK

```bash
cd android-app
export ANDROID_HOME=$HOME/android-sdk
./gradlew assembleDebug
```

APK di output:

`android-app/app/build/outputs/apk/debug/app-debug.apk`

## Uso rapido

1. Apri **Modelli**
2. Premi **Carica in AI** su un modello piccolo (parti da TinyLlama o TinyStories per test)
3. Vai in **Chat** e chiedi aiuto sul codice
4. Oppure dall'**Editor** usa **Invia ad AI**
