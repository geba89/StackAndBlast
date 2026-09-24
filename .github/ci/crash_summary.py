#!/usr/bin/env python3
"""Print the useful part of an iOS crash report (.ips) in the CI log.

An .ips file is one line of JSON (a header) followed by a JSON body. The body says
how the app died ("exception"), often why in plain words ("asi" — e.g. the reason
of an uncaught exception), and where (the backtrace of the crashed thread).

Usage: crash_summary.py REPORT.ips
"""
import json
import sys


def main(path):
    header, _, body = open(path, encoding="utf-8", errors="replace").read().partition("\n")
    try:
        report = json.loads(body)
    except json.JSONDecodeError:
        print(body[:3000])  # older plain-text format: just show the start
        return

    print(f"--- Crash report {path}")
    print("Exception:", report.get("exception"))
    for library, messages in (report.get("asi") or {}).items():
        for message in messages:
            print(f"{library}: {message}")

    images = report.get("usedImages", [])
    crashed = next((t for t in report.get("threads", []) if t.get("triggered")), {})
    # For an uncaught exception, the backtrace of the throw is the interesting one
    frames = report.get("lastExceptionBacktrace") or crashed.get("frames", [])
    print("Backtrace:")
    for frame in frames[:30]:
        index = frame.get("imageIndex")
        image = images[index].get("name", "?") if index is not None and index < len(images) else "?"
        print(f"  {image:<32} {frame.get('symbol', hex(frame.get('imageOffset', 0)))}")


if __name__ == "__main__":
    main(sys.argv[1])
