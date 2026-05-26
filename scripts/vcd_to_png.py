#!/usr/bin/env python3
"""Render a VCD as a PNG digital-timing diagram via matplotlib.

Single-bit signals draw as low/high lines; multi-bit signals draw as bus
envelopes with hex value labels.

Usage:
    python3 vcd_to_png.py <input.vcd> <output.png> [t_max_ns]
"""
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

# (full_path, label, kind)  kind in {"scalar", "bus"}
SIGNALS = [
    ("top.clock", "clock", "scalar"),
    ("top.reset", "reset", "scalar"),
    ("top.bus.ALE", "ALE", "scalar"),
    ("top.bus.RD", "RD", "scalar"),
    ("top.bus.WR", "WR", "scalar"),
    ("top.bus.IOM", "IOM", "scalar"),
    ("top.bus.Address", "Address[19:0]", "bus"),
    ("top.bus.Data", "Data[7:0]", "bus"),
    ("top.M0_CS", "M0_CS", "scalar"),
    ("top.M1_CS", "M1_CS", "scalar"),
    ("top.IO0_CS", "IO0_CS", "scalar"),
    ("top.IO1_CS", "IO1_CS", "scalar"),
]


# ---------- VCD parsing ----------

VAR_RE = re.compile(r"^\$var\s+(\w+)\s+(\d+)\s+(\S+)\s+(\S+)(?:\s+(\[[^\]]+\]))?\s+\$end$")


def parse_vcd(path):
    """Return (scalars, buses, events).
       scalars: {full_path: vcd_id}
       buses:   {full_path: {"width": int, "bit_ids": {idx: vid}, "single_vid": vid or None}}
       events:  list of (t_ns, vcd_id, value_str)
    """
    text = Path(path).read_text(errors="replace")
    scalars = {}
    buses = {}
    scope_stack = []
    in_header = True
    events = []
    t = 0

    for line in text.splitlines():
        s = line.strip()
        if in_header:
            if s.startswith("$scope"):
                scope_stack.append(s.split()[2])
            elif s.startswith("$upscope"):
                if scope_stack:
                    scope_stack.pop()
            elif s.startswith("$var"):
                m = VAR_RE.match(s)
                if not m:
                    continue
                _vtype, width, vid, sym, range_suffix = m.groups()
                width = int(width)
                base = sym
                full = ".".join(scope_stack + [base])
                if width == 1 and range_suffix and ":" not in range_suffix:
                    # Bit-blasted entry: NAME [N]
                    bit_idx = int(range_suffix.strip("[]"))
                    bg = buses.setdefault(full, {"width": 0, "bit_ids": {}, "single_vid": None})
                    bg["bit_ids"][bit_idx] = vid
                    bg["width"] = max(bg["width"], bit_idx + 1)
                elif width > 1:
                    # Single multi-bit declaration: NAME [N:M]
                    bg = buses.setdefault(full, {"width": width, "bit_ids": {}, "single_vid": None})
                    bg["single_vid"] = vid
                    bg["width"] = max(bg["width"], width)
                else:
                    if full not in scalars:
                        scalars[full] = vid
            elif s == "$enddefinitions $end":
                in_header = False
            continue
        if not s:
            continue
        if s[0] == "#":
            try:
                t = int(s[1:])
            except ValueError:
                pass
        elif s[0] in "01xzXZ" and len(s) >= 2:
            events.append((t, s[1:], s[0]))
        elif s[0] in "bB":
            parts = s.split()
            if len(parts) == 2:
                events.append((t, parts[1], parts[0][1:]))  # strip 'b' prefix
    return scalars, buses, events


def scalar_transitions(vid, events):
    return sorted([(t, v) for t, eid, v in events if eid == vid])


def bus_transitions(bus_info, events):
    """Return [(t, value_string)] where value_string is a binary string
       (MSB first) of length 'width', possibly containing x/z/X/Z.
    """
    width = bus_info["width"]
    if bus_info["single_vid"]:
        vid = bus_info["single_vid"]
        out = []
        for t, eid, v in events:
            if eid == vid:
                # v already has 'b' prefix stripped; pad/truncate to width
                if all(c in "01xzXZ" for c in v):
                    vv = v.rjust(width, "0") if len(v) < width else v[-width:]
                else:
                    vv = v
                out.append((t, vv))
        out.sort()
        return out

    # Bit-blasted: walk events, track per-bit current value, emit combined on change
    bits = bus_info["bit_ids"]
    if not bits:
        return []
    cur = {i: "x" for i in range(width)}
    # Build a vid->bit_idx map
    vid_to_idx = {vid: i for i, vid in bits.items()}
    out = []
    last_combined = None
    for t, eid, v in events:
        if eid not in vid_to_idx:
            continue
        # If it's a 'b...' compound value, it's a stale multi-bit hit — should not happen for blasted bits
        if len(v) > 1:
            continue
        cur[vid_to_idx[eid]] = v
        combined = "".join(cur[i] if i in cur else "x" for i in range(width - 1, -1, -1))
        if combined != last_combined:
            out.append((t, combined))
            last_combined = combined
    return out


def binary_to_hex(b):
    """Convert a binary string (may contain x/z) to hex. Returns 'X' if any unknown bit."""
    if any(c in "xXzZ" for c in b):
        if all(c in "xX" for c in b):
            return "X"
        if all(c in "zZ" for c in b):
            return "Z"
        # Mixed — try to render nibbles where possible
        out = []
        for i in range(0, len(b), 4):
            chunk = b[i:i+4]
            if any(c in "xX" for c in chunk):
                out.append("x")
            elif any(c in "zZ" for c in chunk):
                out.append("z")
            else:
                out.append(format(int(chunk, 2), "x"))
        return "".join(out)
    return format(int(b, 2), "x")


