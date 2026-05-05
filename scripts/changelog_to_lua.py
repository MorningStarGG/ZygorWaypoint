#!/usr/bin/env python3
"""
Convert the recent version entries from CHANGELOG.md into docs/changelog_data.lua format.

Expected markdown shape for modern entries:

## 2.6

- **Section title**
  - Entry line
  - Entry line

Usage examples:
    python scripts/changelog_to_lua.py --count 3
    python scripts/changelog_to_lua.py --count 5 --output docs/changelog_data.lua
    python scripts/changelog_to_lua.py --count 2 --stdout
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


VERSION_HEADING_RE = re.compile(r"^##\s+(.+?)\s*$")
SECTION_RE = re.compile(r"^-\s+\*\*(.+?)\*\*\s*:?\s*$")
ENTRY_RE = re.compile(r"^\s*-\s+(.+?)\s*$")

DEFAULT_INPUT = Path("CHANGELOG.md")
DEFAULT_OUTPUT = Path("docs/changelog_data.lua")


@dataclass
class Entry:
    text: str
    level: int = 1


@dataclass
class Section:
    title: str
    entries: list[Entry] = field(default_factory=list)


@dataclass
class VersionEntry:
    version: str
    sections: list[Section] = field(default_factory=list)


def normalize_text(text: str) -> str:
    replacements = {
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2013": "-",
        "\u2014": "-",
        "\u2026": "...",
        "\u00a0": " ",
        "â€™": "'",
        "â€˜": "'",
        "â€œ": '"',
        "â€": '"',
        "â€“": "-",
        "â€”": "-",
        "â€¦": "...",
        "â†’": "->",
    }

    for source, target in replacements.items():
        text = text.replace(source, target)

    return " ".join(text.strip().split())


def escape_lua_string(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"')


def entry_level(line: str) -> int:
    indent = 0
    for char in line:
        if char == " ":
            indent += 1
        elif char == "\t":
            indent += 4
        else:
            break

    return max(1, indent // 2)


def parse_changelog(markdown: str) -> list[VersionEntry]:
    entries: list[VersionEntry] = []
    current_version: VersionEntry | None = None
    current_section: Section | None = None

    for raw_line in markdown.splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()

        if not stripped:
            continue

        version_match = VERSION_HEADING_RE.match(stripped)
        if version_match:
            version_name = normalize_text(version_match.group(1))

            # Stop once the file leaves the modern "## version" area.
            if version_name.lower() == "legacy":
                break

            current_version = VersionEntry(version=version_name)
            entries.append(current_version)
            current_section = None
            continue

        if current_version is None:
            continue

        section_match = SECTION_RE.match(line)
        if section_match:
            current_section = Section(title=normalize_text(section_match.group(1)))
            current_version.sections.append(current_section)
            continue

        entry_match = ENTRY_RE.match(line)
        if entry_match and current_section is not None:
            entry_text = normalize_text(entry_match.group(1))
            if entry_text:
                current_section.entries.append(Entry(text=entry_text, level=entry_level(line)))
            continue

    return [entry for entry in entries if entry.sections]


def take_recent(entries: list[VersionEntry], count: int) -> list[VersionEntry]:
    if count <= 0:
        return []
    return entries[:count]


def render_lua(entries: Iterable[VersionEntry]) -> str:
    lines: list[str] = [
        "local NS = _G.AzerothWaypointNS",
        "",
        "NS.CHANGELOG_DATA = {",
    ]

    for version in entries:
        lines.append("    {")
        lines.append(f'        version = "{escape_lua_string(version.version)}",')
        lines.append("        sections = {")

        for section in version.sections:
            lines.append(f'            {{ title = "{escape_lua_string(section.title)}", entries = {{')
            for entry in section.entries:
                lines.append(
                    "                { "
                    f'text = "{escape_lua_string(entry.text)}", '
                    f"level = {entry.level} "
                    "},"
                )
            lines.append("            }},")

        lines.append("        },")
        lines.append("    },")

    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert recent CHANGELOG.md entries into docs/changelog_data.lua format."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT,
        help=f"Markdown changelog path. Default: {DEFAULT_INPUT}",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Lua output path. Default: {DEFAULT_OUTPUT}",
    )
    parser.add_argument(
        "--count",
        type=int,
        required=True,
        help="Number of recent versions to include.",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print the Lua result to stdout instead of writing a file.",
    )
    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()

    if args.count <= 0:
        parser.error("--count must be greater than 0")

    if not args.input.is_file():
        parser.error(f"input file not found: {args.input}")

    markdown = args.input.read_text(encoding="utf-8", errors="replace")
    parsed = parse_changelog(markdown)
    selected = take_recent(parsed, args.count)

    if not selected:
        parser.error("no changelog entries were parsed from the input file")

    lua_text = render_lua(selected)

    if args.stdout:
        print(lua_text, end="")
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(lua_text, encoding="utf-8", newline="\n")
    print(f"Wrote {len(selected)} version(s) to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
