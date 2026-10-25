# Tungsten (Fire HD 10 13th-gen, KFTUWI) — Bootloader Unlock Research

Compiled 2026-10-24 from the XDA tungsten thread (all 6 pages), the sunstone/karat/sheldonp
unlock releases, R0rt1z2's repos (amonet, amonet-koboreru, kaeru, idmetool, GhostLock), and
the Fire HD 10 11th-gen (trona) thread. Claims are cited per-source; inferences are marked
[INFERENCE]; rumors are flagged as rumors.

---

## 1. Unlock status consensus + evidence

**Consensus: no bootloader unlock exists for tungsten, and nobody in the community has a
working theory that survives contact with the hardware.** The only achievement is
*temporary root* (GhostLock 5.4-tungsten port of CVE-2026-43499 by sshell_, repacked as a
1-click by oversleeper).

Evidence for "why not":

- The 1-click root notes state plainly: *"This package cannot unlock the bootloader and does
  not install persistent root"* and *"Do not use root to modify system, vendor, bootloader,
  TEE, or preloader partitions; DOING SO WILL PERMANENTLY BRICK YOUR DEVICE."*
  — oversleeper, post #82, 2026-09-17:
  https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-90742465
- Full LK reverse-engineering (androdidme, post #74, 2026-09-16):
  https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-90741257
  - Fastboot commands **present**: getvar, signature, flash, erase, continue,
    reboot(-bootloader/-recovery/-fastboot), download, `oem flags`, `oem relock`,
    `oem idme`, `oem ultraflash`, dump, etc.
  - Fastboot commands **absent**: `oem unlock`, `flashing unlock`, `flash:unlock`.
  - `amzn_verify_unlock` path exists in LK but the idme unlock slots are empty
    (`unlock_code` = 256 bytes of 0x00; `t_unlock_code`/`t_unlock_cert` empty).
    *"Filling them with junk will not verify. Do **not** dd a patched lk — preloader still
    signature-checks it."*
  - `ro.oem_unlock_supported=1` is property-only; there is no fastboot command behind it.
  - kaeru payload was actually built for tungsten LK (base 0x4C400000, ~9.6 KB payload at
    0x4C568000, platform_init BL redirected) but **never flashed** — *"Persistent unlock on
    this unit still needs Amazon's signed unlock_code or a preloader/bootrom path."*
- Rortiz2 on why the standard commands can't work (post #23/#25, Sep 2024): Amazon uses a
  signed-unlock-code scheme, update.bin repacking fails signature checks, and a locked
  bootloader verifies boot images (Magisk-patched boot.img = brick):
  https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-89730924
- Bootrom access: believed dead. OP (post #1): *"Fire tablets released after 2020 can't
  access the bootrom, and any known exploits have been patched in version 8.x … it hasn't
  been confirmed whether accessing the bootrom via shorting pins … is entirely impossible."*
  oversleeper physically opened a unit and shorted candidate test pins while running
  mtkclient — no bootrom mode obtained (post #33, 2025-10-04):
  https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-90311516
  Yanny 57 XDA speculated *"Maybe brom fuses like HD 8 2020"* (i.e., Amazon blows an efuse
  disabling bootrom DL on retail units) — **this is a rumor-level hypothesis, not confirmed.**
- mtkclient: an early attempt is referenced as "the only documented exploit attempt":
  https://github.com/bkerler/mtkclient/issues/1166 (link now 404s; referenced at
  post #32: https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-89823965).
  The truncated mtkclient log in post #33 shows HW code 0x1169 (MT8169) and
  `SBC/SLA/DAA enabled: False` readings, but the log was captured while mtkclient was still
  *waiting* for the device ("Waiting for PreLoader VCOM, please reconnect mobile to brom
  mode"), so those False values are likely defaults, **not** a confirmed security-off state.
  [Treat as unverified.]
- SoC identity confusion settled: device-tree says MT8169 (ro.board.platform=mt8169,
  `ro.boot.hardware=mt8169`, mtkclient HW code 0x1169); the SoC package is marked
  MT8186AV (teardown photo, post #5). Amazon kernel tree = `alps-mp-r0.mp8.tc6sp.ppr`.
  CVE-2021-0623 (the only known MT8186-family CVE mentioned) was never shown to be useful
  here (post #1; no follow-up ever produced anything).

## 2. What's been tried and exact failure modes

| Attempt | Result | Source |
|---|---|---|
| `fastboot flashing unlock[_critical]`, `fastboot oem unlock` | Commands **do not exist** in tungsten LK (Ghidra, cmd table at 0x4C66801C). Rortiz2 found the same on maverick (2019): "there is not a single reference to any of them" | https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-90741257 , https://xdaforums.com/t/new-fire-hd10-2019-bootless-root-method-bootloader-unlock-brainstorming.3979343/post-86247343 |
| Repack update.bin with Magisk-patched boot.img | Never got past theory: Amazon signs the whole package; device rejects modified bins; and locked BL verifies boot → would brick | https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-89731257 |
| mtkclient bootrom/preloader access + motherboard pin shorting | No bootrom mode; only the generic "Waiting for PreLoader VCOM" state | post #33 (link above) |
| Chromebook MT8186 uboot/depthcharge chainloading idea | Dead on arrival: locked chain + efuses; "resistant to things like preloader crash methods" (oversleeper post #39) | https://xdaforums.com/t/root-fire-hd-10-13th-generation-2023-tungsten-kftuwi-temporary-root.4686124/post-90373234 |
| idme writes | Nobody has reported attempting an idme write on tungsten. androdidme only *read* idme (`idme print` as root). The `unlock_code` slot exists (256 bytes) but requires an Amazon-signed blob | post #74 (link above) |
| kaeru port for tungsten LK | Built but deliberately not flashed (preloader signature-checks LK → guaranteed brick) | post #74 |
| **Patching `amzn_verify_unlock` in LK to `return 1` (done on trona/MT8183, 11th gen)** | **Hard brick**: "device rebooted, never came back. USB connect/disconnect loop every 3 seconds." Confirms preloader verifies LK signature on the 2021+ Amazon chain | BluPhant, https://xdaforums.com/t/fire-hd-10-11th-generation-2021-bootloader-unlock-root-brainstorming.4509197/post-90750030 (quoted post-90751120); GuestyMC: "Patching the BL just sends it to preloader hell" |
| Preloader RE (trona, by [ACL], Oct 2026 — closest active work to ours) | Verified preloader RSA-verifies the LK *payload* region (`LK[0x200:0x96a10)`) with its embedded 'prod' key; the 0x200-byte **header and the tail are NOT signature-covered**, and header fields (`m_load_addr=0xffffffff`, `m_dram_size`, `m_name`) are attacker-controllable without breaking verification | https://xdaforums.com/t/fire-hd-10-11th-generation-2021-bootloader-unlock-root-brainstorming.4509197/post-90785397 and /post-90774615 |
| Quake94 (wjdob) full research program on trona (SnuSnuRoot port, persistent root on 7.3.1.9) | "No good path forward for software based bootloader unlock. Recovery options are very limited…" — research stopped; repo published | https://xdaforums.com/t/fire-hd-10-11th-generation-2021-bootloader-unlock-root-brainstorming.4509197/post-90765759 , https://github.com/wjdob/firehd11g-unlock-public |

No bricks have been reported *on tungsten itself* — because nobody has dared flash anything
(no recovery path exists). All concrete brick data comes from trona, whose chain
(MT8183/preloader-verifies-LK) androdidme's findings say matches tungsten's.

## 3. The sunstone (Fire Max 11) unlock mechanism — detailed

Release thread: https://xdaforums.com/t/unlock-root-twrp-unbrick-fire-max-11-2023-sunstone.4800303
Source: https://github.com/R0rt1z2/amonet/tree/mt8188-sunstone (plus kaeru, idmetool submodules)

**Observed flow (from unlock.sh + output logs):**

1. GhostLock temp root (`su -c id` must return uid=0).
2. PC pushes a single closed-source binary `bin/unlock` and runs `su -c /data/local/tmp/unlock`.
   No USBDL/bootrom interaction happens during the unlock itself.
3. On-device output: `Unlocking bootloader... ok ok ok` (sunstone) /
   `ok ok` + `Writing new IDME data... ok ok` (karat branch output, same codebase:
   https://xdaforums.com/t/unlock-root-twrp-unbrick-fire-tv-stick-4k-2nd-gen-series-karat-mantra.4798951).
4. Device reboots straight into TWRP. Result: persistent unlock, `verifiedbootstate=orange`,
   kaeru-patched LK (adds `fastboot oem dmesg`, `fastboot boot`, `fastboot fetch`,
   `fastboot oem kaeru-version`), TWRP as recovery, OTA neutering advised.

**What the ZIP contains** (makedist.sh):
`gpt-sunstone.bin`, `sunstone-kaeru.bin` (patched LK), `twrp.img`, `tz.img`, and stock
`mcupm/spmfw/sspm/dpm/dtbo/apusys/cam_vpu*.img`, plus `idmetool` (linked into payloads) and
`pl-payload/pl/pl.bin` (k4y0z's Preloader payload — he is explicitly credited).

**Unbrick path (informs the mechanism):** `bootrom-step.sh` → `modules/main.py` talks to the
device on `/dev/ttyACM0`, does a `handshake2` (k4y0z's preloader "FACTFACT"-style handshake),
loads `pl-payload/pl/pl.bin`, then flashes tz/lk/etc. This only works *"after installing the
exploit"* — i.e., **the unlock leaves a preloader state on the device that accepts the
USBDL payload**. 

**Mechanism [INFERENCE from the above — the `bin/unlock` source is not public]:**
the on-device binary uses root raw-block access to (a) write kaeru-patched LK to `lk`,
(b) write TWRP to `recovery`, (c) write a vulnerable/downgraded **preloader** to
`/dev/block/mmcblk0boot0` (the same `flash_preloader.sh` technique is shown in plaintext in
the sheldonp GhostLock package: `echo 0 > force_ro; dd preloader.img -> /dev/block/mmcblk0boot0`),
and (d) update IDME (idmetool) to the unlocked state. The older Amazon-signed preloader still
passes bootrom verification (no efuse anti-rollback on PL for these chips), no longer
sig-checks LK (or is exploitable via the USBDL handshake), and kaeru LK then runs with AVB
in orange state. R0rt1z2: *"I already killed one tablet while making this possible"* — wrong
images in lk/tee1 = hard brick even on sunstone.

**Critical dependency for the whole recipe:** a *signed, bootable, but exploit- or
verification-deficient preloader* must exist for the SoC. R0rt1z2's `amonet-koboreru`
(https://github.com/R0rt1z2/amonet-koboreru) documents the relevant preloader bug class:
MediaTek's preloader trusts the TEE sub-image header's **load address and size (not covered
by the signature)**, copies the image *before* checking the signature, and its
`check_part_overlapped` guard compares partition names (`lk`/`lk_a`/`lk_b`/`uboot`) against
image-header names (`LK`) so it never fires. A crafted `tee1` therefore hijacks the
preloader's block-device read pointer mid-transfer → EL3 code execution → in-memory patching
of the preloader (accept unsigned DA/ATF/TEE, clear RPMB anti-rollback) → loads a custom LK.
**"Amazon patched this around 2022, so recent Preloaders are not vulnerable. You need to
downgrade the Preloader to an older version first. To check whether a given Preloader is
affected, grep it for `check_part_overlapped done`."** — koboreru README (this grep test has
**never been reported for tungsten's preloader**).

**The sheldonp chain** (https://xdaforums.com/t/temp-root-downgrade-fire-tv-stick-lite-3rd-gen-sheldon-sheldonp.4800976/
+ hardware-verified writeup in GhostLock PR #7, https://github.com/R0rt1z2/GhostLock/pull/7)
is the fully documented version of this recipe:
1. GhostLock root →
2. `dd` the **Fire OS 7.2.3.4 preloader** (old, Amazon-signed, known-vulnerable) onto
   `mmcblk0boot0` → device deliberately "bricks" (won't boot) →
3. PC runs kamakiri `main.py` over USB against the downgraded preloader → rpmb downgrade,
   flash tz/lk/lk-payload, inject microloader → hacked fastboot → TWRP → Magisk.
Why it can't trivially move to tungsten: tungsten shipped in 2023 (Fire OS 8.3.1.9), i.e.
*after* the ~2022 preloader patch — there is **no known vulnerable preloader build for
MT8169/MT8186AV**, and no kamakiri/bootrom exploit exists for this SoC (HW code 0x1169 is
not a kamakiri target). [The "bootrom fused" claim is community hypothesis, not proven —
see §1.]

## 4. IDME format knowledge

- **R0rt1z2/idmetool** (https://github.com/R0rt1z2/idmetool, `lib/idmelib.h`) — the
  authoritative public documentation of the format:
  - Magic `"beefdeed"` (8B) + 4-char version + item count, then items of
    `{char name[16]; u32 size; u32 exportable; u32 permission; u8 data[]}`, 4-byte aligned;
    total region = 30 × 512-byte blocks.
  - Known flag enums: fos_flags bits `ADB_ON(1)`, `ADB_ROOT(2)`, `CONSOLE_ON(4)`,
    `RAMDUMP_ON(8)`, `VERBOSITY_ON(0x10)`, `ADB_AUTH_DISABLE(0x20)`, `DM_VERITY_OFF(0x80)`,
    `BOOT_DEXOPT(0x100)`; separate dev_flags/usr_flags sets.
  - bootmode values: NORMAL=1, DIAG=2, RECOVERY=3, EMERGENCY=4, POWERSAVE=5, FASTBOOT=6,
    TRANSITION=7, **WSWDL=8** (wireless/software download?), STANDBY_LOGO=9.
- Unlock storage (Rortiz2, maverick thread): the "unlock partition" is **not a real
  partition — it's a small sector of the boot1 (idme) area** holding the unlock code,
  "probably encrypted with their RSA keys"; flashing a too-big file there bricks.
  https://xdaforums.com/t/new-fire-hd10-2019-bootless-root-method-bootloader-unlock-brainstorming.3979343/post-86223431
  (older reference: the "Bootloader Unlock Ideas" HD 8.9-era thread,
  https://xdaforums.com/t/bootloader-unlock-ideas.3289721/#post-64729512)
- **Temporary Unlock** (2019+ devices, from LK strings): `amzn_get_temp_unlock_idme_data`,
  `amzn_get_temp_unlock_idme_cert`, `amzn_verify_temp_unlock_code`,
  `"Device is temporarily unlocked, %d reboots remaining"` — a reboot-counted unlock using
  idme `t_unlock_code`/`t_unlock_cert`. Both slots are empty on tungsten retail units
  (androdidme's dump). Source: Rortiz2,
  https://xdaforums.com/t/new-fire-hd10-2019-bootless-root-method-bootloader-unlock-brainstorming.3979343/post-86247557
- Tungsten idme state (root `idme print`, androdidme): `unlock_code` = 256×0x00;
  `t_unlock_code`/`t_unlock_cert` empty; `fos_flags/usr_flags/dev_flags = 0`;
  `ro.boot.flash.locked=1`, `vbmeta.device_state=locked`, `secure_cpu=1 prod=1 rpmb_state=1`.
- On-device writers exist: the karat/sunstone unlock binary itself rewrites IDME from root
  ("Writing new IDME data... ok ok"), and LK exposes `fastboot oem idme` on tungsten
  (unexplored — see §5).

## 5. Untried angles, ranked (temp root + kernel arbitrary R/W, no DA/bootrom)

1. **Grep/audit the tungsten preloader for the koboreru bug.** androdidme's dump guide
   (post #70) already pulls `mmcblk0boot0`. Run `strings preloader | grep
   'check_part_overlapped done'`. If present, the tee1 header-injection primitive
   (load-addr 0 fallback + dead overlap check) may work despite the 2023 build date —
   the ~2022 patch date is for *old devices' firmware*, and per-chip firmware lineages lag.
   This is the single highest-value, lowest-cost check; the payload side (koboreru) is
   MIT-licensed and portable. **Risk: a bad tee1/lk write = permanent brick** (no BROM
   recovery on tungsten), so the preloader must be statically proven vulnerable first.
   Feasibility: moderate-high to *test*, high-risk to *run*.
2. **[ACL]'s LK-header injection (trona, Oct 2026 — directly transferable analysis).**
   He proved (on MT8183) that preloader verifies only `LK[0x200:end)`; the 0x200-byte
   header (incl. `m_load_addr=0xffffffff` fallback-to-0 and `m_name`) is unsigned. If
   tungsten's preloader shares the same "default load address = 0" fallback + broken
   overlap check, a stock-signed LK with a hostile header could inject a payload without
   touching the signed region — no preloader downgrade needed. Verify tungsten's PL does
   the same fallback in Ghidra first. Feasibility: unknown until PL RE'd; same brick risk.
3. **`fastboot oem idme` / `oem ultraflash` / `oem flags` probing.** These commands *are*
   registered in tungsten LK. If `oem idme` allows writing arbitrary idme vars from
   fastboot, candidates are: `fos_flags` (ADB_ROOT/DM_VERITY_OFF — post-boot conveniences,
   not an unlock), `bootmode` (FASTBOOT/DIAG/WSWDL — may expose engineering download modes
   = a new attack surface), and the unlock slots (won't verify without Amazon's signature,
   but the *temp-unlock* path `amzn_verify_temp_unlock_code` has never been fuzzed).
   Feasibility: high to probe (needs only `adb reboot bootloader`), low probability of
   direct unlock; moderate for discovering a new surface.
4. **idme write from root via the idme driver/HAL.** `init.svc.idme-1.0` runs on tungsten.
   With kernel R/W, attempt idme writes (fos_flags/bootmode) and observe what's honored at
   next boot. Non-destructive if restricted to flag vars; **never** touch unlock_code with
   oversized data (documented brick).
5. **RPMB/anti-rollback mapping.** `ro.boot.rpmb_state=1`. Determine whether preloader
   downgrade is even possible (efuse/RPMB PL-version check). If a tungsten PL from an
   earlier incremental (8.3.1.9's is not published; earliest public is 8.3.2.0 per
   bibikalka/FTVDB) differs and *boots*, downgrade-to-vulnerable becomes thinkable — but
   currently no vulnerable tungsten PL is known to exist at all. Feasibility: low (no
   known vuln PL), but cheap to check with the dumped images.
6. **CVE-2021-0623 / other MT8186-family bugs** (raised in OP; never investigated further
   by anyone). Feasibility: low-information rumor tier.
7. **Hardware**: test-point hunting for bootrom (oversleeper tried 5 pads, failed) and
   eMMC/UART work (Quake94: "hoping someone… has the know-how to dump and test directly
   with eMMC"). Feasibility: lab-tier; community skill present ([ACL], Quake94 interested).

## 6. Key community contacts

- **Rortiz2 / R0rt1z2** (Roger Ortiz) — owns the entire modern Fire unlock stack: GhostLock,
  amonet (mt8188-sunstone, mt8696-karat branches), amonet-koboreru, kaeru, idmetool,
  lkpatcher, kamakiri fork. blog.r0rt1z2.com. Said unlocks for onyx/maverick are coming;
  tungsten notably absent from that list.
- **k4y0z** — original amonet/Preloader payload author (the pl-payload used by
  sunstone/karat unbrick); suez/douglas/karnak unlocks.
- **sshell_** — GhostLock 5.4-tungsten port author (https://github.com/sshell/GhostLock
  branch 5.4-tungsten).
- **oversleeper** — tungsten thread owner; 1-click repack; hardware (pin-shorting) tests.
- **androdidme** — tungsten LK map + idme dump + unflashed kaeru build (has offsets/defconfig
  to share).
- **[ACL]** — active (Oct 2026) preloader RE on trona; proved exact LK signed-region
  boundaries; wants a bootrom dump. Closest skill match for tungsten PL analysis.
- **Quake94 (wjdob)** — trona research repo (firehd11g-unlock-public), SnuSnuRoot port.
- **BluPhant** — bricked a trona patching amzn_verify_unlock (failure-mode witness).
- **bibikalka, Michajin, Yanny 57 XDA** — testers with many devices; Yanny has prototype
  units (root adbd on DVT prototypes).
- **bkerler** (mtkclient), **shomykohai** (mtk-payloads/libsej, penumbra), **xyz`**
  (original temp-unlock idea, karnak amonet-3), **diplomatic** (mtk-su).
- Upstream root-exploit lineage: **NebuSec/CyberMeowfia** (CVE-2026-43499),
  **F-19-F/IonStackQuest3** (5.10 port), **dorlow/hazel-cve-2026-43499** (auto offset
  extraction from OTA packages — could be adapted for tungsten builds).

---

## Appendix A: ACL header-injection methodology (verbatim)

Added 2026-10-24. Sources: the wjdob/firehd11g-unlock-public repository (Quake94 + [ACL]'s
trona research), the two XDA posts by [ACL], and R0rt1z2/amonet-koboreru. This is the
methodology template for testing the LK header-coverage question on tungsten.

### A.0 ⚠ LATE-BREAKING (2026-10-21/24): `amonet-trona` exists and rewrites the model

The trona research repo's own anchor document was superseded on the day it was written:

> **"Superseding update, 2026-10-24.** The unlock was achieved publicly on 2026-10-21
> (`amonet-trona`)… On a non-secure unit the preloader accepts an unsigned LK and the RSA
> gate never runs."
> — https://raw.githubusercontent.com/wjdob/firehd11g-unlock-public/main/exploits/CONTEXT-ANCHOR.md

Full delta analysis: `exploits/AMONET-TRONA-DELTA.md` in the same repo (analysis of the
released `amonet-trona-v1.0.0/v1.1.0.zip` artifacts; XDA release thread:
https://xdaforums.com/t/unlock-root-twrp-unbrick-amazon-fire-fire-hd-10-fire-hd-10-plus-11th-gen-trona.4805805/).

Key proven facts from the delta (all artifact-verified, no device needed):

- The release = root (GhostLock named in the wrapper's own error text) → push+run a static
  AArch64 `bin/unlock` (packed, 8.00 entropy — write list not statically readable) → three
  `ok`s → reboot to TWRP. It also contains the string **"downgrading bootloaders..."**.
- **The shipped `trona-kaeru.bin` FAILS RSA-2048-PSS verification against the production
  image key** (stock lk.img VERIFIES as control). Yet thousands of units boot it ⇒
  their preloaders take the unsigned-image path.
- That path is one eFuse bit in the trona preloader:

  ```
  02D59C  ldr  r3, [pc, #8]     ; 0x11F10060  SEC_CFG
  02D59E  ldr  r0, [r3]
  02D5A0  ubfx r0, r0, #1, #1   ; bit 1: secure SoC (signed images required)
  ```
  Bit 1 clear → `"non secure SoC run with unsigned %s"` → signature check skipped.
  A second selector at 0x2D5AC reads **bit 2** = DA validation
  (`"DA validation disabled on non-secure chip"`); the released unbrick sends
  `SEND_DA sig_len=0` + `JUMP_DA` over the preloader serial protocol and it works.
- The unbrick flasher writes **zeros to RPMB block 0** (anti-rollback region) and
  `boot-recovery` into `misc`; ships an **older signed TEE build** (not header-tampered).
- Correction of a prior claim (important for what an unlock buys on Amazon chains):
  **"an unlocked device does NOT skip LK verification — it re-verifies with the alternate
  Amazon key (0x2D86, key 0x37A98) and still rejects on failure. Unlock changes *which
  Amazon key* is acceptable, not whether a signature is needed. A patched `lk` cannot run
  even on an unlocked unit."** (CONTEXT-ANCHOR corrections table.) On trona/sunstone-class
  chains, amonet works *because the device is non-secure-fused*, not because of any
  unlock_code state.

**Implication for tungsten (directly testable with GhostLock kernel R/W):**

1. Dump tungsten's preloader (`mmcblk0boot0` — androdidme's guide already does this) and
   grep for `"non secure SoC run with unsigned"` / `"secure SoC should run signed"` /
   `"DA validation disabled on non-secure chip"`. If the strings and the SEC_CFG check
   exist, find the register address (may differ from MT8183's `0x11F10060`).
2. **Read the actual SEC_CFG register value from the live rooted device** (kernel
   arbitrary read of the SEC_CFG MMIO). `ro.boot.secure_cpu=1` does NOT answer this — the
   delta doc explicitly calls that inference unsound ("That property describes the CPU
   security complex, not the SBC/DA fuse bits").
3. If bit 1 is clear on tungsten → the amonet recipe (root + kaeru LK write) is open to us
   exactly as on trona/sunstone, with androdidme's already-built kaeru payload. If set →
   locked-prod behavior, and any LK write is the documented S2 brick.

### A.1 The two XDA posts by [ACL] — verbatim

Post #133, 2026-10-13
(https://xdaforums.com/t/fire-hd-10-11th-generation-2021-bootloader-unlock-root-brainstorming.4509197/post-90774615):

> More updates for research reasons only. Wealth of info here.
> https://github.com/wjdob/firehd11g-unlock-public/blob/main/stage2-unlock/README.md
>
> I did verify that preloader verifies LK . It looks into the header and checks the payload
> in lk for changes. So if you do change LK in anyway, you will go to the bootloop of death.
> However, it looks like it only checks the payload, not the header 0x200 or the tail end
> portion.
>
> This is a check of a matching pair of preloader and lk.
>
> ```
> LK image: 617232 bytes, image extent 0x96b10
>   magic 0x58881688  name 'lk'  hdr.size 0x96910
>   _LK_VER: tag at 0x96a06 (expected 0x96a06)
>   signed region: LK[0x200:0x96a10) (616464 bytes)
>
> preloader key 'alternate' @ 0x37d6c  (n[0:4]=c48d9dba)
>     rejected  (cryptography cross-check: rejected)
> preloader key 'prod' @ 0x37e6c  (n[0:4]=d847f58a)
>     VERIFIES  (cryptography cross-check: VERIFIES)
> preloader key 'unlock' @ 0x37f6c  (n[0:4]=e34a3e78)
>     rejected  (cryptography cross-check: rejected)
>
> RESULT: MATCHED PAIR -- this LK image is validly signed by this preloader's prod
> image-verify key, and does not collide with the other key slots.
> ```
>
> if you take a close look at the actual lk header, there is a lot of fields that are
> blanked our or that can be modified without breaking the signature check . Potentially
> allowing extra data to be injected into memory. I will continue down this path but
> sharing for anyone else looking into this.
>
> ```
> m_is_valid     : 1 (1 if magic matched, else 0)
> m_header_size  : 0x200 (Always 0x200 bytes total header block size)
> m_is_extended  : 1 (1 if extended variant2 header format, else 0)
> m_img_version  : 0x0 (Chain flags/component-type marker)
> m_boot_mode    : 0xffffffff (Target boot mode mask)
> m_load_addr    : 0xffffffff (RAM destination address for payload)
> m_entry_offset : 0x0 (Entry point offset relative to load address)
> m_size         : 0x96910 (616720 bytes raw payload size)
> m_aligned_size : 0x96910 (Block-aligned payload size)
> m_file_offset  : 0x0 (Flash layout offset / sector tracking)
> m_dram_size    : 0xffffffff (Maximum allocation bounds limit)
> m_name         : b'lk\x00...' (Null-padded partition identifier string)
> ```

Post #140, 2026-10-22
(https://xdaforums.com/t/fire-hd-10-11th-generation-2021-bootloader-unlock-root-brainstorming.4509197/post-90785397):

> > ChipLag said: … Someone told me that's how the older exploits (I think kamakiri or
> > amonet) started … I was able to locate the firmware on both The Internet Archive and
> > from this archive: https://github.com/fireos-archive/fireos-archive …
>
> Thanks for the archive. I have been wanting to run a test and see if mixing preboot and
> diff lk versions create a signature issue. This may at least answer if we can mix and
> match.

(Related context posts: #131 — "There is signs of sha256 but what it's not clear is how
it's used to test the validity of the lk.img… preloader has a lot of interesting stuff.
Looks like there is support for usbtty so technically you can recover if your lk image is
corrupt"; #137/#138 — wants a BROM dump, asks whether cross-version PL/LK mixing fails the
signature check.)

### A.2 Proving the signed region is LK[0x200:] — the method

From `stage2-unlock/README.md` ("Container-header audit: pre-authentication load path
(2026-10-06)"), reproducible offline with `stage2-unlock/verify-lk-signature.py`:

> `AMZN_PL_VERIFY` (preloader 0x2b48 → RSA public op 0x2bc30 + hw SHA-256 0x2bc2a) with
> RSA-PSS / SHA-256 / MGF1-SHA-256 / salt 32, signature = last 0x100 bytes:
>
> | key | over `LK[0x000 : 0x939f0)` | over `LK[0x200 : 0x939f0)` |
> |---|---|---|
> | 0x37a98 alternate image key | rejected | rejected |
> | **0x37b98 prod image key** | rejected | **VERIFIES** (604 144 bytes) |
> | 0x37c98 unlock key | rejected | rejected |
>
> So the LK image is verified by the **prod image-verify key**, and the leading 0x200-byte
> container header is outside the signature. Identical for the OTA `lk.img` and the
> on-device `mmcblk0p5` dump.

Boot-flow ordering (single function, no boundaries between the calls):

```
019d2e  bl 0x193bc            <- LK load  (read hdr[4] bytes to 0x56000000)
019d40  ... 'Warning: LK out of boundary.'  (non-fatal, printed AFTER the copy)
019d62  bl 0x2f58             <- LK verify (0x2c60 -> AMZN_PL_VERIFY)
019fcc  bl 0x21590            <- PICACHU DVFS module (writes the 0x5F100C00 slot — AFTER LK copy)
```

Loader internals (LK loader wrapper 0x193bc → "image with header" loader 0x200f4; header
parsers 0x2007c / 0x18c00):

- Container magic `0x58881688` at hdr[0]; second magic `0x58891689` (hdr[0x30]) selects the
  variant. Fields used: hdr[4]=payload size, hdr[8]=name ("lk"), hdr[0x28]=requested
  address, hdr[0x2c]=mode, hdr[0x44]=size-alignment unit (0x10 for LK).
- **"The header is consumed, not copied": the device read starts 0x200 bytes into the
  partition (+0x200 at 0x20180), so only the payload reaches RAM, at the hard-coded
  0x56000000 (`mov.w r3, #0x56000000` @ 0x19d20).**
- **m_load_addr (`hdr[0x28]`) role on trona: "Destination is not header-controlled on this
  device. The header address is used only when `hdr[0x2c]==0 && hdr[0x28]!=-1`, in which
  case 0x200f4 calls the TEE-reserve helper 0x26064 and uses its result. Every shipped
  image carries 0xffffffff sentinels in hdr[0x28]/hdr[0x2c] … so the caller-fixed address
  always wins."** — i.e. the koboreru "choose the destination" move is dead *on trona's
  loader generation*; only the **length** (`hdr[4]`) is attacker-controlled from the
  unsigned header. (Tungsten's loader generation is UNKNOWN — this is exactly what we must
  check; if tungsten's PL *does* honor hdr[0x28], the primitive is much stronger.)
- m_name role: in guard-generation A devices the name feeds `check_part_overlapped`'s
  name table (see A.4); in generation B (trona) there is no name table at all.
- After load, `get_img_size` (0x2b260 → parse 0x18c00) **recomputes** the size with the
  hdr[0x44] alignment; verifier derives `len = size-0x100`, `sig = base+size-0x100`,
  `_LK_VER:` tag at `base+size-0x10a`. Copy length and verify length are driven by the
  same value ⇒ fails closed: "any value that keeps the signature valid also keeps the copy
  inside the LK window; every larger value breaks the `_LK_VER:`/signature check first."
- Anti-rollback on LK: **NOT ENFORCED** — the preloader reads the 2-byte version at
  `(lk_end − 0x102)` and only logs it; no minimum-version compare exists.

### A.3 What a hostile header can do (the proven primitive and its exact limits on trona)

- **Primitive**: `hdr[4]` larger than the LK window ⇒ the preloader copies that many bytes
  from flash to 0x56000000 upward, **before** any signature check; the 9 MB window check
  is a printed non-fatal warning *after* the copy; the block read is bounded only by the
  *card* sector count, not the partition (a read starting in `lk` can run into following
  partitions). This is "a real pre-auth write primitive of the Koboreru / CVE-2023-20695
  class."
- **Live DRAM map (read-only, over the root listener)** killed it on trona: the
  preloader's working set `g_dram_buf = 0x44800000` is ~280 MiB **below** the LK window;
  `0x56900000 → 0x624e0000` (framebuffer) is ~188 MiB of unreserved DRAM; the only
  identified structure above the window (MTK context slot `0x5F100C00`, PICACHU DVFS
  save/restore pair SAVE 0x296f0 / RESTORE 0x291a4) is **written after** the LK read and
  its workspace is written before being read ⇒ "the failure mode is the known brick, not
  a hijack." Branch/computed-pointer tooling: `stage2-unlock/pl-cfg.py`
  (builds branch edges + pc-relative literals + computed `ldr/add pc` code pointers;
  found the *only* reference to RESTORE at 0x299e0 where it's handed to an external
  component).
- **The sister defect that survives on trona (ATF_DRAM)**: in `tee.img`, the `atf_dram`
  sub-image's **copy** length comes from the unsigned *outer* container header while its
  **authenticated** length comes from the *inner* header (`inner[0x08]+inner[0x18]`), with
  **no equality check**; it loads to caller-fixed `0x54600000`, 26 MiB below LK, **after**
  LK is verified, and nothing re-verifies LK. An oversized outer `hdr[4]` (min
  0x1a00010 due to 0x10 alignment) could overwrite already-verified LK in RAM. Dead on
  trona in practice because: exploiting it requires relocating the `tee` container into
  `metadata` (boot-critical writes, S2/S3 brick on any error), the bytes landing on LK
  come from `metadata` flash content (dual-use constraint), and the atf/atf_dram/tee
  bodies are **encrypted with efuse-derived keys** (~8.0 bits/byte entropy; keys reachable
  only via BROM, which is patched shut on trona). NOTE: on tungsten, whether tee/atf
  bodies are encrypted is unknown — tungsten's getprop shows the same `secure_cpu=1`, but
  see A.0: that property doesn't prove fuse state. **The copy-vs-authenticated-length
  equality question for tungsten's tee1 is a top-priority offline check.**

### A.4 amonet-koboreru: full test procedure + the guard generations

Repo: https://github.com/R0rt1z2/amonet-koboreru (MIT, Roger Ortiz + Ben Grisdale).

The prescribed vulnerability test (README): **"Amazon patched this around 2022, so recent
Preloaders are not vulnerable. You need to downgrade the Preloader to an older version
first. To check whether a given Preloader is affected, grep it for
`check_part_overlapped done`. If the string is there, it is most likely vulnerable."**

Bug mechanics (README, verbatim essence): MTK wraps partitions in a 512-byte header; the
header's size and load address are **not covered by the signature**, and the preloader
copies the image to the header's address **before** checking the signature. A TEE
sub-image with load address `0xFFFFFFFF` makes the preloader fall back to a default that
was never set (= 0); sized to reach past its own block-device struct. The
`check_part_overlapped` guard keeps a single `lk_region` and compares the header name
against a table of *partition* names (`lk`/`lk_a`/`lk_b`/`uboot`) while real headers carry
`LK` — "Nothing ever matches, so nothing ever claims a range"; naming your image `lk`
takes the early-return branch and the overlap test is never reached. The copy overwrites
the block-device struct's read method mid-transfer → next block read runs the payload →
EL3. The payload then patches the preloader in memory to accept unsigned DA/ATF/TEE,
clears RPMB anti-rollback counters, and loads the real LK from another partition; it lives
in flash (`tee1`) so it persists.

wjdob's `exploits/tools/preloader-audit.py` codifies the two known guard generations —
**run this verbatim against tungsten's preloader dump:**

- **Generation A** (koboreru-vulnerable): markers `check_part_overlapped done`,
  `lk_region`, `lk_a`, `lk_b`, `uboot`.
- **Generation B** (trona): marker `dram_buf overlap` — a real interval check
  (`end = dest + size`, intersect with `[g_dram_buf, g_dram_buf+0x9de40)`) but it protects
  exactly **one** interval; destinations outside it are unexamined.
- Both generations share the underlying defect: length (+ possibly destination) honored
  from an unsigned header, copied before verifying. Common markers: `Warning: LK out of
  boundary.`, `partition.c`, `atf_dram`.

Usage: `python preloader-audit.py tungsten-preloader.img` (also has `--selftest`).
**Nothing about MT8169/MT8186 preloaders is known publicly** — koboreru ships only
hardcoded 32-bit MT8163/MT8173-era targets (`biscuit, checkers, cronos, crown, crumpet,
cupcake, donut, douglas, radar, rook, sloane`); per-device SRAM constants like
`PAYLOAD_ADDR 0x00101000` / `BDEV_ADDR 0x00102DC0` would need re-derivation for MT8169
(trona's retraction notes warn that even MT8183's SRAM map differs: only SCP SRAM at
0x10500000 exists, and the preloader never references SRAM at all on that chip — check
this on tungsten rather than assuming).

### A.5 Additional trona findings that transfer as test items for tungsten

- **Full load/verify matrix** (trona): every image the preloader loads IS verified
  (lk/lk2 0x19d62; sspm; cam_vpu1/2/3; spmfw; atf/atf_dram/tee via 0x26034) — "no
  load-without-verify path." Build the same matrix for tungsten (androdidme's LK map shows
  dead `mt_part_*` strings; PL side unmapped).
- **LK authenticates *its* images with certificate chains**, not raw keys:
  `amzn_image_verify` 0x1238, two embedded roots ("Common Kernel Signing Production CA"
  LK 0x4746c / "…Engineering CA" 0x479c4), selected by `amzn_is_production_device()`
  0xe420 reading a platform-structure byte exported as `androidboot.prod`.
- **Failed `boot` verification is NOT fatal on trona**: LK displays "Please download %s
  image with correct signature", waits 5 s, returns -1 — with LK/fastboot still running
  (categorically safer than an `lk` write; S1 vs S2). Verify tungsten's LK behaves the
  same before any experiment; and note locked-device fastboot on trona is a strict
  **denylist at dispatch** (resolved at LK VA 0x56083680; `boot`/`verify`/`env`/
  `ultraflash` not even registered; `download:` allowed but size-validated into a fixed
  128 MiB buffer at 0x56900000 — no overflow).
- **`oem relock` is a trap**: gate-allowed while locked, randomizes IDME
  `unlock_version` and clears `unlock_code` — NEVER run it (destroys the device's
  unlock-request binding).
- **Temp-unlock audit (lead L10)**: `flash:tucert`/`flash:tucode` are gate-ALLOWED on the
  locked device and write IDME `t_unlock_cert`/`t_unlock_code` with **length checks only**
  (the only unauthenticated persistent write found); the reader path still ends in an RSA
  check (different key), persistence is one boot and LK-only, and the verifier's
  reachability on a provisioned unit is an open sub-question (gated on a list count fed by
  an unidentified IDME variable). **Untested on tungsten — a concrete, low-risk probe
  (writes fail safe per code reading: "failure clears both IDME fields"; still, treat any
  IDME write as R3+ until confirmed).**
- **Unlock-code replay is impossible**: the signed request string
  `'0x'+%08x(id13)+%08x(id12)+%08x(unlock_version)` binds to per-chip HRID (devinfo
  indices 12/13 = `get_hrid()`, runtime eFuse reads — no literals in images).
- **PSS verifier audit**: 17/17 RFC 8017 §9.1.2 checks present (incl. the top-bit check);
  Unicorn harness on the real preloader code: genuine LK signature accepted (positive
  control), 1,000,000 random signatures → 0 accepts. Forging is out; don't fuzz hoping.
- **GhostLock/CVE-2026-43499 correction (trona 4.4 kernel)**: an earlier pass declared the
  CVE absent on 4.4 because it audited the wrong symbols; the corrected finding is that
  the vulnerable pattern (`kernel/locking/rtmutex.c:1079-1090`, `current->pi_lock`/
  `pi_blocked_on` misuse) IS present and the fix only shipped in v7.1 — consistent with
  tungsten (5.4.86) being exploitable, as we proved.
- Tooling worth reusing for tungsten: `preloader-audit.py` (guard generation),
  `verify-lk-signature.py` (signed-region proof), `verify-tee-signature.py` (outer vs
  inner length), `pl-cfg.py` / `pl-xref.py` (branch+computed-ref and string xref;
  alignment-independent, handles T1/Thumb-2 ldr forms, word-scaled immediates),
  `verify-lk-image.py` / `walk-mtk-container.py` (used for the amonet-trona artifact
  analysis).