# ---------- Rendering ----------

def render(vcd_path, png_path, t_max_ns):
    scalars, buses, events = parse_vcd(vcd_path)

    rows = []   # (label, kind, transitions)
    missing = []
    for full, label, kind in SIGNALS:
        if kind == "scalar" and full in scalars:
            rows.append((label, kind, scalar_transitions(scalars[full], events)))
        elif kind == "scalar" and full in buses:
            # Questa dumps `bit` as 32-bit registers — render as scalar (LSB).
            tr = bus_transitions(buses[full], events)
            tr = [(t, v[-1]) for t, v in tr]  # take LSB
            rows.append((label, kind, tr))
        elif kind == "bus" and full in buses:
            rows.append((label, kind, bus_transitions(buses[full], events)))
        else:
            missing.append(full)

    if not rows:
        print(f"No signals matched in {vcd_path}", file=sys.stderr)
        sys.exit(1)

    n = len(rows)
    fig_height = max(4.0, 0.7 * n + 1.5)
    fig, ax = plt.subplots(figsize=(16, fig_height))
    ax.set_xlim(0, t_max_ns)
    ax.set_ylim(-0.5, n - 0.5)
    ax.set_yticks([n - 1 - i for i in range(n)])
    ax.set_yticklabels([r[0] for r in rows], fontsize=9, family="monospace")
    ax.set_xlabel("time (ns)")
    title = Path(vcd_path).name
    if missing:
        title += f"   (missing: {', '.join(missing)})"
    title += f"   |   window: 0 - {t_max_ns} ns"
    ax.set_title(title, fontsize=10, family="monospace")
    ax.grid(axis="x", linestyle=":", alpha=0.4)
    ax.tick_params(axis="x", labelsize=8)

    HI = 0.38
    LO = -0.38
    SCALAR_COLOR = "#1f77b4"
    BUS_FILL = "#d6e8ff"
    BUS_EDGE = "#1f77b4"
    X_FILL = "#ffd966"
    Z_COLOR = "#888"

    for raw_idx, (label, kind, transitions) in enumerate(rows):
        row_idx = n - 1 - raw_idx
        # Reduce transitions to segments [(t0, t1, value)]
        segs = []
        last_v = "x" if kind == "scalar" else "x" * 32
        last_t = 0
        for t, v in transitions:
            if t > last_t:
                segs.append((last_t, t, last_v))
            last_v = v
            last_t = t
        segs.append((last_t, t_max_ns, last_v))

        if kind == "scalar":
            for t0, t1, v in segs:
                if t1 <= 0 or t0 >= t_max_ns:
                    continue
                t0 = max(t0, 0); t1 = min(t1, t_max_ns)
                nv = v[-1] if len(v) > 1 else v
                if nv == "0":
                    y = row_idx + LO
                    ax.plot([t0, t1], [y, y], color=SCALAR_COLOR, linewidth=1.7)
                elif nv == "1":
                    y = row_idx + HI
                    ax.plot([t0, t1], [y, y], color=SCALAR_COLOR, linewidth=1.7)
                elif nv in ("x", "X"):
                    ax.add_patch(Rectangle((t0, row_idx + LO), t1 - t0, HI - LO,
                                           facecolor=X_FILL, edgecolor="none", alpha=0.8))
                elif nv in ("z", "Z"):
                    ax.plot([t0, t1], [row_idx, row_idx], color=Z_COLOR, linewidth=1.2, linestyle="--")
            # transition edges
            prev_v = None
            for t, v in transitions:
                if 0 < t <= t_max_ns:
                    ax.plot([t, t], [row_idx + LO, row_idx + HI],
                            color=SCALAR_COLOR, linewidth=0.7, alpha=0.6)
        else:
            # Bus rendering
            for t0, t1, v in segs:
                if t1 <= 0 or t0 >= t_max_ns:
                    continue
                t0 = max(t0, 0); t1 = min(t1, t_max_ns)
                # Color/value
                if all(c in "xX" for c in v):
                    ax.add_patch(Rectangle((t0, row_idx + LO), t1 - t0, HI - LO,
                                           facecolor=X_FILL, edgecolor="none", alpha=0.8))
                    label_text = "X"
                elif all(c in "zZ" for c in v):
                    ax.plot([t0, t1], [row_idx, row_idx], color=Z_COLOR, linewidth=1.5, linestyle="--")
                    label_text = "Z"
                else:
                    ax.add_patch(Rectangle((t0, row_idx + LO), t1 - t0, HI - LO,
                                           facecolor=BUS_FILL, edgecolor=BUS_EDGE, linewidth=0.7))
                    label_text = "0x" + binary_to_hex(v)
                # Draw value text if segment is wide enough
                width_ns = t1 - t0
                if width_ns >= max(150, t_max_ns / 80):
                    ax.text((t0 + t1) / 2, row_idx, label_text,
                            ha="center", va="center", fontsize=7,
                            family="monospace", color="#1a3a6e")

    # Microsecond gridlines (heavy)
    for us in range(0, t_max_ns // 1000 + 1):
        ax.axvline(us * 1000, color="#999", linewidth=0.5, alpha=0.6)

    plt.tight_layout()
    plt.savefig(png_path, dpi=140)
    print(f"Wrote {png_path} ({Path(png_path).stat().st_size} bytes)")


if __name__ == "__main__":
    vcd = sys.argv[1]
    png = sys.argv[2]
    t_max = int(sys.argv[3]) if len(sys.argv) > 3 else 7000
    render(vcd, png, t_max)
