#!/usr/bin/env python3

from pathlib import Path
import re

ROOT_DIR = Path(".")
OUTPUT_FILE = "merged_systemverilog.md"

SV_EXTENSIONS = {".sv", ".svh", ".v", ".vh"}

files = sorted(
    f for f in ROOT_DIR.rglob("*")
    if f.is_file()
    and f.suffix.lower() in SV_EXTENSIONS
    and f.name != OUTPUT_FILE
)

def make_anchor(path):
    return re.sub(r"[^a-zA-Z0-9_-]", "-", str(path))

with open(OUTPUT_FILE, "w", encoding="utf-8") as out:

    out.write("# SystemVerilog Project Merge\n\n")
    out.write(f"Total files: **{len(files)}**\n\n")

    # Index
    out.write("## File Index\n\n")

    for idx, file in enumerate(files, start=1):
        rel_path = file.relative_to(ROOT_DIR)
        anchor = make_anchor(rel_path)
        out.write(f"{idx}. #{anchor}\n")

    out.write("\n---\n\n")

    # File contents
    for idx, file in enumerate(files, start=1):
        rel_path = file.relative_to(ROOT_DIR)
        anchor = make_anchor(rel_path)

        out.write(f'<a id="{anchor}"></a>\n\n')
        out.write(f"## [{idx}] {rel_path}\n\n")

        # Comment header inside the code block
        out.write("```systemverilog\n")
        out.write(f"// FILE_INDEX: {idx}\n")
        out.write(f"// FILE_PATH : {rel_path}\n\n")

        try:
            out.write(file.read_text(encoding="utf-8", errors="ignore"))
        except Exception as e:
            out.write(f"// ERROR READING FILE: {e}\n")

        out.write("\n```\n\n")

print(f"Created {OUTPUT_FILE} with {len(files)} files.")