# NOTICE

This repository packages and redistributes upstream software published by the
[starship](https://starship.rs) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

`starship/logo.svg` is upstream's own `media/icon.svg`, reproduced unmodified
under the same ISC grant as the rest of the upstream repository;
`starship/logo.png` is a 512px raster of it. Any upstream name or mark used is
used nominatively, for identification only. The marks remain the property of
their respective owners and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `starship` | `ghcr.io/ocx-contrib/starship/starship` | `ISC` |

---

## `starship`

Upstream: <https://github.com/starship/starship>
Published to `ghcr.io/ocx-contrib/starship/starship`.

| Component | SPDX | Holder |
|---|---|---|
| starship (`starship`) | **ISC** | Copyright (c) 2019-2022, Starship Contributors |

The ISC License is permissive — functionally equivalent to MIT and BSD-2-Clause
— and grants permission to use, copy, modify and **distribute** the software
for any purpose, with or without fee, provided the copyright notice and the
permission notice appear in all copies. Both are reproduced here and the full
license text is published upstream at
<https://github.com/starship/starship/blob/master/LICENSE>. The published
binaries statically link third-party Rust crates under permissive licenses,
enumerated in the `Cargo.toml` / `Cargo.lock` shipped in the upstream source
tree at the corresponding tag and gated upstream by `deny.toml`.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
