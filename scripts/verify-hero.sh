#!/usr/bin/env bash
#
# End-to-end proof that the risk engine works against a real database over
# HTTP: request an OTP, exchange it for a JWT, and read the demo work's full
# risk breakdown back.
#
#   ./scripts/verify-hero.sh                        # the deployed service
#   BASE=http://localhost:8000 ./scripts/verify-hero.sh   # a local server
#
# The reason points printed at the end must add up to the score exactly. That
# is the explainability contract: the arithmetic is checkable, not asserted.
#
# Needs only curl and python3.
set -euo pipefail
BASE="${BASE:-https://mplad-satya-hi8x.onrender.com}"
# A fresh number each run, so the 30-second OTP resend limit never blocks you.
PHONE="+9198765${RANDOM:0:5}"

echo "server: $BASE"
echo "phone : $PHONE"

REQ=$(curl -s -X POST "$BASE/api/v1/auth/otp/request" \
  -H 'Content-Type: application/json' -d "{\"phone\":\"$PHONE\"}")

RID=$(printf '%s' "$REQ" | python3 -c '
import sys, json
d = json.load(sys.stdin)
if "error" in d:
    sys.exit("request failed: " + d["error"]["message"])
print(d["request_id"])')

OTP=$(printf '%s' "$REQ" | python3 -c '
import sys, json
print(json.load(sys.stdin)["debug_code"])')
echo "otp   : $OTP   (returned in the response - no SMS gateway configured)"

TOKEN=$(curl -s -X POST "$BASE/api/v1/auth/otp/verify" \
  -H 'Content-Type: application/json' \
  -d "{\"request_id\":\"$RID\",\"phone\":\"$PHONE\",\"otp\":\"$OTP\"}" \
  | python3 -c '
import sys, json
d = json.load(sys.stdin)
if "error" in d:
    sys.exit("verify failed: " + d["error"]["message"])
print(d["access_token"])')

curl -s "$BASE/api/v1/works/MP%2F2026%2F1142/risk" \
  -H "Authorization: Bearer $TOKEN" > /tmp/risk.json

python3 - /tmp/risk.json <<'PY'
import sys, json
d = json.load(open(sys.argv[1]))
if "error" in d:
    sys.exit("risk failed: " + d["error"]["message"])
print()
print('SCORE  = %s   band=%s (%s)' % (d['score'], d['band'], d['band_label']))
print('action = %s' % d['action_label'])
print()
t = 0
for x in d['reasons']:
    print('  %3d  %-32s[%s]' % (x['points'], x['code'], x['category']))
    t += x['points']
print('  ---')
print('  %3d  TOTAL      sums to score: %s' % (t, t == d['score']))
print()
print('engine   %s' % d['engine_version'])
print('rulebook %s' % d['rules_sha256'][:16])
PY
