# Tungsten Tooling & Community Research Report
Date: 2026-10-24 · Target: Fire HD 10 13th gen (tungsten/KFTUWI, MT8169, kernel 5.4.86, Fire OS 8.3.3.6, SPL 2025-06)

## 1. Fire tablet / MTK ecosystem

### Directly relevant, high value
- **R0rt1z2/GhostLock** — https://github.com/R0rt1z2/GhostLock — kernel root exploit (CVE-2026-43499) for Fire Max 11 (`sunstone`) and Fire TV Stick 4K Max 2nd gen (`karat`), 5.10 targets. This is the base we're porting; also shows R0rt1z2's offset-derivation conventions.
- **Trona port (same bug, 11th-gen HD 10, active 3 days ago)** — XDA thread: https://xdaforums.com/t/temp-root-fire-fire-hd-10-fire-hd-10-plus-11th-gen-trona-trona_plus.4805804/ — CyberMeowfia CVE-2026-43499 adapted to trona/trona_plus. Trona is Fire OS 8 on an Amazon MTK tablet — the closest living relative to tungsten. Contact the author; likely solved several 5.4-adjacent/Amazon-specific problems already.
- **Kara port (4.14 kernel!)** — https://xdaforums.com/t/temp-root-fire-tv-stick-4k-max-1st-gen-kara.4801361 — proves GhostLock ports back to pre-5.10 kernels; the wake-path differences someone solved for 4.14 will inform our 5.4 futex wake panic.
- **accessmodifier364/cve-2026-43499-firetv-sheldonp-writeup** — https://github.com/accessmodifier364/cve-2026-43499-firetv-sheldonp-writeup — "from temporary root to bootloader unlock" via preloader downgrade. This is the roadmap for what to do *after* temp root on tungsten; its references/ page links kamakiri sheldon branch and R0rt1z2's Fire OS 4.4 port. Read first.
- **seb5594/GhostLock-sheldon** — https://github.com/seb5594/GhostLock-sheldon — another Amazon port with writeup.
- **dnlid/CVE-2026-43499** — https://github.com/dnlid/CVE-2026-43499 — futex PI UAF research package (bug analysis of remove_waiter/rtmutex). Useful for understanding the 5.4 vs 5.10 wake-path divergence.
- **XDA tungsten threads** — temp-root thread (https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/) confirms tungsten IS affected by CVE-2026-43499 (~4% trigger rate noted) and that public NAM-AL00/Rortiz2 builds don't work; brainstorming thread (.4686124) has R0rt1z2 himself participating — he is the person to ping with a well-formed 5.4 wake-path question.
- **amazon-mt8169-dev GitHub org** — https://github.com/orgs/amazon-mt8169-dev/repositories — has `android_device_amazon_raspite` (updated Feb 2026). Raspite = Fire HD 8 12th gen, also MT8169. Kernel source mirror: **488315-archive/android_kernel_amazon_raspite** (Fire OS 8.3.1.3, aarch64 build config) — this is a *matching-SoC Amazon kernel source tree*, invaluable for building a source-level 5.4 reference and for diffing futex/rtmutex code instead of pure binary work. Highest-leverage find in this section.
- **amazon-mustang-hack** (artur9010) — Fire 7 9th-gen root via CVE-2022-38181; its README has a "PARKED: GhostLock" section with notes on why GhostLock was parked on a 4.9 Amazon kernel — read for known Amazon-specific pitfalls.
- **ericpardee.github.io/fire-hd-ownership/HANDOFF.html** — existing CVE-2022-38181 trona handoff doc (our own ecosystem's prior art on Amazon kernel-exploit handoffs).

### DA / preloader / SP Flash Tool
- androidmtk.com DA collections and penumbra.itssho.my DA archive exist, but **no MT8169 Amazon-signed DA is publicly known**; tungsten's bootrom DL is fused off and Amazon DAs are prod-key signed, so generic DA collections are a **dead end** — do not spend more time here. Avoid "Amazon service tool DA leak" downloads on random forums: unverifiable, classic malware vector. Dead end, flagged.
- kamakiri/amonet (https://github.com/amonet-kamakiri/kamakiri, https://github.com/R0rt1z2/amonet) require a bootrom USB-DL path; fused off on tungsten → not applicable. amonet-koboreru (preloader exploit) targets older preloaders; worth a skim of its technique against the extracted tungsten preloader but low odds.
- **kaeru** (https://github.com/R0rt1z2/kaeru) is ARMv7 LK payload — tungsten is aarch64; not applicable as-is. [Correction from later analysis: tungsten's LK is actually 32-bit Thumb-2, so kaeru is technically architecture-compatible — the real blocker is the preloader's image signature enforcement.]

### Fire Toolbox on 8.3.3.6
- Fire Toolbox v44 (Apr 2026) ships a built-in OTA blocker and works on Fire OS 8.3.3.6 without root for: disabling OTA, custom launcher (via Launcher Manager 1.1.x / LauncherHijackV403), debloat. Confirmed by Liliputing coverage and mrhaydendp/Fire-Tools releases (https://github.com/mrhaydendp/Fire-Tools/releases) which has macOS/Linux posix parity. Free. **Verdict: worth running now** to freeze OTA so Amazon can't ship a patch mid-effort. (AFTVnews notes Amazon patched the Fire TV variant of the launcher exploit — expect tablet-side patches eventually.)
- The "SYSTEM USER ≤ RS8149" XDA method (https://xdaforums.com/t/system-user-fire-cube-stick-tv-tablet-ps7704-fireos7-rs8149-fireos8.4759215/) gives system-user privileges on FireOS8 ≤ RS8149 — check whether 8.3.3.6 build number is ≤ RS8149; if so it gives OTA-disable + launcher without any kernel work.

## 2. Kernel exploit dev tooling (macOS arm64)

| Tool | Install | Works on arm64 vmlinux? | Verdict |
|---|---|---|---|
| **Ghidra + analyzeHeadless** | `brew install --cask ghidra` (needs a JDK, e.g. `brew install temurin`) | Yes — import raw binary as ARMv8/AArch64 little-endian, base 0xffffff8008000000 (from boot.img); with kallsyms recovered you already have a symbol map to import as a Ghidra script | **Worth it.** Headless decompile of the 5.4 futex wake path (`futex_wake`, `rt_mutex_unlock`, proxy-lock rollback) beats rizin's pseudocode. Use `-process`/`-scriptPath` with a postscript to dump decompilations to text for agent consumption. |
| **rz-ghidra** | NOT in homebrew core; build from source: `brew install rizin cmake` then cmake build of rizinorg/rz-ghidra against rizin ≥0.8 | Yes (anything rizin opens) | **Skip for now** unless Ghidra GUI is unwanted; source build on macOS arm64 is finicky (rizin version-lock). Ghidra proper gives the same decompiler. |
| **Diaphora** | `pip install diaphora` + IDA — requires IDA Pro/IDA Home (~$365+, over budget) | Yes but gated on IDA | **Skip** (budget). |
| **BinDiff** (standalone, Google) | Free since 2023: https://github.com/google/bindiff — but its free UI needs IDA/Ghidra export via BinExport; Ghidra BinExport plugin is free | Yes | **Worth it for 5.4-vs-5.10 futex diffing**: build two kernels from source (raspite tree + android common 5.10 GhostLock target), export with BinExport, diff in BinDiff. Function-level similarity directly answers "what changed in the wake path." |
| **r2diaphora** (FernandoDoming) | https://github.com/FernandoDoming/r2diaphora — pip, works on radare2/rizin databases | Yes | **Worth trying** as the zero-cost diffing option; quality below BinDiff/Diaphora but free and scriptable. |
| **Source-level diff (cheapest, best)** | `git clone` android common kernel 5.4 + 5.10 from android.googlesource.com; `git diff v5.4.86..<5.10-target> -- kernel/futex/ kernel/locking/rtmutex*` | N/A (source) | **Do this first.** The 5.4→5.10 futex/rtmutex churn (incl. the 2021 futex rewrite, PI fixes) is fully visible in source; binary diffing only needed to map source knowledge onto tungsten's exact build. |
| **angr** | `pip install angr` (works on macOS arm64) | Loads vmlinux ELF fine | **Skip** — symbolic execution won't materially speed a race/UAF port. |
| **pwndbg / pwndbg-android** | `brew install pwndbg` not a thing; git clone + setup.sh; needs gdb with aarch64 target (`brew install gdb` on arm64 is community-maintained) | Only useful with a live debug target (QEMU or JTAG) — we have neither on tungsten | **Skip** unless a QEMU 5.4 MT8169-ish repro environment is stood up (see §5). |
| **vmlinux-to-elf, capstone, NDK** (current) | already in use | — | Keep. vmlinux-to-elf's kallsyms recovery + Ghidra symbol import is the main loop. |

## 3. Agent skills / MCP

| Item | URL | Verdict |
|---|---|---|
| EncidXVII/claude-reverse-engineering-skill | https://github.com/EncidXVII/claude-reverse-engineering-skill | **Install.** Broad RE skill covering Ghidra/radare2/jadx/firmware triage workflows; cheap to add, decent prompting scaffolding. |
| sjkim1127/Reversecore_MCP | https://github.com/sjkim1127/Reversecore_MCP | **Maybe.** MCP wrapping radare2/YARA/LIEF/capstone — overlaps with our rizin flow; try if agent-driven rizin queries get tedious. |
| FuzzingLabs/mcp-security-hub (radare2-mcp) | https://github.com/FuzzingLabs/mcp-security-hub | **Maybe** — 32 radare2 tools as MCP; same overlap caveat. |
| crowdere/Awesome-RE-MCP | https://github.com/crowdere/Awesome-RE-MCP | Bookmark as index. |
| Masriyan/Claude-Code-CyberSecurity-Skill (04-reverse-engineering) | github.com/Masriyan/Claude-Code-CyberSecurity-Skill | **Skip** — generic. |
| Sarks0/binary-mcp | github.com/Sarks0/binary-mcp | **Skip** — Windows-centric (x64dbg/WinDbg/.NET). |
| Firmware MCP (EMBA/FACT/Firmadyne wrappers), DNYoussef firmware skills | aimcp.info listings | **Skip** — those tools attack Linux *userland firmware* extraction/emulation; our problem is a single kernel binary + on-device race, already past extraction. |
| angr/Ghidra MCP servers (various) | — | **Skip** until Ghidra headless pipeline exists; then a small local script > generic MCP wrapper. |

## 4. CVE-2026-64560 (posix-cpu-timers UAF) porting status

- Bug: race between `sys_timer_delete()` and non-leader `exec()` → UAF of `struct k_itimer`/cpu-timer state. Fixed upstream July 2026 (NVD, RH bug 2508504).
- Existing public work: **only the NebuSec/CyberMeowfia Pixel PoC** (NebuSec/CyberMeowfia repo). No other device/arm64/5.4 ports found — clean field.
- Tungsten applicability: fix landed mid-2026; tungsten's SPL is 2025-06 → **vulnerable**. Code path (kernel/time/posix-cpu-timers.c) is far more stable between 5.4 and 5.10 than the futex/rtmutex code GhostLock depends on — the 5.4 porting surface is small.
- Offset needs for the PoC: standard kcred/cred overwrite targets — `init_cred`/`init_task` (already derivable via existing derive_init_task.py + kallsyms), `k_itimer` and `cpu_timer_list` struct layout for 5.4 (compile-time derivable from raspite kernel source — another reason §1's source tree matters), plus SLAB cache name for the timer allocation (`posix_timers_cache`) and msg_msg/whatever elastic object spray matches that cache's object size on 5.4. arm64 KASLR base is already recoverable via existing primitives.
- **Verdict: viable, arguably better fallback than expected.** If the GhostLock 5.4 wake-path panic proves structural, pivot.
- [LATER CORRECTION from CveScout's disassembly: NOT applicable — our 5.4.86 predates the vulnerable 2020 refactor (55e8c8eb2c7b); the 2010 mt-exec workaround is present in the image. Bug does not exist on tungsten.]

## 5. Other angles worth pursuing

- **QEMU repro environment (recommended, free):** build the raspite MT8169 kernel source (§1) for qemu aarch64 virt, reproduce the GhostLock wake-path panic there with kgdb attached. Turns "panic on device, guess why" into single-stepped debugging. This is the single biggest iteration-speed win available; every GhostLock port author (R0rt1z2 et al.) effectively does this.
- **ramoops/pstore without root:** pstore on MTK survives warm reboot into preloader/LK but reading it needs root (`/sys/fs/pstore`) or a preloader dump path (gated). `adb bugreport` includes last_kmsg only if `ro.debuggable`/console-ramoops is exposed — on production Fire builds it is not. **Dead end without root**; the QEMU repro above substitutes for panic-log needs. Post-root, `/sys/fs/pstore` becomes the panic-analysis channel. [Later note: ramoops cmdline is set but pstore driver never binds on this build — empty even with root.]
- **UART on tungsten:** no published test-point map for Fire HD 10 2023 found. FCC ID internal photos (fccid.io, search grantee for KFTUWI) may reveal pads. Soldering UART on a daily-driver exploit target is high-risk/low-reward vs QEMU; **defer**.
- **fastboot oem commands:** XDA tungsten thread notes `fastboot flashing unlock[_critical]` already tried/failed (idme-gated). Amazon's LK build exposes a reduced command set; enumerate via `fastboot oem help` — cheap to try, historically barren on Fire OS 8 devices. **Low odds, 5 minutes of effort.** [Done: `oem flags` reads/writes usr_flags while locked; `oem idme`, `oem ultraflash`, `oem dmesg`, all getvars are gated.]
- **People to contact:** R0rt1z2 (active in the tungsten XDA thread; authored the GhostLock Amazon ports and amonet), the trona temp-root author (XDA 4805804), accessmodifier364 (sheldonp root→unlock chain). A precise question with the 5.4 panic stack trace will get traction.
- **Fastbrick/GPT caution:** tungsten has no known unbrick path (no bootrom DL, gated DA). Any LK/boot writes post-root must be preceded by full partition dumps via temp root. State the obvious: keep the exploit non-destructive until dumps exist. [Done — full dumps in device-dump/.]

## Budget
Everything above is free (open source). Diaphora+IDA exceeds budget → excluded. Total spend: $0.

## Dead ends (explicit)
- Public MT8169 DA files / Amazon-signed DA leaks — none credible; avoid.
- kamakiri/amonet/amonet-koboreru on tungsten — bootrom fused, preloader gated.
- kaeru — ARMv7 only [but see §1 correction: matches tungsten's 32-bit LK; blocked by sig enforcement instead].
- pstore/ramoops pre-root on production Fire OS — not exposed.
- angr/pwndbg — no live target; wrong tool for a race port.
