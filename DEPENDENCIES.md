# Dependencies — Ka0s Panel Master

Everything you need installed to build, run, test or release this addon, with commands that work on
**WSL2 / Ubuntu** — the collection's development environment. Every entry names the evidence for why
it is here. Nothing is listed on a hunch; where something is only plausible, it says so.

This file answers **what to install**. [`docs/testing.md`](docs/testing.md) answers **how to
verify**. Neither repeats the other.

Read only the section you need:

| You are… | Read |
|---|---|
| A player installing the addon | [Runtime](#runtime-in-game) — one line long |
| A contributor fixing a bug or writing a test | [Runtime](#runtime-in-game) + [Development](#development) |
| Regenerating the bundled artwork, the poster or the Sunn manifest | all three, including [Release and assets](#release-and-assets) |

---

## Runtime (in-game)

**World of Warcraft (Retail). Nothing else.**

- The TOC declares **no `## Dependencies`** — no other addon is required. Evidence:
  `PanelMaster.toc:1-13`.
- `## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets`
  (`PanelMaster.toc:8`) lists libraries that are **already vendored** under `libs/` and loaded from
  there (`PanelMaster.toc:15-29`). The line only lets the client load a standalone copy first if one
  is installed; a player installs none of it.
- `LibSharedMedia-3.0` is genuinely optional at runtime — the addon has a tested soft-fallback path
  for its absence, which is why the headless mock deliberately omits it
  (`docs/testing.md` ▸ *Mock fidelity that is load-bearing*).
- **Sunn - Viewport Art** is *adapted*, not required: its themes are offered when its texture folders
  are present and the feature simply offers nothing when they are not
  (`modules/SunnArt.lua`, closed issue [`ARTWORK-10`](https://github.com/tusharsaxena/PanelMaster/issues/41)).

Libraries are vendored and committed on purpose. Listing one here does not license fetching it at
build time — `.pkgmeta` has no `externals` block for exactly that reason (`.pkgmeta:3`).

---

## Development

The toolchain to run the tests and the lint. Roughly five minutes on a fresh WSL2 Ubuntu.

```sh
sudo apt update
sudo apt install -y lua5.1 luarocks git
sudo luarocks install luacheck
sudo apt install -y pipx && pipx ensurepath && pipx install lizard
```

| Tool | Version | Why — evidence | Verify |
|---|---|---|---|
| **Lua 5.1** | **5.1 exactly — a hard requirement** | The headless harness loads every source with `loadfile` + **`setfenv`** (`tests/_kit/loader.lua:31`, `:50`). `setfenv` was **removed in Lua 5.2**, so 5.2/5.3/5.4 do not merely warn — they fail. This is also the interpreter WoW itself runs, so it is the version the addon is written against. `.luacheckrc:1` pins `std = "lua51"` for the same reason. | `lua -v` → `Lua 5.1.5` |
| **luacheck** | any recent (verified with 1.2.0) | Half the green gate. Config at `.luacheckrc`; run per `docs/testing.md` ▸ *The green gate*. Pinning a version would be false precision — no rule in `.luacheckrc` depends on one. | `luacheck --version` |
| **lizard** | any recent (verified with 1.23.0) | Drives the `complexity` suite of the automated-test run at release, per `performance-§10`. Optional day to day: without it the report is simply **stale**, which is a visible state, not a compliance failure. | `lizard --version` |
| **git** | any recent | Beyond version control, one suite shells out to it: `tests/_kit/vendor_sync.lua:140` runs `git -C <sibling> …` to read the LibKa0s tag the vendored payload claims. Absent git, that case degrades rather than errors (`:139` guards on `io.popen`). The shell-out moved into the vendored kit when `tests/test_vendor_sync.lua` became registration-only; the requirement did not move with it. | `git --version` |
| **A POSIX shell with `ls`** | — | `tests/_kit/framework.lua:202` enumerates the suite files behind `T.assertSuiteInventory` (`ls -A`, with a `dir /b` fallback for cmd.exe), and `tests/_kit/vendor_sync.lua:96` lists vendored folders the same way (Lua 5.1 has no directory API and this repo declines a LuaFileSystem dependency — see the comment at `framework.lua:197-201`). Any WSL2/Ubuntu shell has this; it is listed because it is a real, invisible assumption. | `ls --version` |
| **The sibling `../LibKa0s` checkout** | matching tag | Not a package — a **checked-out repo next to this one**, needed only to run the vendor gate's four `diff -r` commands (`docs/testing.md` ▸ *The vendor gate*) or to re-vendor. The addon builds, runs and tests without it; `tests/test_vendor_sync.lua` skips what it cannot reach. | `ls ../LibKa0s/LibKa0s` |

**`pip install lizard` does not work on Ubuntu 24.04.** Its Python is marked
`EXTERNALLY-MANAGED` (PEP 668) and `pip` refuses outright. Use the `pipx` line above. The documented
alternative, if you would rather not have pipx, is
`pip3 install --user --break-system-packages lizard` — it works, but the flag name is the warning:
you are overriding the distribution's package manager. Prefer pipx.

`luarocks install luacheck` needs `sudo` because it installs to the system tree. A user-local install
(`luarocks install --local luacheck`) also works, but then `luacheck` is on your `PATH` only after
`eval "$(luarocks path)"`.

### The commands this repo is verified with

```sh
lua tests/run.lua                                    # the headless suite — must be green
luacheck .                                           # must be 0 errors, 0 warnings
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .    # the complexity report (release only)
```

The first two are the commit gate. The third is a **release** step, not a commit gate
(`performance-§10`). What each one means, what it does and does not cover, and the vendor and
artwork gates that neither can see, are all in [`docs/testing.md`](docs/testing.md).

---

## Release and assets

**None of this is needed to build, run or test the addon.** You can fix a bug, write a test, run
both gates and ship a change with nothing from this section installed. It exists only to
**regenerate committed assets** — the artwork catalog, the contact-sheet poster and the Sunn
manifest — and `.pkgmeta:10` excludes `tools` from the packaged addon entirely, so none of it
reaches a player.

If you are not touching `media/artwork/` or the Sunn packs, skip the rest of this file.

### Python and its packages

Four `python3` scripts are committed:

| Script | Needs | Evidence |
|---|---|---|
| `tools/artwork/update_catalog.py` | Pillow | `update_catalog.py:29` — `from PIL import Image` |
| `tools/artwork/make_poster.py` | Pillow | `make_poster.py:61-62` — `import PIL`, `from PIL import Image, ImageDraw, ImageFont, features` |
| `tools/artwork/artwork_cleaner.py` | Pillow **and** numpy | `artwork_cleaner.py:45-46` — `import numpy as np`, `from PIL import Image, ImageFilter` |
| `tools/sunn/build_manifest.py` | **stdlib only** | `build_manifest.py:35-39` — `argparse`, `os`, `re`, `struct`, `sys`. It reads TGA headers by hand precisely so it needs nothing installed. |

So: **Pillow for three of the four, numpy for `artwork_cleaner.py` alone.**

```sh
sudo apt install -y python3 python3-pil python3-numpy
```

| Tool | Version | Verify |
|---|---|---|
| **python3** | any Python 3 (verified with 3.12.3). No script declares a minimum and none uses syntax newer than 3.6. | `python3 --version` |
| **Pillow** | any recent (verified with 10.2.0) | `python3 -c "import PIL; print(PIL.__version__)"` |
| **numpy** | any recent (verified with 2.5.1) | `python3 -c "import numpy; print(numpy.__version__)"` |

Two notes on Pillow specifically. `make_poster.py --check` compares the poster's **pixels**, not its
bytes, so a differing Pillow or zlib does not by itself stale the poster ([`ARTWORK-05`](https://github.com/tusharsaxena/PanelMaster/issues/36),
[`ARTWORK-06`](https://github.com/tusharsaxena/PanelMaster/issues/37)). And it reports its own toolchain — Pillow, **FreeType** and **zlib** versions
(`make_poster.py:387-389`) — into `media/poster/artwork-poster.txt`, so when the pixels *do* move you
can see which component moved. FreeType and zlib arrive with Pillow; they are not separately
installed.

If you prefer pipx-managed installs here too, note that Pillow and numpy are *libraries*, not
applications, so `apt` (or a venv) is the right tool — `pipx` installs commands, not imports.

### The vendored upscaler

`tools/artwork/bin/realesrgan-ncnn-vulkan` (~11 MB) is a **vendored binary**: committed to this
repo, **not installed through any package manager**, and with no upstream to `apt upgrade` it from.
It is already there after a clone — there is nothing to install and nothing to keep current. The
reasoning is recorded in closed issue [`ARTWORK-04`](https://github.com/tusharsaxena/PanelMaster/issues/35): the
import pipeline's one irreplaceable step should not be a download link that can rot, and re-deriving
the bundled plates from a different binary would not be byte-reproducible. Its models sit beside it
at `tools/artwork/bin/models/` (`artwork_cleaner.py:87`), and it is invoked as a subprocess at
`artwork_cleaner.py:276`.

It is dynamically linked, so it does need **system libraries** — this is the one part of this
section that is a real install:

| Library | Ubuntu package | Evidence |
|---|---|---|
| `libvulkan.so.1` | **`libvulkan1`** | `ldd tools/artwork/bin/realesrgan-ncnn-vulkan` resolves it; the binary is a Vulkan-compute build (the name says so). |
| `libgomp.so.1` | `libgomp1` | Same `ldd`. Normally already present — it ships with the GCC runtime — so it is listed for completeness, not as a likely gap. |

```sh
sudo apt install -y libvulkan1
```

Verify — the check is `ldd`, and what you are looking for is that **no line says "not found"**:

```sh
ldd tools/artwork/bin/realesrgan-ncnn-vulkan | grep -i "vulkan\|not found"
```

A working answer looks like `libvulkan.so.1 => /lib/x86_64-linux-gnu/libvulkan.so.1 (0x…)`. A
`not found` on that line is the whole failure, and it is worth knowing that `libvulkan1` gets you
the **loader**, not a **driver**: under WSL2 the driver comes from the WSLg/Mesa side, and whether
this machine can actually run compute is a separate question the loader will not answer. If the
upscaler runs but produces nothing, install `vulkan-tools` and read `vulkaninfo`.

`artwork_cleaner.py` has a `--no-ai` path that falls back to Lanczos resampling
(`artwork_cleaner.py:590`), so a machine with no working Vulkan can still run the pipeline — at
lower quality, and **not** reproducing the committed assets byte for byte.

### What is deliberately NOT listed here

- **Bundled assets are not dependencies.** `tools/artwork/fonts/DejaVuSans*.ttf` are committed
  ([`ARTWORK-06`](https://github.com/tusharsaxena/PanelMaster/issues/37)) and `media/` ships the addon's own art. They are in the repo after a clone; there
  is nothing to install. A font you must not install is the point — `make_poster.py` resolves fonts
  *only* from `tools/artwork/fonts/` and fails loudly rather than falling back to a system font.
- **`realesrgan-ncnn-vulkan` model files** — same: committed at `tools/artwork/bin/models/`.
- **Nothing for CI.** There is no CI in this repo; every gate is local and hand-run
  (`docs/testing.md`, last line).
- **No packaging tool.** The addon is packaged from `.pkgmeta` by CurseForge's own packager, which
  runs on their infrastructure. Nothing local is needed to produce a release zip.

---

## Keeping this file honest

It is checked at **release**, alongside the rest of the doc set (`documentation-§5`, `documentation-§7`).
A new script, a new import, a new vendored binary or a dropped tool changes this file **in the same
change** — a dependency list that is wrong is what turns a new contributor's first hour into their
last.
