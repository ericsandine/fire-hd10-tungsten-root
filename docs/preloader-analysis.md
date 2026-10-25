# Tungsten preloader analysis (device-dump/mmcblk0boot0.bin, MT8186 PL)

Status: cut short at stop condition (device confirmed secure-fused via /proc/pl_lk).
Tooling: derive/pl.py (PIC xref + BL index for the preloader; caches
/tmp/plrefs.pkl, /tmp/plbls.pkl), derive/plref.py (per-function ref resolver).
Conventions verified against Main's proof (AMZN_PL_VERIFY @0x37d33 refs at
0x1a28/0x1b30/0x1bb4/0x1be6/0x1c5c — reproduced).

## Q2 — LK signature coverage (kaeru relevance): **header UNSIGNED, body signed**

Verify chain (all disasm-verified):

```
boot path 0x228xx  →  verify_lk wrapper 0x1d2c   (also: sspm 0x1d58,
                                                     spmfw 0x1d84, lk_main_dtb 0x1db0)
  → amzn_pl_verify_image_maybe 0x1af4(name="lk", data=load_addr, size=m_size, ctx)
      - locates version magic "_LK_VER:" at data+size-0x10a (strlen 8 + 2-byte
        version at data+size-0x102) — memcmp at 0x1b86
      - 0x1bc2: amzn_pl_verify(0x19e0)(data, len = size - 0x100,
                                      sig = data + size - 0x100, siglen=0x100, …)
  → amzn_pl_verify 0x19e0: RSA-2048 public-key decryption (0x346c4)
      → HW SHA-256 over data (0x347bc) → PSS decode/verify (0x33d6e region)
```

- **Signed/hashed range: image body only** — the loader (0x29d64) reads the
  0x200-byte boot header into a *scratch* buffer (parse via 0x29b54, magic
  0x58881688 checked), then reads **m_size bytes from partition_offset + 0x200
  into load_addr** (emmc read @ 0x2a128: size = [hdr+4] = m_size,
  dst = resolved load addr). The verify then covers
  `[load_addr, load_addr + m_size − 0x100)`.
  → **lk partition bytes [0x200, 0x200 + m_size − 0x100) are signed; the first
    0x200 bytes (boot header) are NOT covered by the signature.**
- Trailer layout confirmed against the live dump (lk.img): m_size = 0x173a10,
  `_LK_VER:` at file 0x173b06, version u16 `00 02` at 0x173b0e, 256-byte RSA
  signature at file 0x173b10 (= 0x200 + m_size − 0x100) ✓ exact match with the
  PL's computed offsets.
- Header fields consumed BEFORE/OUTSIDE verification (0x29b54):
  [hdr+4] m_size, [hdr+0x28] m_load_addr, [hdr+0x2c] (second field).
  On this device both address fields are **0xFFFFFFFF → fallback to default
  0x4C400000** (fallback constant seen at [0x22b24] in the boot function).
- m_load_addr is range-checked at 0x22a5c-0x22a6c: must satisfy
  addr > 0x4C3FFFFF and addr+size ≤ 0x4CD00000 (else error, no boot).
- LK itself links at 0x4C3FFE00 (file 0) = 0x4C400000 (body, file 0x200) —
  consistent with the default load address.
- tee1/boot images: not reached in this pass (the four AMZN_PL_VERIFY wrappers
  cover lk/sspm/spmfw/lk_main_dtb only; tee1 path not traced).

## Q1 — lock master_byte provenance: INCONCLUSIVE (stopped)

What was established:
- LK's is_locked master byte lives in a heap "device info" context struct built
  from the PL handoff (sibling getvar fields: pl_build_date,
  pl_build_top_commit_id, sbc_enabled, prod_dev, daa_enabled, rpmb_state,
  antirback_{lk,pl,tee}_version). Only ever read in LK (7 sites, all ldrb).
- PL side: sec.c init (0x2f3c0 area) reads flash partition **"seccfg"**
  (0x2000 bytes) and a partition named **"efuse"**; an eFuse driver touches
  literal base 0x1000a000 (code @0x34274/0x34be4/0x34c58) and 0x10210000
  (@0x34da8+). SEJ 0x10009000 / GCPU 0x10241000 literals did NOT appear in this
  PL image. SEC_CFG register address for MT8169: not identified in this pass.
- PL has its own SBC image-verify (0x33a04, "[SBC] Verification Pass/Fail") and
  the prod/dev split log in amzn_pl_verify_image_maybe ("Succeed to verify %s
  with prod key", "secure SoC should run signed %s" vs "non secure SoC run with
  unsigned %s" @0x1c5e/0x1c70).
- **The PL secure-SoC decision: `is_secure_soc` @ 0x36b54 = bit 1 of the 32-bit
  register at physical address 0x11CB0060** (adjacent getter 0x36b64 = bit 2 of
  the same register). verify_image_maybe calls it at 0x1c52: secure (bit set) →
  unsigned image = hard fail; non-secure → log and boot anyway. This register
  (0x11CB0060, security/fuse-status block) is the MT8169 fuse mirror — not
  flash-writable. (Note: "SEC_CFG" as a *register* name didn't appear; the only
  "seccfg" here is the flash partition read by sec.c init.)
- Per Main's device log this unit is production/secure-fused, so the byte is 1
  and the unlock question is moot. Whether the byte's PL-side computation reads
  seccfg (writable) vs eFuse was NOT resolved — the handoff struct construction
  site was not located before the stop.
