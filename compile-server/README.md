# CodeCompanion Compile Server

Piccolo server da avviare **sul PC**. L'APK gli manda il codice e riceve errori/output.

## Avvio

```bash
python3 compile-server/server.py
```

Ascolta su `0.0.0.0:8765`.

## Sul telefono

Nella scheda **Build** imposta l'URL, esempio:

`http://192.168.1.23:8765`

(usa l'IP LAN del PC; telefono e PC sulla stessa Wi‑Fi)

## Linguaggi

| Linguaggio   | Serve sul PC      |
|-------------|-------------------|
| Python      | `python3`         |
| JavaScript  | `node`            |
| Java        | JDK (`javac`/`java`) |
| Kotlin      | `kotlinc` + `java` |

## API

- `GET /health` → stato tool
- `POST /compile` body `{"language":"python","code":"..."}` → stdout/stderr
