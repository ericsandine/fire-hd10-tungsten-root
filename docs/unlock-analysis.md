# Tungsten LK bootloader-unlock analysis (device-dump/lk.img, live 3MB dump)

Image: MT8186 LK (ARM32 Thumb-2, fully PIC). Verified conventions:
- Link/runtime base **B = 0x4C3FFE00** (solved from the fastboot name table:
  9/11 command-name string pointers hit at B; "flash:unlock" = 0x4C45BE6E ✓ matches
  the expected 0x4C45xxxx range).
- PIC refs: `ldr rT,[pc,#imm]` (literal base = (addr+4)&~3) followed by
  `add rT, pc` where **PC = addr+4 unaligned** (verified against known strings).
- BL targets are file offsets. Analysis tooling: derive/lk.py (PIC xref scanner),
  derive/lkref.py (per-function ref resolver), BL index /tmp/lkbls.pkl.

## 1. The unlock decision (Q1)

Core state function — **is_locked() @ 0xc0bc**:

```
is_locked():                              ; file 0xc0bc
    if (master_lock_byte() != 1)          ; 0xc800: returns (*(**0x17372c) + 0x5a49) != 0
        return 0;                         ;   -> NOT locked at all
    if (unlock_code_valid())              ; 0x1158
        return 0;                         ;   -> permanently unlocked
    return !temp_unlock_active();         ; 0x16bc: t_unlock_* present+valid
```

**unlock_code_valid() @ 0x1158**: idme_read("unlock_code", buf, 0x100) [0x474];
if read OK → returns (amzn_verify_unlock(buf, 0x100) == 0). [0x1354]

**amzn_verify_unlock() @ 0x1354** (named by its own log strings):
- key = **0xc9ac()** → returns ptr to embedded pubkey blob @ file **0x5c41e**,
  sets keylen = 0x126 (294). Blob at 0x5c420 parses as **X.509 SPKI RSA-2048,
  e=65537**, modulus starts df3aad17 29687b27 818cdc86 ce6ec4b4…
- message = **0xc984()** → formats the unlock_version value via 0xc81c
  (hex-format helper) — i.e. the signed payload is derived from the idme
  "unlock_version" value (device-specific random nonce).
- 0x11b0(msg, msglen, sig = unlock_code (256 B), siglen = 0x100, key, 294)
  → generic crypto wrapper (ops table at global, mallocs, 0xa568 = bignum/rsa
  step, error strings "…signature length error, wrong signature file?…").
  RSA-2048/SHA-256-style verify; exact padding detail doesn't affect the verdict.

