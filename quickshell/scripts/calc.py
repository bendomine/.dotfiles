#!/usr/bin/env python3
"""Calculator backend for quickshell/status/CalculatorPopup.qml.

Long-running: reads one JSON request per line on stdin,
    {"id": 7, "expr": "5 ft to m", "color": "#e0e0e0"}
and answers each with one JSON line on stdout,
    {"id": 7, "result": "1.524 m", "error": "", "warnings": [],
     "latex": "5\\,\\mathrm{ft} = 1.524\\,\\mathrm{m}", "image": "/run/user/…/preview-7.png", "scale": 2}

- result/error/warnings: `qalc -t` (the user's qalc settings apply) plus the
  "error:"/"warning:" lines of a second `qalc -latex` run; both are limited to
  QALC_TIME_MS (qalc -m) and killed after PROC_TIMEOUT.
- latex: qalc's own LaTeX ("expression = result"), with its siunitx macros
  (\\qty, \\num, \\unit, \\per, …) rewritten into plain math for matplotlib's
  mathtext. "" when qalc gave none.
- image: that LaTeX rendered by mathtext (no TeX install needed) as a PNG with a
  transparent background in `color`, at `scale` × screen pixels; "" when
  matplotlib is missing or mathtext can't parse it. Files live in
  $XDG_RUNTIME_DIR/quickshell-calc; older previews are deleted.

Requests that arrive while one is being processed supersede it: only the newest
pending request is answered (a skipped request gets no reply). Exits on EOF
after answering the last request, so it also works as a one-shot:
    echo '{"id":1,"expr":"2^10+sqrt(16)"}' | python3 calc.py
"""

import io
import json
import os
import re
import subprocess
import sys
import tempfile
import threading

QALC_TIME_MS = 1500
PROC_TIMEOUT = 3.0
# Preview pixels per screen pixel: above any monitor scale (1.5 here), so the
# popup only ever downsamples (mipmapped) and edges stay sharp.
SCALE = 4
FONT_PT = 16 * 72 / 96  # ≈ 16 px glyphs at SCALE 1
KEEP_PREVIEWS = 2

PREVIEW_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir(), "quickshell-calc")


# ── qalc ─────────────────────────────────────────────────────────────────────

