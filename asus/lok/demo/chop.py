import sys, re
w = int(sys.argv[1]); esc = re.compile(r"\x1b\[[0-9;]*m")
for line in sys.stdin.read().split("\n"):
    out, n, i = [], 0, 0
    while i < len(line) and n < w:
        m = esc.match(line, i)
        if m: out.append(m.group()); i = m.end(); continue
        out.append(line[i]); n += 1; i += 1
    print("".join(out) + "\x1b[0m")
