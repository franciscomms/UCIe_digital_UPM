#!/usr/bin/env python3
"""Optional static elaboration with pyslang; Questa does not require Python."""
from pathlib import Path
import os
from pyslang import syntax, ast, DiagnosticEngine, parsing, Bag, SourceManager
root = Path(__file__).resolve().parents[1]
os.chdir(root)
lines = Path('bringup.f').read_text().splitlines()
options = parsing.PreprocessorOptions()
options.additionalIncludePaths = [x[8:] for x in lines if x.startswith('+incdir+')]
manager = SourceManager()
tree = syntax.SyntaxTree.fromFiles([x for x in lines if x and not x.startswith('+')], manager, Bag([options]))
compilation = ast.Compilation()
compilation.addSyntaxTree(tree)
diagnostics = compilation.getAllDiagnostics()
Path('logs/static_elaboration.log').write_text(DiagnosticEngine.reportAll(manager, diagnostics))
errors = [d for d in diagnostics if d.isError()]
print(f'{len(errors)} errors; {len(diagnostics)-len(errors)} other diagnostics')
if errors:
    print(DiagnosticEngine.reportAll(manager, errors))
raise SystemExit(bool(errors))
