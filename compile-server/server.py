#!/usr/bin/env python3
"""CodeCompanion compile server — run on your PC, phone connects to it."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

HOST = os.environ.get("CC_HOST", "0.0.0.0")
PORT = int(os.environ.get("CC_PORT", "8765"))
TIMEOUT_SEC = int(os.environ.get("CC_TIMEOUT", "20"))


def which(cmd: str) -> str | None:
    return shutil.which(cmd)


def run(cmd: list[str], cwd: Path, timeout: int = TIMEOUT_SEC) -> dict[str, Any]:
    started = time.time()
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {
            "exitCode": proc.returncode,
            "stdout": proc.stdout or "",
            "stderr": proc.stderr or "",
            "durationMs": int((time.time() - started) * 1000),
            "timedOut": False,
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "exitCode": 124,
            "stdout": (exc.stdout or "") if isinstance(exc.stdout, str) else "",
            "stderr": ((exc.stderr or "") if isinstance(exc.stderr, str) else "")
            + f"\nTimeout dopo {timeout}s",
            "durationMs": int((time.time() - started) * 1000),
            "timedOut": True,
        }


def tool_status() -> dict[str, bool]:
    return {
        "python": which("python3") is not None or which("python") is not None,
        "javascript": which("node") is not None,
        "java": which("javac") is not None and which("java") is not None,
        "kotlin": which("kotlinc") is not None,
    }


def compile_and_run(language: str, code: str, filename: str | None = None) -> dict[str, Any]:
    lang = language.lower().strip()
    tools = tool_status()

    with tempfile.TemporaryDirectory(prefix="codecompanion_") as tmp:
        root = Path(tmp)

        if lang in ("python", "py"):
            if not tools["python"]:
                return fail("Python non trovato sul PC (installa python3).")
            py = which("python3") or which("python")
            path = root / (filename or "main.py")
            path.write_text(code, encoding="utf-8")
            result = run([py, str(path.name)], cwd=root)
            return wrap(result, "python", path.name)

        if lang in ("javascript", "js", "node"):
            if not tools["javascript"]:
                return fail("Node.js non trovato sul PC (installa node).")
            path = root / (filename or "main.js")
            path.write_text(code, encoding="utf-8")
            result = run(["node", str(path.name)], cwd=root)
            return wrap(result, "javascript", path.name)

        if lang in ("java",):
            if not tools["java"]:
                return fail("JDK non trovato sul PC (serve javac + java).")
            class_name = detect_java_class(code) or "Main"
            path = root / f"{class_name}.java"
            path.write_text(code, encoding="utf-8")
            compile_result = run(["javac", path.name], cwd=root)
            if compile_result["exitCode"] != 0:
                return wrap(compile_result, "java", path.name, phase="compile")
            run_result = run(["java", class_name], cwd=root)
            merged = {
                "exitCode": run_result["exitCode"],
                "stdout": run_result["stdout"],
                "stderr": (compile_result["stderr"] + "\n" + run_result["stderr"]).strip(),
                "durationMs": compile_result["durationMs"] + run_result["durationMs"],
                "timedOut": run_result["timedOut"],
            }
            return wrap(merged, "java", path.name, phase="run")

        if lang in ("kotlin", "kt"):
            if not tools["kotlin"]:
                return fail(
                    "kotlinc non trovato sul PC. Installa Kotlin compiler "
                    "oppure usa python/javascript/java."
                )
            path = root / (filename or "Main.kt")
            path.write_text(code, encoding="utf-8")
            jar = root / "out.jar"
            compile_result = run(
                ["kotlinc", path.name, "-include-runtime", "-d", jar.name],
                cwd=root,
            )
            if compile_result["exitCode"] != 0:
                return wrap(compile_result, "kotlin", path.name, phase="compile")
            java_bin = which("java")
            if not java_bin:
                return fail("Kotlin compilato, ma java non è disponibile per eseguirlo.")
            run_result = run([java_bin, "-jar", jar.name], cwd=root)
            merged = {
                "exitCode": run_result["exitCode"],
                "stdout": run_result["stdout"],
                "stderr": (compile_result["stderr"] + "\n" + run_result["stderr"]).strip(),
                "durationMs": compile_result["durationMs"] + run_result["durationMs"],
                "timedOut": run_result["timedOut"],
            }
            return wrap(merged, "kotlin", path.name, phase="run")

        return fail(f"Linguaggio non supportato: {language}")


def detect_java_class(code: str) -> str | None:
    import re

    match = re.search(r"\bpublic\s+class\s+([A-Za-z_][A-Za-z0-9_]*)", code)
    if match:
        return match.group(1)
    match = re.search(r"\bclass\s+([A-Za-z_][A-Za-z0-9_]*)", code)
    return match.group(1) if match else None


def fail(message: str) -> dict[str, Any]:
    return {
        "ok": False,
        "exitCode": 1,
        "stdout": "",
        "stderr": message,
        "durationMs": 0,
        "language": None,
        "filename": None,
        "phase": "setup",
    }


def wrap(
    result: dict[str, Any],
    language: str,
    filename: str,
    phase: str = "run",
) -> dict[str, Any]:
    return {
        "ok": result["exitCode"] == 0 and not result.get("timedOut"),
        "exitCode": result["exitCode"],
        "stdout": result.get("stdout", ""),
        "stderr": result.get("stderr", ""),
        "durationMs": result.get("durationMs", 0),
        "language": language,
        "filename": filename,
        "phase": phase,
        "timedOut": bool(result.get("timedOut")),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "CodeCompanionCompile/1.0"

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[compile-server] {self.address_string()} - {fmt % args}")

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path in ("/", "/health"):
            self._json(
                200,
                {
                    "ok": True,
                    "service": "codecompanion-compile",
                    "tools": tool_status(),
                },
            )
            return
        self._json(404, {"ok": False, "stderr": "Not found"})

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._json(400, fail("JSON non valido"))
            return

        if path == "/compile":
            language = str(data.get("language") or "python")
            code = str(data.get("code") or "")
            filename = data.get("filename")
            if not code.strip():
                self._json(400, fail("Codice vuoto"))
                return
            result = compile_and_run(language, code, filename)
            self._json(200, result)
            return

        self._json(404, fail("Not found"))


def main() -> None:
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    tools = tool_status()
    print(f"CodeCompanion compile server on http://{HOST}:{PORT}")
    print(f"Tools: {tools}")
    print("Dal telefono usa l'IP del PC, es. http://192.168.1.10:8765")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
