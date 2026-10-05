# OrbitMorph Credits and Local Tool Licenses

OrbitMorph is a local macOS front end. Its app bundle and DMG contain OrbitMorph, original brand assets, self-created tutorial PNG/MP4 samples, a generated PCM feedback sound and its English/Simplified Chinese language catalogue. They do not redistribute the optional conversion tools below. The app discovers tools already installed on the user's Mac and invokes them locally.

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

Version 1.2.0 also discovers independently installed LibreOffice and Calibre apps. LibreOffice is distributed under MPL-2.0 and includes components under other licenses; see the [official license page](https://www.libreoffice.org/licenses/) and the installation's LICENSE files. Calibre's source licensing is documented in its [upstream LICENSE](https://github.com/kovidgoyal/calibre/blob/master/LICENSE). Those tools and their bundled libraries are not copied into OrbitMorph.

The included tutorial image, video and feedback sound were created locally for OrbitMorph. They contain no user documents or downloaded stock footage/music. PDFKit, Vision, ImageIO and system fonts are supplied by macOS rather than redistributed as app resources.

OrbitMorph includes no Homebrew libraries or converter executables in its application bundle. Any converters configured by the user remain subject to their own upstream license terms.
