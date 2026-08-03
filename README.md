# mirror-starship

OCX mirror for [starship](https://starship.rs), the minimal, blazing-fast and
infinitely customizable prompt for any shell. One repository, one spec
directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [starship](https://github.com/starship/starship) | [`starship/mirror.yml`](starship/mirror.yml) | `ghcr.io/ocx-contrib/starship/starship` | [`ocx.sh/starship/starship`](https://index.ocx.sh/starship/starship) | `ISC` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

The GitHub org is the project's own brand, so org and tool coincide:
`starship/starship`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
starship/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `starship/mirror.yml` does not restate it.

## Platforms

`starship` publishes six platform entries: both Linux arches, both macOS arches
and both Windows arches.

**Asset filenames carry no version string at all.**
`starship-x86_64-apple-darwin.tar.gz` is the identical name on every release —
the version lives only in the release tag and the download URL's tag segment.
So every asset pattern in the spec is an **exact anchored literal**, not the
`tool-.*-<triple>` wildcard the other Rust mirrors in this fleet use; that shape
would match zero assets here and silently skip the platform. It is also why
`verify.github_asset_digest` is doing real work: the digest is the only thing
that tells one release's tarball from another's.

Upstream ships **both** a `-gnu` and a `-musl` x86_64 Linux asset, and musl
**only** for every other Linux arch. This mirror carries the **musl** build on
both arches, under **bare** platform keys — measured, not assumed. Both musl
binaries were byte-measured on the `v1.25.0` floor and on `v1.26.0` and are
fully **static**: no `PT_INTERP`, no `DT_NEEDED`. The gnu binary, measured the
same way, is dynamically linked against `libc.so.6`, `libgcc_s.so.1`,
`libpthread.so.0`, `libm.so.6` and `libdl.so.2`. `os.features` states what an
artifact requires *of the host*, so a static binary takes a bare key: a
`+libc.musl` suffix would be a false requirement that hid the package from
every glibc host it in fact runs on.

The gnu asset is deliberately **not** also published under
`linux/amd64+libc.glibc`. That two-key split is the skill's fallback, taken
where the gnu build reaches capability the static one lacks — normally
NSS-dependent resolution, which a local prompt renderer that makes no network
calls cannot reach. It would also be asymmetric: upstream ships no aarch64 gnu
asset, so `linux/arm64` could never carry the matching key. Upstream itself
treats musl as its primary Linux artifact, shipping musl-only for aarch64,
armv7, i686 and riscv64. The `alpine:3.20` container leg in `mirror-base.yml`
is what turns the bare claim into evidence; the measurement is recorded above
the `assets:` block in `starship/mirror.yml`.

Each Windows arch ships **both** a `.msi` installer and a `.zip`, and each
macOS arch shipped a `.pkg` on `v1.25.1`. Only the portable archives are
mirrored; the `\.zip$` / `\.tar\.gz$` anchors are what keep the installer out,
and an under-anchored pattern would match both and fail as an ambiguity error.
Upstream additionally ships `arm-unknown-linux-musleabihf`,
`i686-unknown-linux-musl`, `i686-pc-windows-msvc`,
`riscv64gc-unknown-linux-musl` (new in `v1.26.0`) and
`x86_64-unknown-freebsd`. None of those has an OCX platform key, so they are
deliberately out of scope. Resolution was verified both ways on **all three**
in-range releases — `v1.25.0`, `v1.25.1`, `v1.26.0` — rather than sampled, and
the riscv64 arrival mid-range is exactly why.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `starship/mirror.yml` | hand | yes — see below |
| `starship/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `starship/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec starship/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`starship/metadata.json` declares `binaries: ["starship"]` by hand, and
`starship/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. The scan
only inspects an interface-visible `${installPath}/<dir>` PATH entry, and
starship's archives are **flat**: a single `starship` (`starship.exe` on
Windows) sits at the archive root with no subdirectory to point one at. With
nothing to inspect the scan would pass green whatever the archive contained, so
`auto` and `verify` both fail spec load at exit 65 rather than offer a hollow
check. The hand-written list is what the error message itself directs, and it
is as short as a list gets — `starship` is the only member of the archive.

## The smoke test

starship's real output is **heavily colorized and entirely
configuration-dependent**: the default prompt renders whatever modules the host
happens to satisfy, each wrapped in its own SGR sequence. Asserting a plain
substring against that is the fleet's known colorized-output failure — the
escape codes land between the characters being matched.

So the smoke test never reads an ambient prompt. It writes its **own**
`starship.toml` into scratch, points `STARSHIP_CONFIG` at it via `ocx.run`'s
`env=` overlay, and pins `format` to two modules with empty styles. The
rendered result is then byte-deterministic and SGR-free, so it is compared for
**exact equality** — stronger than any substring, and it reds if starship fell
back to a developer's real `~/.config/starship.toml`. Flipping only
`--status=0` → `--status=1` must flip the character module, and changing only
the environment variable must change only that span, so neither assertion can
pass on a constant. A last check drives `starship init … --print-full-init` for
two shells and asserts they differ — the shell-integration half of the tool,
without asserting a line of its prose.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
