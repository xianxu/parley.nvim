#!/usr/bin/env python3
"""Cut a raw asciinema recording into a captioned demo.

The raw cast plays fast; around each caption it drops to real time for long
enough to read the caption. Caption times are the ones stamped in viewer.html,
which plays the raw cast with its recorded idle_time_limit applied.

    demo/cut.py demo.cast captions.txt -o demo-cut.cast

captions.txt holds one caption per line: `~m:ss.s  text`.
The output is an asciicast v3 file. Each caption becomes a marker, and the
header carries `captions: [{start, end, text}]` in output time for the viewer.
"""
import argparse
import json
import re


def read_cast(path):
    with open(path) as f:
        lines = [l for l in f.read().splitlines() if l.strip()]
    header = json.loads(lines[0])
    if header.get("version") != 3:
        raise SystemExit(f"{path}: expected asciicast v3")
    return header, [json.loads(l) for l in lines[1:]]


def read_captions(path):
    caps = []
    for n, line in enumerate(open(path), 1):
        line = line.strip()
        if not line:
            continue
        m = re.match(r"~?(\d+):(\d+(?:\.\d+)?)\s+(.+)", line)
        if not m:
            raise SystemExit(f"{path}:{n}: expected `~m:ss.s  text`, got {line!r}")
        caps.append((int(m[1]) * 60 + float(m[2]), m[3].strip()))
    return sorted(caps)


def plan_windows(caps, a):
    """Real-time windows in view time. An overlapping caption starts when the previous one ends."""
    windows, prev_end = [], 0.0
    for t, text in caps:
        hold = max(a.min_hold, len(text.split()) / a.wps + a.beat)
        start = max(t - a.lead, prev_end, 0.0)
        windows.append((start, start + hold, text))
        prev_end = start + hold
    return windows


def build_segments(times, windows, a):
    """Piecewise-constant rates (output seconds per view second) covering the view timeline."""
    bounds = [b for s, e, _ in windows for b in (s, e)]
    inside = lambda x: any(s <= x < e for s, e, _ in windows)
    segs, prev = [], 0.0
    for t in times:
        cuts = sorted({prev, t, *[b for b in bounds if prev < b < t]})
        pieces = [(p, q, inside((p + q) / 2)) for p, q in zip(cuts, cuts[1:])]
        # Idle beyond `idle` seconds within one gap is dropped before speeding up.
        fast = sum(q - p for p, q, slow in pieces if not slow)
        squeeze = min(1.0, a.idle / fast) if fast > 0 else 1.0
        for p, q, slow in pieces:
            segs.append((p, q, 1.0 if slow else squeeze / a.speed))
        prev = t
    return segs


def warp(segs, x):
    out = 0.0
    for p, q, rate in segs:
        if x <= p:
            break
        out += (min(x, q) - p) * rate
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cast")
    ap.add_argument("captions")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--speed", type=float, default=5.0, help="playback speed between captions")
    ap.add_argument("--idle", type=float, default=1.0, help="max idle seconds per gap before speeding up")
    ap.add_argument("--lead", type=float, default=1.0, help="start real time this long before a stamp")
    ap.add_argument("--min-hold", type=float, default=4.0, help="minimum real-time seconds per caption")
    ap.add_argument("--wps", type=float, default=3.5, help="caption reading speed, words per second")
    ap.add_argument("--beat", type=float, default=1.0, help="extra seconds added to reading time")
    a = ap.parse_args()

    header, events = read_cast(a.cast)
    cap = header.pop("idle_time_limit", None)
    times, t = [], 0.0
    for gap, *_ in events:
        t += min(gap, cap) if cap else gap
        times.append(t)

    caps = read_captions(a.captions)
    for ct, text in caps:
        if ct > times[-1]:
            raise SystemExit(f"caption at {ct:.1f}s is past the end of the recording ({times[-1]:.1f}s): {text}")
    windows = plan_windows(caps, a)
    segs = build_segments(times, windows, a)

    header["captions"] = [
        {"start": round(warp(segs, s), 3), "end": round(warp(segs, e), 3), "text": text}
        for s, e, text in windows
    ]
    stream = [(warp(segs, t), 0, [kind, data]) for t, (_, kind, data) in zip(times, events)]
    # Markers sort before output at the same instant.
    stream += [(c["start"], -1, ["m", c["text"]]) for c in header["captions"]]
    stream.sort(key=lambda s: (s[0], s[1]))

    with open(a.out, "w") as f:
        f.write(json.dumps(header, ensure_ascii=False) + "\n")
        last = 0.0
        for out_t, _, (kind, data) in stream:
            f.write(json.dumps([round(out_t - last, 6), kind, data], ensure_ascii=False) + "\n")
            last = out_t

    total = warp(segs, times[-1])
    print(f"{a.out}: {total:.1f}s (view {times[-1]:.1f}s), {len(windows)} captions")
    for c in header["captions"]:
        print(f"  {c['start']:6.1f}-{c['end']:6.1f}  {c['text']}")


if __name__ == "__main__":
    main()
