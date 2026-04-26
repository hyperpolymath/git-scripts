#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# DEPRECATED — replaced by standardize_readmes.sh (which uses pandoc properly).
#
# The original sed-based converter had several broken regexes (\\* escaping,
# group references). standardize_readmes.sh handles MD->AsciiDoc with pandoc
# and the correct boilerplate. Stub kept so the Elixir TUI's hardcoded
# reference (lib/script_manager/md_converter.ex) still resolves.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
echo "[deprecated] md_to_adoc_converter.sh -> standardize_readmes.sh" >&2
exec "${SCRIPT_DIR}/standardize_readmes.sh" "$@"
