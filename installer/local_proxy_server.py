#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from http.client import HTTPConnection, HTTPSConnection
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}


def parse_bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def build_handler(frontend_dir: Path, backend_url: str, runtime_config: dict[str, object]):
    backend_parts = urlsplit(backend_url)
    if backend_parts.scheme not in {"http", "https"}:
        raise ValueError("backend_url must use http or https")
    if not backend_parts.hostname:
        raise ValueError("backend_url must include a hostname")

    backend_port = backend_parts.port or (443 if backend_parts.scheme == "https" else 80)
    backend_cls = HTTPSConnection if backend_parts.scheme == "https" else HTTPConnection

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(frontend_dir), **kwargs)

        def do_GET(self) -> None:
            self._route_request(head_only=False)

        def do_HEAD(self) -> None:
            self._route_request(head_only=True)

        def do_POST(self) -> None:
            self._proxy_request(head_only=False)

        def do_PUT(self) -> None:
            self._proxy_request(head_only=False)

        def do_PATCH(self) -> None:
            self._proxy_request(head_only=False)

        def do_DELETE(self) -> None:
            self._proxy_request(head_only=False)

        def do_OPTIONS(self) -> None:
            self._proxy_request(head_only=False)

        def _route_request(self, *, head_only: bool) -> None:
            path = urlsplit(self.path).path
            if path == "/runtime-config.js":
                self._serve_runtime_config(head_only=head_only)
                return
            if path.startswith("/api/") or path == "/health":
                self._proxy_request(head_only=head_only)
                return

            translated_path = Path(self.translate_path(path))
            if path != "/" and not translated_path.exists() and "." not in Path(path).name:
                original_path = self.path
                self.path = "/index.html"
                try:
                    if head_only:
                        super().do_HEAD()
                    else:
                        super().do_GET()
                finally:
                    self.path = original_path
                return

            if head_only:
                super().do_HEAD()
            else:
                super().do_GET()

        def _serve_runtime_config(self, *, head_only: bool) -> None:
            payload = (
                "window.__GITVIBE_RUNTIME_CONFIG__ = Object.freeze("
                + json.dumps(runtime_config, separators=(",", ":"))
                + ");\n"
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/javascript; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if not head_only:
                self.wfile.write(payload)

        def _proxy_request(self, *, head_only: bool) -> None:
            path = urlsplit(self.path).path
            if not (path.startswith("/api/") or path == "/health"):
                self.send_error(405, "Only /api/* and /health are accepted for non-static methods")
                return

            content_length = int(self.headers.get("Content-Length", "0") or "0")
            body = self.rfile.read(content_length) if content_length > 0 else None

            upstream_headers: dict[str, str] = {}
            for key, value in self.headers.items():
                lower = key.lower()
                if lower in HOP_BY_HOP_HEADERS or lower == "host":
                    continue
                upstream_headers[key] = value
            upstream_headers["Host"] = backend_parts.netloc

            connection = backend_cls(backend_parts.hostname, backend_port, timeout=15)
            try:
                connection.request(self.command, self.path, body=body, headers=upstream_headers)
                response = connection.getresponse()
                payload = response.read()

                self.send_response(response.status, response.reason)
                for key, value in response.getheaders():
                    lower = key.lower()
                    if lower in HOP_BY_HOP_HEADERS or lower == "content-length":
                        continue
                    self.send_header(key, value)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                if not head_only and self.command != "HEAD":
                    self.wfile.write(payload)
            except OSError as exc:
                error_payload = json.dumps({"detail": f"Upstream backend error: {exc}"}).encode("utf-8")
                self.send_response(502)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(error_payload)))
                self.end_headers()
                if not head_only:
                    self.wfile.write(error_payload)
            finally:
                connection.close()

    return Handler


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve frontend locally with API proxy support.")
    parser.add_argument("--frontend-dir", required=True)
    parser.add_argument("--backend-url", default="http://127.0.0.1:8000")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3000)
    parser.add_argument("--app-mode", default="demo")
    parser.add_argument("--demo-namespace", default="gitvibe_demo_v1")
    parser.add_argument("--allow-demo-on-public-host", default="false")
    args = parser.parse_args()

    runtime_config = {
        "APP_MODE": args.app_mode,
        "API_BASE_URL": "",
        "DEMO_NAMESPACE": args.demo_namespace,
        "ALLOW_DEMO_ON_PUBLIC_HOST": parse_bool(args.allow_demo_on_public_host),
    }

    frontend_dir = Path(args.frontend_dir).resolve()
    if not frontend_dir.exists():
        raise FileNotFoundError(f"frontend directory not found: {frontend_dir}")

    handler = build_handler(frontend_dir, args.backend_url, runtime_config)
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving local frontend at http://{args.host}:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