def run_qalc(args, expr):
    """(returncode, stdout) of qalc; (None, "") on timeout or when qalc is missing."""
    try:
        proc = subprocess.run(
            ["qalc", "-m", str(QALC_TIME_MS), *args, "--", expr],
            stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=PROC_TIMEOUT,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None, ""
    return proc.returncode, proc.stdout


def evaluate(expr):
    """{"result", "error", "warnings", "latex"} for `expr`."""
    # Run the terse (result) and LaTeX (messages + preview) passes concurrently.
    latex_out = {}
    latex_thread = threading.Thread(target=lambda: latex_out.update(zip(("rc", "out"), run_qalc(["-latex"], expr))))
    latex_thread.start()
    rc, out = run_qalc(["-t"], expr)
    latex_thread.join()

    errors, warnings, latex_lines = [], [], []
    for line in latex_out.get("out", "").splitlines():
        if line.startswith("error: "):
            errors.append(line[len("error: "):].strip())
        elif line.startswith("warning: "):
            warnings.append(line[len("warning: "):].strip())
        elif line.strip():
            latex_lines.append(line.strip())

    result = out.strip()
    if rc is None:
        error = "Timed out"
    elif rc != 0 or errors:
        error = errors[0] if errors else "Invalid expression"
    else:
        error = ""
    latex = ""
    if not error and latex_lines:
        latex = to_mathtext(" ".join(latex_lines))
    return {"result": result if not error else "", "error": error, "warnings": warnings, "latex": latex}


# ── qalc LaTeX → mathtext ────────────────────────────────────────────────────

# siunitx unit macros whose symbol is not just the macro name (\km → km is).
UNIT_NAMES = {
    "metre": "m", "meter": "m", "gram": "g", "second": "s", "minute": "min", "hour": "h",
    "day": "d", "ampere": "A", "kelvin": "K", "mole": "mol", "candela": "cd",
    "radian": "rad", "steradian": "sr", "hertz": "Hz", "newton": "N", "pascal": "Pa",
    "joule": "J", "watt": "W", "coulomb": "C", "volt": "V", "farad": "F", "ohm": r"\Omega",
    "siemens": "S", "weber": "Wb", "tesla": "T", "henry": "H", "lumen": "lm", "lux": "lx",
    "becquerel": "Bq", "gray": "Gy", "sievert": "Sv", "katal": "kat", "litre": "L",
    "liter": "L", "tonne": "t", "electronvolt": "eV", "bel": "B", "decibel": "dB",
    "neper": "Np", "degree": r"^{\circ}", "arcminute": "'", "arcsecond": "''",
    "degreeCelsius": r"^{\circ}\mathrm{C}", "percent": r"\%", "bit": "bit", "byte": "B",
    "astronomicalunit": "au", "dalton": "Da", "hectare": "ha",
}

UNIT_PREFIXES = {
    "quecto": "q", "ronto": "r", "yocto": "y", "zepto": "z", "atto": "a", "femto": "f",
    "pico": "p", "nano": "n", "micro": r"\mu ", "milli": "m", "centi": "c", "deci": "d",
    "deca": "da", "deka": "da", "hecto": "h", "kilo": "k", "mega": "M", "giga": "G",
    "tera": "T", "peta": "P", "exa": "E", "zetta": "Z", "yotta": "Y", "ronna": "R",
    "quetta": "Q", "kibi": "Ki", "mebi": "Mi", "gibi": "Gi", "tebi": "Ti", "pebi": "Pi",
    "exbi": "Ei", "zebi": "Zi", "yobi": "Yi",
}

POWERS = {"squared": "2", "cubed": "3"}


def take_group(s, i, open_ch, close_ch):
    """If s[i] opens a group, return (inner, index after it); else (None, i)."""
    if i >= len(s) or s[i] != open_ch:
        return None, i
    depth = 0
    for j in range(i, len(s)):
        if s[j] == open_ch:
            depth += 1
        elif s[j] == close_ch:
            depth -= 1
            if depth == 0:
                return s[i + 1:j], j + 1
    return s[i + 1:], len(s)


def number(text):
    text = text.strip()
    m = re.fullmatch(r"([-+]?[0-9.]+)[eE]([-+]?[0-9]+)", text)
    if m:
        mantissa, exponent = m.group(1), int(m.group(2))
        return (mantissa + r"\times " if mantissa not in ("1", "1.0") else "") + "10^{%d}" % exponent
    return to_mathtext(text)


def roman(symbol):
    """Upright plain symbols; mathtext pieces (\\Omega, ^{\\circ}…) stay as they are."""
    return symbol if not symbol or "\\" in symbol or "^" in symbol else r"\mathrm{%s}" % symbol


def unit(text):
    """siunitx unit argument (\\km\\per\\second\\squared, deg.\\C, \\gibi B) → mathtext."""
    num, den = [], []
    prefix, per, last = "", False, None
    for macro, word, dot in re.findall(r"\\([A-Za-z]+)|([^\\\s.]+)|(\.)", text):
        if dot:
            continue
        if macro == "per":  # applies to the next unit only
            per = True
        elif macro in POWERS:
            if last:
                last[-1] += "^{%s}" % POWERS[macro]
        elif macro in UNIT_PREFIXES:
            prefix += UNIT_PREFIXES[macro]
        else:
            symbol = UNIT_NAMES.get(macro, macro) if macro else word
            last = den if per else num
            last.append(roman(prefix) + roman(symbol))
            prefix, per = "", False
    out = r"\,".join(num) or "1"
    if den:
        out += "/" + r"\,".join(den)
    return out


def to_mathtext(latex):
    """qalc -latex output (one formula) → a mathtext-compatible formula body."""
    s = latex.strip()
    if s.startswith("$") and s.endswith("$"):
        s = s[1:-1]
    s = s.replace(r"\displaystyle", "").replace(r"\lvert", "|").replace(r"\rvert", "|")
    s = re.sub(r"\\begin\{([bp]?)matrix\}(.*?)\\end\{[bp]?matrix\}",
               lambda m: (r"\left[" if m.group(1) == "b" else r"\left(" if m.group(1) == "p" else "")
               + r"\,;\, ".join(r",\, ".join(c.strip() for c in row.split("&")) for row in m.group(2).split(r"\\"))
               + (r"\right]" if m.group(1) == "b" else r"\right)" if m.group(1) == "p" else ""),
               s, flags=re.S)
    out, i = [], 0
    macro = re.compile(r"\\(qty|num|unit|SI|si)(?![A-Za-z])")
    while True:
        m = macro.search(s, i)
        if not m:
            out.append(s[i:])
            break
        out.append(s[i:m.start()])
        j = m.end()
        _, j = take_group(s, j, "[", "]")  # options
        a, j = take_group(s, j, "{", "}")
        b = None
        if m.group(1) in ("qty", "SI"):
            b, j = take_group(s, j, "{", "}")
        if a is None:
            out.append(m.group(0))
        elif m.group(1) == "num":
            out.append(number(a))
        elif m.group(1) in ("unit", "si"):
            out.append(unit(a))
        else:
            out.append(number(a) + r"\," + unit(b or ""))
        i = j
    return "".join(out).strip()


# ── Rendering ────────────────────────────────────────────────────────────────

class Renderer:
    """matplotlib mathtext, imported (and warmed up) in the background at startup."""

    def __init__(self):
        self.ready = threading.Event()
        self.mathtext = None
        threading.Thread(target=self._load, daemon=True).start()

    def _load(self):
        try:
            import matplotlib
            matplotlib.use("Agg")
            from matplotlib import mathtext, rcParams
            from matplotlib.font_manager import FontProperties
            rcParams["mathtext.fontset"] = "cm"
            rcParams["savefig.transparent"] = True
            self.mathtext, self.font = mathtext, FontProperties(size=FONT_PT)
            os.makedirs(PREVIEW_DIR, exist_ok=True)
            self._render("x^{2}", io.BytesIO(), "#000000")
        except Exception:  # no matplotlib: previews are simply absent
            self.mathtext = None
        finally:
            self.ready.set()

    def _render(self, formula, path, color):
        self.mathtext.math_to_image("$" + formula + "$", path, prop=self.font, dpi=96 * SCALE, format="png", color=color)

    def render(self, req_id, formula, color):
        """Path of the PNG for `formula`, or "" if it can't be rendered."""
        self.ready.wait()
        if self.mathtext is None or not formula:
            return ""
        path = os.path.join(PREVIEW_DIR, "preview-%d.png" % req_id)
        try:
            self._render(formula, path, color)
        except Exception:  # mathtext doesn't support every construct
            return ""
        self._prune(path)
        return path

    @staticmethod
    def _prune(keep):
        try:
            files = [os.path.join(PREVIEW_DIR, f) for f in os.listdir(PREVIEW_DIR) if f.startswith("preview-")]
            files.sort(key=lambda f: os.stat(f).st_mtime, reverse=True)
            for f in files[KEEP_PREVIEWS:]:
                if f != keep:
                    os.remove(f)
        except OSError:
            pass


# ── Main loop ────────────────────────────────────────────────────────────────

class Inbox:
    """Holds only the newest unprocessed request."""

    def __init__(self):
        self.cond = threading.Condition()
        self.latest = None
        self.closed = False

    def put(self, req):
        with self.cond:
            self.latest = req
            self.cond.notify()

    def close(self):
        with self.cond:
            self.closed = True
            self.cond.notify()

    def get(self):
        """Next request, or None once stdin is closed and nothing is pending."""
        with self.cond:
            while self.latest is None and not self.closed:
                self.cond.wait()
            req, self.latest = self.latest, None
            return req

    def superseded(self):
        with self.cond:
            return self.latest is not None


def read_requests(inbox):
    for line in sys.stdin:
        try:
            req = json.loads(line)
            req_id = int(req["id"])
            expr = str(req.get("expr", ""))
            color = str(req.get("color") or "#000000")
        except (ValueError, KeyError, TypeError):
            continue
        inbox.put((req_id, expr, color))
    inbox.close()


def main():
    renderer = Renderer()
    inbox = Inbox()
    threading.Thread(target=read_requests, args=(inbox,), daemon=True).start()
    while (req := inbox.get()) is not None:
        req_id, expr, color = req
        reply = {"id": req_id, "result": "", "error": "", "warnings": [], "latex": "", "image": "", "scale": SCALE}
        if expr.strip():
            reply.update(evaluate(expr))
            if inbox.superseded():
                continue
            reply["image"] = renderer.render(req_id, reply["latex"], color)
            if inbox.superseded():
                continue
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
