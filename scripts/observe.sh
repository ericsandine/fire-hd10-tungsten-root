#!/bin/bash
# Usage: ./observe.sh [extra env string for preload]
ENVS="$1"
adb wait-for-device 2>/dev/null
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
sleep 5
adb shell "pkill -f ghostlock.stage 2>/dev/null; pkill -f /data/local/tmp/preload 2>/dev/null; sleep 1; rm -f /data/local/tmp/ghostlock.log /data/local/tmp/ghostlock.proof /data/local/tmp/ghostlock.stage"
adb push "${PRELOAD:-$(dirname "$0")/../GhostLock/build/tungsten/bin/preload}" /data/local/tmp/preload >/dev/null
adb shell "chmod 755 /data/local/tmp/preload; $ENVS nohup /data/local/tmp/preload > /data/local/tmp/ghostlock.log 2>&1 &"
echo "launched $(date +%T) envs=[$ENVS]"
dropped=0
for i in $(seq 1 40); do
  sleep 5
  state=$(adb get-state 2>/dev/null)
  lines=$(adb shell 'wc -l < /data/local/tmp/ghostlock.log' 2>/dev/null | tr -d '\r')
  echo "t+$((i*5))s state=$state loglines=$lines"
  if [ "$state" != "device" ]; then dropped=1; echo "DEVICE DROPPED at t+$((i*5))s (panic)"; break; fi
  if adb shell 'test -f /data/local/tmp/ghostlock.proof' 2>/dev/null; then echo "PROOF EXISTS"; break; fi
done
if [ "$dropped" = 1 ]; then
  echo "=== waiting for reboot, then pulling log ==="
  adb wait-for-device 2>/dev/null
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
fi
echo "=== FINAL LOG ==="
adb shell 'cat /data/local/tmp/ghostlock.log' 2>/dev/null | tail -40
echo "=== PROOF ==="
adb shell 'cat /data/local/tmp/ghostlock.proof' 2>/dev/null
