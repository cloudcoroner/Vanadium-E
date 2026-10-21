#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Estimates how much of each blocklist Cloudflare's malware-blocking resolver already blocks.

For a random sample of domains from each list it asks security.cloudflare-dns.com (the filtered resolver) and
cloudflare-dns.com (unfiltered) over DNS-over-HTTPS. A domain counts as blocked when the filtered resolver answers
0.0.0.0 while the unfiltered one does not. Only DNS lookups are made; no site is ever contacted.

RUN THIS ON A NETWORK WHERE DNS-OVER-HTTPS AND LOOKUPS OF MALWARE DOMAINS ARE ALLOWED (not a managed work network):
corporate filters often block DoH and may flag lookups of known-bad domains.

Usage: measure-dns-overlap.py [--sample 300] [--lists ads,tracking,...] [--threads 6] [--seed 1]
"""
import argparse, json, math, random, re, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

BLP = "https://blocklistproject.github.io/Lists/{}.txt"
LISTS = ["ads", "basic", "redirect", "scam", "tracking", "abuse", "fraud", "malware", "phishing", "ransomware", "crypto"]
FILTERED, UNFILTERED = "security.cloudflare-dns.com", "cloudflare-dns.com"
UA = "Mozilla/5.0 (vanadium-e dns overlap check)"


def parse_domains(text):
    """Domains from a hosts-format ('0.0.0.0 example.com') or one-domain-per-line list."""
    out = set()
    for line in text.splitlines():
        line = line.split('#', 1)[0].strip().lower()
        if not line:
            continue
        parts = line.split()
        d = parts[1] if len(parts) >= 2 and re.fullmatch(r'[0-9.]+|::1?', parts[0]) else parts[0]
        if re.fullmatch(r'[a-z0-9._-]+\.[a-z0-9-]{2,}', d) and not re.fullmatch(r'[0-9.]+', d):
            out.add(d)
    return sorted(out)


def classify(filtered, unfiltered):
    """filtered/unfiltered: parsed DoH JSON dicts. Returns one of blocked / resolves / dead / unknown."""
    def answers(r): return [a.get('data') for a in r.get('Answer', []) if a.get('type') == 1]
    f, u = answers(filtered), answers(unfiltered)
    if '0.0.0.0' in f and '0.0.0.0' not in u:
        return 'blocked'
    if unfiltered.get('Status') == 3 and filtered.get('Status') == 3:
        return 'dead'
    if f or u:
        return 'resolves'
    return 'unknown'


def doh(host, name, tries=4):
    url = f"https://{host}/dns-query?name={name}&type=A"
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"accept": "application/dns-json", "User-Agent": UA})
            return json.load(urllib.request.urlopen(req, timeout=15))
        except urllib.error.HTTPError as e:
            if e.code == 403:
                sys.exit(f"HTTP 403 from {host}: this network blocks DNS-over-HTTPS. Run the script from a different network.")
            time.sleep(1.5 * (i + 1))
        except Exception:
            time.sleep(1.5 * (i + 1))
    return {}


def check(name):
    return classify(doh(FILTERED, name), doh(UNFILTERED, name))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--sample', type=int, default=300)
    ap.add_argument('--lists', default=','.join(LISTS))
    ap.add_argument('--threads', type=int, default=6)
    ap.add_argument('--seed', type=int, default=1)
    a = ap.parse_args()
    rnd = random.Random(a.seed)
    print(f"{'list':12} {'domains':>9} {'sampled':>8} {'blocked':>8} {'% blocked':>10} {'(95% +/-)':>10} {'dead':>6}")
    for name in a.lists.split(','):
        try:
            text = urllib.request.urlopen(urllib.request.Request(BLP.format(name), headers={"User-Agent": UA}), timeout=120).read().decode('utf-8', 'replace')
        except Exception as e:
            print(f"{name:12} download failed: {e}")
            continue
        doms = parse_domains(text)
        sample = rnd.sample(doms, min(a.sample, len(doms)))
        with ThreadPoolExecutor(a.threads) as ex:
            results = list(ex.map(check, sample))
        n = len(results)
        blocked, dead = results.count('blocked'), results.count('dead')
        p = blocked / n if n else 0
        moe = 1.96 * math.sqrt(p * (1 - p) / n) if n else 0
        print(f"{name:12} {len(doms):>9,} {n:>8} {blocked:>8} {p:>9.1%} {moe:>9.1%} {dead:>6}")


if __name__ == '__main__':
    main()
