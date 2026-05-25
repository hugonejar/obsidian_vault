#!/usr/bin/env python3
"""Minimal Pi-hole v6 Prometheus exporter."""
import json, os, time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen

PIHOLE_URL = os.getenv("PIHOLE_URL", "http://localhost")
PIHOLE_PASS = os.getenv("PIHOLE_PASSWORD")
if not PIHOLE_PASS:
    raise SystemExit("PIHOLE_PASSWORD env var is required (do not hardcode)")
REFRESH = int(os.getenv("REFRESH", "30"))
BIND_HOST = os.getenv("BIND_HOST", "127.0.0.1")

cache = {"metrics": "", "expires": 0}

def fetch_sid():
    data = json.dumps({"password": PIHOLE_PASS}).encode()
    req = Request(f"{PIHOLE_URL}/api/auth", data=data,
                  headers={"Content-Type": "application/json"})
    with urlopen(req) as r:
        return json.load(r)["session"]["sid"]

def fetch_stats(sid):
    headers = {"Accept": "application/json", "sid": sid}
    req = Request(f"{PIHOLE_URL}/api/stats/summary", headers=headers)
    with urlopen(req) as r:
        return json.load(r)

def build_metrics():
    global cache
    now = time.time()
    if now < cache["expires"]:
        return cache["metrics"]
    try:
        sid = fetch_sid()
        stats = fetch_stats(sid)
        q = stats.get("queries", {})
        lines = [
            "# HELP pihole_queries_total Total DNS queries processed",
            "# TYPE pihole_queries_total counter",
            f'pihole_queries_total {q.get("total", 0)}',
            "# HELP pihole_queries_blocked Total DNS queries blocked",
            "# TYPE pihole_queries_blocked counter",
            f'pihole_queries_blocked {q.get("blocked", 0)}',
            "# HELP pihole_queries_percent_blocked Percentage blocked",
            "# TYPE pihole_queries_percent_blocked gauge",
            f'pihole_queries_percent_blocked {q.get("percent_blocked", 0)}',
            "# HELP pihole_queries_cached Total cached queries",
            "# TYPE pihole_queries_cached counter",
            f'pihole_queries_cached {q.get("cached", 0)}',
            "# HELP pihole_queries_forwarded Total forwarded queries",
            "# TYPE pihole_queries_forwarded counter",
            f'pihole_queries_forwarded {q.get("forwarded", 0)}',
            "# HELP pihole_queries_unique_domains Unique domains",
            "# TYPE pihole_queries_unique_domains gauge",
            f'pihole_queries_unique_domains {q.get("unique_domains", 0)}',
            "# HELP pihole_clients_active Active clients",
            "# TYPE pihole_clients_active gauge",
            f'pihole_clients_active {stats.get("clients", {}).get("active", 0)}',
            "# HELP pihole_gravity_domains Domains in blocklist",
            "# TYPE pihole_gravity_domains gauge",
            f'pihole_gravity_domains {stats.get("gravity", {}).get("domains_being_blocked", 0)}',
        ]
        cache["metrics"] = "\n".join(lines) + "\n"
        cache["expires"] = now + REFRESH
    except Exception as e:
        cache["metrics"] = f"# pihole_exporter_error {str(e)}\n"
        cache["expires"] = now + 10
    return cache["metrics"]

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            try:
                body = build_metrics().encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(body)
            except BrokenPipeError:
                pass
        else:
            try:
                self.send_response(302)
                self.send_header("Location", "/metrics")
                self.end_headers()
            except BrokenPipeError:
                pass
    def log_message(self, *a): pass

if __name__ == "__main__":
    port = int(os.getenv("PORT", "9607"))
    print(f"pihole-exporter v6 on {BIND_HOST}:{port} -> {PIHOLE_URL}")
    HTTPServer((BIND_HOST, port), Handler).serve_forever()
