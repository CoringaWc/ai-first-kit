#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTK="$ROOT/vendor/python-tk"

export PYTHONPATH="$PYTK/usr/lib/python3.12:$PYTK/usr/lib/python3.12/lib-dynload${PYTHONPATH:+:$PYTHONPATH}"
export LD_LIBRARY_PATH="$PYTK/usr/lib:$PYTK/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export TCL_LIBRARY="$PYTK/usr/share/tcltk/tcl8.6"
export TK_LIBRARY="$PYTK/usr/share/tcltk/tk8.6"

exec python3 "$ROOT/ecc_dashboard.py" "$@"
