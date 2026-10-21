#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Counts the flatbuffers "tables" in an indexed subresource-filter ruleset, the way Chromium's verifier does.

Chromium refuses to load an indexed ruleset (so nothing is blocked) when flatbuffers' Verifier visits more than
1,000,000 tables (its default max_tables). The index is a hash table whose EVERY slot, empty or not, is verified as
a table, plus one table per rule, so big lists can exceed the limit even if they index fine.

Usage: count-ruleset-tables.py <ruleset.indexed> [...]     (files made by subresource_indexing_tool)
Exit status 1 if any file is over the limit.
"""
import struct, sys

LIMIT = 1_000_000


class Walker:
    def __init__(self, buf):
        self.b = buf
        self.tables = 0

    def u16(self, p): return struct.unpack_from('<H', self.b, p)[0]
    def u32(self, p): return struct.unpack_from('<I', self.b, p)[0]
    def i32(self, p): return struct.unpack_from('<i', self.b, p)[0]

    def field(self, table, slot):
        """Position of a field inside a table, or None when absent (default value)."""
        vt = table - self.i32(table)
        vsize = self.u16(vt)
        off = 4 + 2 * slot
        if off >= vsize:
            return None
        rel = self.u16(vt + off)
        return table + rel if rel else None

    def table_field(self, table, slot):
        p = self.field(table, slot)
        return None if p is None else p + self.u32(p)

    def vector_field(self, table, slot):
        """(start of elements, length) of a vector field, or (0, 0) when absent."""
        p = self.field(table, slot)
        if p is None:
            return 0, 0
        v = p + self.u32(p)
        return v + 4, self.u32(v)

    def elem_tables(self, start, n):
        for i in range(n):
            e = start + 4 * i
            yield e + self.u32(e)

    def url_pattern_index(self, t, stats, name):
        self.tables += 1                                         # the UrlPatternIndex itself
        start, slots = self.vector_field(t, 1)                  # ngram_index (hash table slots)
        empty = self.table_field(t, 2)                           # ngram_index_empty_slot
        rules = occupied = 0
        for slot in self.elem_tables(start, slots):
            self.tables += 1                                     # every slot is verified, empty ones too
            if slot != empty:
                occupied += 1
                rstart, rn = self.vector_field(slot, 1)          # NGramToRules.rule_list
                self.tables += rn                                # one UrlRule table per rule
                rules += rn
        if empty is not None:
            self.tables += 1                                     # the shared empty-slot table, verified once
        _, fallback = self.vector_field(t, 3)                    # fallback_rules
        self.tables += fallback
        stats[name] = dict(slots=slots, occupied=occupied, rules=rules, fallback=fallback)

    def run(self):
        root = self.u32(0)
        stats = {}
        self.tables += 1                                         # IndexedRuleset
        for slot, name in ((0, 'blocklist'), (1, 'allowlist'), (2, 'deactivation')):
            t = self.table_field(root, slot)
            if t is not None:
                self.url_pattern_index(t, stats, name)
        style = self.table_field(root, 3)                        # StyleRuleIndex
        if style is not None:
            self.tables += 1
            for slot in (1, 2, 3, 4):                            # domain/exclusion/class/id maps of NameToSelectors
                _, n = self.vector_field(style, slot)
                self.tables += n
        return stats


def main(paths):
    worst = 0
    for path in paths:
        with open(path, 'rb') as f:
            buf = f.read()
        w = Walker(buf)
        try:
            stats = w.run()
        except (struct.error, IndexError, RecursionError) as e:
            print(f"{path}: could not parse as an indexed ruleset ({e})")
            worst = 2
            continue
        bl = stats.get('blocklist', {})
        verdict = 'OVER THE LIMIT: the browser will reject this ruleset' if w.tables > LIMIT else 'ok'
        print(f"{path}")
        print(f"   hash table slots {bl.get('slots', 0):>10,}   occupied {bl.get('occupied', 0):>9,}   "
              f"rules {bl.get('rules', 0) + bl.get('fallback', 0):>9,}")
        print(f"   tables verified  {w.tables:>10,}   limit {LIMIT:,}   ({w.tables / LIMIT:.0%})   {verdict}")
        worst = max(worst, 1 if w.tables > LIMIT else 0)
    return worst


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
