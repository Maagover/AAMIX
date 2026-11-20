"""Local HTTP contract fixture, not an account server. Never sends email.
Usage: python probar_cuentas.py /path/to/godot [--gui]
"""
import json
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main():
    project = Path(__file__).resolve().parent.parent
    users, refreshes, requests = {}, {}, []
    serial = 0

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass  # No emails, codes or tokens in logs.

        def reply(self, status, payload):
            body = b"" if status == 204 else json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def session(self, email):
            nonlocal serial
            serial += 1
            user = users[email]
            refresh = f"fixture-refresh-{serial}"
            refreshes[refresh] = email
            return {"user": user, "access_token": "fixture-access-" + user["id"],
                    "refresh_token": refresh, "expires_in": 3600, "token_type": "bearer"}

        def do_POST(self):
            data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            requests.append(self.path)
            if self.headers.get("apikey") != "sb_publishable_contract_fixture":
                return self.reply(401, {"error_code": "bad_key"})
            email = data.get("email", "")
            if self.path == "/auth/v1/otp":
                if email == "rate@fixture.invalid":
                    return self.reply(429, {"error_code": "over_email_send_rate_limit"})
                if email not in users:
                    if not data.get("create_user"):
                        return self.reply(400, {"error_code": "otp_disabled"})
                    users[email] = {"id": f"00000000-0000-4000-8000-{len(users)+1:012d}",
                                    "email": email, "user_metadata": data.get("data", {})}
                return self.reply(200, {})
            if self.path == "/auth/v1/verify":
                if data.get("token") != "123456" or data.get("type") != "email" or email not in users:
                    return self.reply(403, {"error_code": "otp_expired"})
                if email == "malformed@fixture.invalid":
                    return self.reply(200, {"access_token": "incomplete-session"})
                return self.reply(200, self.session(email))
            if self.path == "/auth/v1/token?grant_type=refresh_token":
                email = refreshes.pop(data.get("refresh_token", ""), "")
                if not email:
                    return self.reply(401, {"error_code": "refresh_token_not_found"})
                return self.reply(200, self.session(email))
            if self.path == "/auth/v1/logout?scope=local":
                if not self.headers.get("Authorization", "").startswith("Bearer fixture-access-"):
                    return self.reply(401, {})
                return self.reply(204, None)
            return self.reply(404, {})

    # Bind only to this computer, on an automatically chosen port.
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    command = [sys.argv[1], "--path", str(project)]
    command += ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"] if "--gui" in sys.argv else ["--headless"]
    command += ["--script", "res://tests/test_accounts.gd", "--log-file", str(project.parent.parent/"auth-test.log"), "--",
                f"--auth-test-url=http://127.0.0.1:{server.server_port}"]
    command += [arg for arg in sys.argv[2:] if arg.startswith("--account-screenshots=")]
    try:
        result = subprocess.run(command, timeout=90)
        print(json.dumps({"http_fixture_requests": len(requests), "real_emails_sent": 0}))
        return result.returncode
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
