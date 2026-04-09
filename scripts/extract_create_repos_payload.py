import json
import pathlib

log_path = pathlib.Path("c:/Users/User/git/ansible-role-nexus3-oss/tmp-nexus-vvv.log")
out_path = pathlib.Path("c:/Users/User/git/ansible-role-nexus3-oss/tmp-create-repos-payload.json")

text = log_path.read_text(encoding="utf-8", errors="replace")
body_line = None
for line in text.splitlines():
    if '"body": "[{' in line and '", "body_format"' in line:
        body_line = line
        break
if body_line is None:
    raise SystemExit("payload body line not found in verbose log")

prefix = '"body": "'
start = body_line.index(prefix) + len(prefix)
end = body_line.index('", "body_format"')
escaped_payload = body_line[start:end]
body_text = bytes(escaped_payload, "utf-8").decode("unicode_escape")
body_text = bytes(body_text, "utf-8").decode("unicode_escape")
try:
    payload, end_pos = json.JSONDecoder().raw_decode(body_text)
except json.JSONDecodeError as exc:
    print("decode_error_prefix:", repr(body_text[:200]))
    at = exc.pos
    print("decode_error_near:", repr(body_text[max(0, at - 120): at + 120]))
    raise

out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"items={len(payload)}")
print(f"out={out_path}")
