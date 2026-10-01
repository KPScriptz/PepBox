# Notices

DropClip is a fork of OpenClip, Copyright (c) 2026 Ganesh M and OpenClip Contributors, taken
from OpenClip while it was licensed under the MIT License. DropClip is licensed under the same
MIT License: see [LICENSE](LICENSE), which keeps OpenClip's copyright notice as the licence
requires. Where it came from, and why it stays there, is in [PROVENANCE.md](PROVENANCE.md).

DropClip is not OpenClip and is not affiliated with or endorsed by the OpenClip project. "OpenClip"
is named here only to say where DropClip's source comes from; DropClip uses none of OpenClip's
names, logos or services.

`Sources/OpenSelection` is OpenSelection, Copyright 2026 Ganesh M, licensed under the Apache
License, Version 2.0: see [Sources/OpenSelection/LICENSE.txt](Sources/OpenSelection/LICENSE.txt)
and its notice, [Sources/OpenSelection/NOTICE.txt](Sources/OpenSelection/NOTICE.txt). Two files
are modified, and each says so at the top: `OpenSelectionMonitor.swift` (`MainActor.assumeIsolated`
at AppKit callouts goes through `DroppyMainThread`, `Sources/OpenSelection/Droppy/`) and
`CursorClassifier.swift` (the cursor image's pixel data is kept alive for the whole scan).

`Sources/DropClip/Droppy/KeyboardShortcuts.swift` re-implements the part of Sindre Sorhus's
KeyboardShortcuts package (MIT License, Copyright (c) Sindre Sorhus) that DropClip uses.

Every licence and notice ships inside the built droplet, in `Assets/Legal/`
(`Acknowledgements.txt` lists them), and DropClip's Credits row in Droppy's Settings opens it.

The `Droppy/` folder in each target is Droppy's host layer, written for this droplet.
