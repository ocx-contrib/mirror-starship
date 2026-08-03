# starship/tests/smoke.star — stable across upstream starship releases.
# Asserts the contract (exit code, version shape, computed prompt strings),
# never help/version prose. See ocx.mirror testing-practices.md.
#
# ⚠ starship's REAL output is heavily colorized and entirely
# configuration-dependent: its default prompt renders whatever modules the host
# happens to satisfy (git, language runtimes, cloud contexts, battery, …), each
# wrapped in its own SGR sequence. Asserting a plain substring against that is
# the fleet's known colorized-output failure — the escape codes land BETWEEN the
# characters you were matching.
#
# So this test never reads an ambient prompt. It writes its own config into
# scratch, points STARSHIP_CONFIG at it, and pins `format` to two modules with
# EMPTY styles. The rendered result is then byte-deterministic, contains no SGR
# at all, and can be compared for EXACT EQUALITY — a stronger assertion than any
# substring, and one that reds against a truncated archive, a wrong-arch binary
# that still happened to exec, and against starship silently falling back to a
# developer's real ~/.config/starship.toml.
#
# Verified byte-identical on the v1.25.0 floor and on v1.26.0.

STARSHIP = "starship.exe" if ocx.target_platform.os == ocx.os.Windows else "starship"

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
# The digits are the contract — not the vendor banner, not the exact version.
r_version = ocx.run(STARSHIP, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Hermetic config ────────────────────────────────────────────────────────
# `env_var` echoes a variable this test sets itself; `character` is the only
# other module in `format`, so nothing about the runner leaks into the output.
# Every `style` is empty, which is what makes the result SGR-free. Writing the
# file is what makes the test hermetic: without STARSHIP_CONFIG, starship reads
# ~/.config/starship.toml and the expected strings below become whatever the
# host happens to have.
#
# `[character].format` is pinned to a bare "$symbol" ON PURPOSE. starship's
# DEFAULT is "$symbol " with a trailing space, so leaving it out would make the
# expected strings below encode a starship default rather than this config —
# and the difference is one invisible byte. (Measured: it reds this test.)
CONFIG = """
format = "$env_var$character"
add_newline = false

[env_var.OCX_SMOKE_TOKEN]
variable = "OCX_SMOKE_TOKEN"
format = "[<$env_value>]($style)"
style = ""
disabled = false

[character]
format = "$symbol"
success_symbol = "OK>"
error_symbol = "ERR>"
"""
ocx.write_file("starship.toml", CONFIG)
CONFIG_PATH = ocx.scratch_root + "/starship.toml"


def prompt(token, status):
    # `env=` is an OVERLAY on the composed bundle env, not a replacement, so
    # PATH still resolves the bundled binary. STARSHIP_CONFIG is not a reserved
    # key, so the overlay is accepted.
    r = ocx.run(
        STARSHIP, "prompt", "--status=" + status,
        env = {"STARSHIP_CONFIG": CONFIG_PATH, "OCX_SMOKE_TOKEN": token},
    )
    expect.ok(r)
    # Tolerate a Windows console translating line endings; there are none in
    # the expected output, so this can only ever remove noise.
    return r.stdout.replace("\r", "")


# ── Tier 3a: the core contract — config parsed, modules rendered ───────────
# Exact equality, not a substring: this reds if the config was ignored, if the
# env_var module did not read the live environment, or if any additional module
# leaked in from the host.
out_ok = prompt("alpha", "0")
expect.eq(out_ok, "<alpha>OK>")

# ── Tier 3b: the status code actually reaches the character module ─────────
# Same config, same env, one flag different — so a binary that ignored
# `--status` (or a `character` module that never saw it) reds here and only
# here.
out_err = prompt("alpha", "1")
expect.eq(out_err, "<alpha>ERR>")
expect.ne(out_ok, out_err)

# ── Tier 3c: the value really flows from the environment ───────────────────
# Guards against Tier 3a passing on a constant. Changing only the env var must
# change only that span of the output.
out_other = prompt("bravo", "0")
expect.eq(out_other, "<bravo>OK>")
expect.ne(out_ok, out_other)

# ── Tier 3d: shell integration is generated, and it is per-shell ───────────
# `init <shell> --print-full-init` is the script every user's rc file sources —
# the tool's other half. No assertion on its prose: only that both shells
# produce a substantial script, that they DIFFER (a stub emitting one canned
# blob for every shell would red), and that the bash one exports the documented
# STARSHIP_SHELL variable — a public API token other tools read, not prose.
r_bash = ocx.run(STARSHIP, "init", "bash", "--print-full-init")
expect.ok(r_bash)
r_zsh = ocx.run(STARSHIP, "init", "zsh", "--print-full-init")
expect.ok(r_zsh)
expect.true(len(r_bash.stdout) > 2000)
expect.true(len(r_zsh.stdout) > 2000)
expect.ne(r_bash.stdout, r_zsh.stdout)
expect.contains(r_bash.stdout, "STARSHIP_SHELL")

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
