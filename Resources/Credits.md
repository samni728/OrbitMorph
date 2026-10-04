# OrbitMorph Credits and Local Tool Licenses

OrbitMorph is a local macOS front end. Its app bundle and DMG contain OrbitMorph and its original brand assets; they do not redistribute the optional command-line conversion tools below. The app discovers tools already installed on the user's Mac and invokes them locally.

The license identifiers below are recorded from the Homebrew formula metadata installed on the development Mac on 2026-10-03. The specific license and obligations for an external tool depend on the build the user installed. This list is a credit and identification aid, not a copy of each license text; consult the installed formula and upstream project for the complete terms.

| Optional local tool | Homebrew formula license metadata |
| --- | --- |
| FFmpeg | GPL-3.0-or-later (the installed formula's metadata; custom FFmpeg builds can differ) |
| ImageMagick | ImageMagick License |
| Pandoc | GPL-2.0-or-later |
| Ghostscript | AGPL-3.0-or-later |
| 7-Zip (`7zz`, formula `sevenzip`) | LGPL-2.1-or-later AND BSD-3-Clause |
| WebP tools/libraries | BSD-3-Clause |
| libheif | LGPL-3.0-or-later |

OrbitMorph includes no Homebrew libraries or converter executables in its application bundle. Any converters configured by the user remain subject to their own upstream license terms.