**temp_unlock_active() @ 0x16bc**: reads t_unlock_code/t_unlock_cert via
0x15ec (malloc'd, from idme), verifies via 0x1714 = amzn_verify_temp_unlock_code
(same 0x11b0 primitive; its own cert/code logic). Also signature-based.

**unlock status reporter @ 0xc9c0** (callers: boot-props builder 0xca04,
"UNLOCK STATUS" printer @0x29fc4, AVB boot fn 0x503ce, handlers): 
state = unlock_code_valid() | temp_unlock_active(); if master_lock_byte()==0 →
state |= 1; caches "true"/"false" into global string @0x17d438; returns state.
This is the inverse of is_locked().

### Consumers of the decision
- **Fastboot command gate @ 0x2a9a4** → gate fn **0xc0e0** (only caller: 0x2a99e):
  ```
  if (!is_locked())                       -> allow all
  if (cmd in ALWAYS5)                     -> allow   # {"oem relock","oem flags",
                                           #   "flash:unlock","flash:tucert","flash:tucode"}
                                           #   array @ file 0xcc80c (abs ptrs)
  if (cmd in dynlist1)                    -> allow   # 0xd724()
  if (cmd in RESTRICTED9)                 -> deny    # {"verify","dump","boot","env",
                                           #   "signature","oem","reboot-recovery",
                                           #   "flash","erase"} array @ 0xcc820
  if (cmd in dynlist2)                    -> deny    # 0xd738()
  else                                    -> allow
  ```
  Deny → prints "the command you input is restricted on locked hw" (0xb93b8).
- **Per-command second gate** at 0x4a298 / 0x4a46a (strncmp name → is_locked()).
- **Boot/AVB path @ ~0x50300**: reads seccfg partition (0x200 B, @0x50426), reads
  master byte ([P2+0x5a49] @0x5080c: !=1 → skip unlock processing), then
  is_locked() @0x50344 / unlock-status @0x503ce → sets verifiedbootstate
  (strings "androidboot.verifiedbootstate=orange|yellow|green" @0xc0f03..) and
  "androidboot.unlocked_kernel=%s" (@0xb8d6d, built @0x2a01e).
- **Boot cmdline props @ 0xca04** (one-shot, flag @0x17d434): appends
  ("unlock_code", hex(unlock_version)), ("unlock_status", "true"/"false"),
  ("tu_code", …) to the boot-properties list (0x2a5ac = append (name,value)).

## 2. Q2 — boot-time re-verification? **YES, every time, no caching.**

is_locked()/status are recomputed from scratch on every call: idme is re-read and
**amzn_verify_unlock re-verifies the RSA signature on every evaluation** (LK runs
per boot; no "trusted once" flag exists — the only one-shot flag (@0x17d434) merely
suppresses rebuilding cmdline strings). A root-written unlock_code without a valid
signature simply fails verification → device stays locked.

## 3. Q3 — dev_flags / usr_flags / fos_flags

- Setter: "oem flags" command handler @ 0xc616 (jump table over
  dev_flags/usr_flags/fos_flags names; reads via 0x474, applies set/clear, writes
  via 0x408). Gated by **0xc27c()** (same is_locked logic: master byte==1 &&
  !unlock_code && !temp_unlock) — on a locked device "Only usr_flags can be set"
  (string @0x5c12c).
- Reader: **amzn_get_flag64(type, mask) @ 0xd2fa**: reads dev_flags (type 2) /
  fos_flags idme var, and the result is `((val & mask) == mask) && !is_locked()`
  (@0xd35e). So flags are **inert while locked** — e.g. "[DM-VERITY] verify off by
  fos_flags" (0x9df5f) only takes effect once unlocked. Not an unlock bypass.

## 4. Q4 — "flash:unlock" handler path

Dispatcher @ 0x2f2e0 (flash: subcommands; "unlock" tail →):
**amzn_set_unlock_code(data, len) @ 0xca98**:
1. len must be > 0xFF else fail.
2. amzn_verify_unlock(data, 0x100) — RSA-2048 verify of the 256-byte blob against
   the embedded pubkey over the unlock_version-derived message. Fail →
   "unlock signature verify failed, do nothing!" (0x5c275), no write.
3. Success → **idme_write("unlock_code", data, 0x100)** — the ONLY idme write —
   then refresh state (0xc9c0) and fastboot OK. (If the write itself fails:
   "correct signature, but update idme failed".)

"flash:tucert"/"flash:tucode" → 0xcaf8/0xcb80 area: write t_unlock_cert /
t_unlock_code (with their own verification; "write tucert/tucode failed!").

"oem relock" @ ~0xc8f8: clears temp-unlock (0x168c), optionally regenerates
unlock_version (random, nonzero, first byte != '0' semantics) unless keep-version,
**clears unlock_code (idme_write len 0)**, sets status "false".

Replication of the write set without the signature is useless: the stored
unlock_code is re-verified at every boot/eval (§2).

## 5. Q5 — Verdict

**Unlock via idme edits alone: NOT possible.** The decision is:

```
locked = (master_byte==1) && !RSA_verify(unlock_code over unlock_version,
                                          embedded Amazon RSA-2048 pubkey)
                            && !temp_unlock_cert_valid
```

- unlock_code forgery → requires Amazon's RSA-2048 private key. Infeasible.
- unlock_version is the *challenge*, not the unlock — editing it changes nothing
  (it is only regenerated by LK when empty/'0…').
- t_unlock_* → separate signed cert path (same primitive). Infeasible.
- dev_flags/fos_flags → gated by is_locked() (§3). Inert.
- Boot-time: no cached trust; every path re-verifies.

### The one open thread: master_lock_byte (P2 + 0x5a49)

is_locked() short-circuits to "unlocked" if this byte != 1. Facts:
- Read as `*(*(file 0x17372c)) + 0x5a49` (0xc800); the global @0x17372c is baked
  in the image = 0x4C65BF88 (a BSS slot, file 0x25c188 — zero in the dump;
  runtime heap pointer P2).
- **Never written by any LK code** — all 6 sites using offsets 0x5a48/0x5a49
  (0xc802, 0xcb82, 0x29f9e, 0x2aad0, 0x2ab1c, 0x2b338, 0x5080c) are `ldrb` reads.
- The enclosing struct carries the preloader handoff fields: "pl_build_date",
  "pl_build_top_commit_id", "sbc_enabled", "prod_dev", "daa_enabled",
  "rpmb_state", "antirback_{lk,pl,tee}_version" (status fn @0x2aa74). So the byte
  is almost certainly **eFuse/PL-derived (secure-boot fused state)** and not
  changeable by root — but this needs one runtime probe to confirm (the page is
  heap, not covered by the lk partition dump):

Probe (on the rooted device, via the GhostLock arbitrary read or a kmem tool):
```
P1 = *(u32 *)0x4C41352C        /* LK global (file 0x17372c) */
P2 = *(u32 *)P1
byte = *(u8 *)(P2 + 0x5A49)    /* expect 1 on this locked retail unit */
also dump P2+0x5A40..0x5A50 and seccfg partition for correlation
```
If that byte ever reads 0 (or a writable partition — seccfg/boot_para — is found
to feed it), the whole signature scheme is bypassed: set it once →
is_locked()==0 forever → fastboot fully open + AVB orange. If it's fused
(sbc/efuse), the conclusion stands: **cryptographically impossible without
Amazon's unlock-signing key**.

### idme commands worth knowing (none unlock)
- `idme unlock_code clear` / relock-equivalent; `idme unlock_version <8 hex>` is
  harmless (challenge value). Neither grants unlock.
- The legitimately unlockable path on-device would be: read unlock_version
  (`idme print`), get a 256-byte RSA-2048 signature over the derived message from
  Amazon, `fastboot flash unlock <sigfile>` (allowed even when locked).

## Appendix — function map (file offsets)

| addr   | meaning |
|--------|---------|
| 0xc0bc | is_locked() |
| 0xc800 | master_lock_byte(): *(*(0x17372c))+0x5a49 != 0 |
| 0x1158 | unlock_code_valid(): idme read + amzn_verify_unlock |
| 0x1354 | amzn_verify_unlock(sig256) — RSA-2048 verify |
| 0xc9ac | returns embedded pubkey @0x5c41e (SPKI RSA-2048, len 294 @0x5c420) |
| 0xc984 | build signed message from unlock_version |
| 0x11b0 | crypto verify primitive (also used by temp-unlock) |
| 0x16bc | temp_unlock_active(): t_unlock_code/t_unlock_cert |
| 0x1714 | amzn_verify_temp_unlock_code |
| 0xc848 | unlock_version get-or-generate (PRNG 0x499f4, idme R 0x474 / W 0x408) |
| 0xc9c0 | unlock status ("true"/"false" cached @0x17d438) |
| 0xc0e0 | fastboot command gate (allow/deny lists) |
| 0xc27c | is_locked twin (used by "oem flags") |
| 0xc616 | "oem flags" setter (dev/usr/fos_flags) |
| 0xd2fa | flag reader: (val&mask)==mask && !is_locked() |
| 0xca04 | boot cmdline props (unlock_code/unlock_status/tu_code) |
| 0xca98 | flash:unlock handler (verify + idme_write unlock_code) |
| 0xcaf8 | flash:tucert/tucode handler |
| 0xc8f8 | "oem relock" handler |
| 0x2f2e0 | flash: subcommand dispatcher |
| 0x474  | idme_read hook · 0x408 idme_write hook · 0x341ae strcpy · 0x33318 print · 0x3420c strlen · 0x34158 strncmp · 0x34192 prefix-match |
