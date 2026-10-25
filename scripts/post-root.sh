#!/bin/sh
# Post-root: verify + dump safety-critical partitions to ./device-dump/
set -e
cd "$(dirname "$0")"
mkdir -p device-dump

echo "[*] verifying root"
adb shell 'su -c id' || { echo "NO ROOT"; exit 1; }

echo "[*] dumping boot0 (idme+preloader), boot1, lk, boot, vbmeta, tee1, tee2, vendor_boot, dtbo, misc, boot_para"
adb shell 'su -c "
for src in /dev/block/mmcblk0boot0 /dev/block/mmcblk0boot1; do
  name=\$(basename \$src)
  dd if=\$src of=/data/local/tmp/\$name.bin bs=4096 2>/dev/null
done
for p in lk boot vbmeta tee1 tee2 vendor_boot dtbo misc boot_para nvcfg; do
  dd if=/dev/block/by-name/\$p of=/data/local/tmp/\$p.img bs=4096 2>/dev/null
done
chmod 644 /data/local/tmp/*.bin /data/local/tmp/*.img
"'

for f in mmcblk0boot0.bin mmcblk0boot1.bin lk.img boot.img vbmeta.img tee1.img tee2.img vendor_boot.img dtbo.img misc.img boot_para.img nvcfg.img; do
  adb pull "/data/local/tmp/$f" "device-dump/$f" >/dev/null 2>&1 && echo "  got $f ($(stat -f%z device-dump/$f 2>/dev/null) bytes)" || echo "  MISS $f"
done

echo "[*] idme via idme tool if present"
adb shell 'su -c "idme print 2>/dev/null || idme dump 2>/dev/null || true"' | tee device-dump/idme.txt
echo "[*] done"
