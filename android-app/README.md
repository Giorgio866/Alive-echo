# CodeCompanion

App Android con AI locale (Hugging Face GGUF) + **compilazione automatica** via PC.

## Architettura

- **APK**: editor, chat, modelli, auto-compile client
- **PC**: `compile-server/server.py` compila/esegue codice

## Build APK

```bash
cd android-app
export ANDROID_HOME=$HOME/android-sdk
./gradlew assembleDebug
```

Output: `app/build/outputs/apk/debug/app-debug.apk`

## Setup compilazione

1. Sul PC:
   ```bash
   python3 compile-server/server.py
   ```
2. Nell'app → scheda **Build** → URL tipo `http://IP_DEL_PC:8765`
3. Attiva **Auto-compile** (già on) e opzionale **Auto-fix AI**

## Flusso

1. Scrivi codice nell'Editor (o chiedi all'AI)
2. L'app invia il codice al PC
3. Vedi output/errori sotto l'editor
4. Se fallisce e Auto-fix è on, l'AI prova a correggere
