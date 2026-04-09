import base64
import json
import socket
import time
import urllib.error
import urllib.request
from pathlib import Path

API_URL = "http://192.168.25.126:8081/service/rest/v1/script/create_repos_from_list/run"
USER = "admin"
PASSWORD = "nexus1234"
TIMEOUT = 45

payload = json.loads(
    Path("c:/Users/User/git/ansible-role-nexus3-oss/tmp-create-repos-payload.json").read_text(
        encoding="utf-8"
    )
)

auth = base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()


def run_chunk(items):
    data = json.dumps(items).encode("utf-8")
    req = urllib.request.Request(API_URL, data=data, method="POST")
    req.add_header("Authorization", f"Basic {auth}")
    req.add_header("Content-Type", "text/plain")
    started = time.time()
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            elapsed = time.time() - started
            return True, resp.status, elapsed, body[:220]
    except urllib.error.HTTPError as e:
        elapsed = time.time() - started
        return False, e.code, elapsed, e.read().decode("utf-8", errors="replace")[:220]
    except (urllib.error.URLError, TimeoutError, socket.timeout) as e:
        elapsed = time.time() - started
        return False, -1, elapsed, str(e)


def bisect(items, offset=0):
    ok, code, elapsed, snippet = run_chunk(items)
    print(f"test offset={offset} size={len(items)} -> ok={ok} code={code} t={elapsed:.2f}s", flush=True)
    if ok:
        return []
    if len(items) == 1:
        one = dict(items[0])
        one["_offset"] = offset
        one["_error"] = snippet
        return [one]
    mid = len(items) // 2
    left = bisect(items[:mid], offset)
    right = bisect(items[mid:], offset + mid)
    return left + right


if __name__ == "__main__":
    bad = bisect(payload, 0)
    out = Path("c:/Users/User/git/ansible-role-nexus3-oss/tmp-create-repos-bisect-result.json")
    out.write_text(json.dumps(bad, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"bad_count={len(bad)}", flush=True)
    print(f"result_file={out}", flush=True)
    if bad:
        print("bad_names=", [x.get("name") for x in bad], flush=True)
