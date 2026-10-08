"""Refresh rates.json from the free ExchangeRate-API open endpoint (no key needed).
Usage: python3 scripts/update_rates.py [url-or-file]   (default: the live endpoint)
Refuses to write anything that fails a sanity check, so a bad response never reaches the app."""
import datetime, json, sys, urllib.request

SRC = sys.argv[1] if len(sys.argv) > 1 else "https://open.er-api.com/v6/latest/USD"
BOUNDS = {"COP": (1000, 10000), "MXN": (5, 60)}  # plausible USD ranges; anything outside is treated as bad data

if SRC.startswith("http"):
    with urllib.request.urlopen(SRC, timeout=30) as r:
        data = json.load(r)
else:
    data = json.load(open(SRC))

if data.get("result") != "success" or data.get("base_code") != "USD":
    sys.exit("Unexpected response: " + json.dumps(data)[:200])
rates = {}
for code, (lo, hi) in BOUNDS.items():
    v = data["rates"].get(code)
    if not isinstance(v, (int, float)) or not lo <= v <= hi:
        sys.exit("Rate for %s looks wrong: %r" % (code, v))
    rates[code] = round(float(v), 6)

out = {"base": "USD", "updated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d"), "source": "ExchangeRate-API", "rates": rates}
with open("rates.json", "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print("rates.json updated:", out)
