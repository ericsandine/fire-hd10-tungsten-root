#!/bin/bash
# Dashboard setup — run while the tablet is rooted (post-GhostLock).
set -e
cd "$(dirname "$0")"
SU='/data/local/tmp/su -c'
HA_URL="${HA_URL:-http://YOUR-HA-HOST:8123}"   # override: HA_URL=http://x:8123 ./dash-setup.sh

echo "[*] root check"
adb shell "/data/local/tmp/su -c id" | grep -q "uid=0" || { echo "NO ROOT — run exploit first"; exit 1; }

echo "[*] wifi connect"
adb shell "/data/local/tmp/su -c 'cmd wifi connect-network 0 auto 2>/dev/null; svc wifi enable'" || true
sleep 4
adb shell "ping -c 2 -W 3 ${HA_URL#http://} | tail -1" 2>/dev/null | grep -v :8123 || echo "WARN: HA unreachable"

echo "[*] installing Fully Kiosk"
adb install -r fully-kiosk.apk

echo "[*] debloat (safe set: ads/media/commerce; keeps launcher/keyboard/settings/systemui)"
BLOAT="
com.amazon.kindle.kso
com.amazon.dee.app
com.amazon.mp3
com.amazon.avod
com.amazon.photos
com.amazon.tahoe
com.amazon.gamehub
com.amazon.alexa.youtube
com.amazon.docs
com.amazon.email
com.amazon.calendar
com.amazon.contacts
com.amazon.social
com.amazon.storm
com.amazon.tmm
com.amazon.website
com.amazon.zest
com.amazon.birch
com.amazon.cloud9
com.amazon.alta.horizons
com.amazon.comics
com.amazon.audible
"
for p in $BLOAT; do
  adb shell "/data/local/tmp/su -c 'pm disable-user --user 0 $p'" >/dev/null 2>&1 || true
done
adb shell "/data/local/tmp/su -c 'pm list packages -d'" | sort

echo "[*] screen/behavior settings"
adb shell "/data/local/tmp/su -c '
settings put global stay_on_while_plugged_in 7
settings put system screen_off_timeout 2147483647
settings put system screen_brightness 128
'" || true

echo "[*] set launcher to Fully Kiosk"
adb shell "/data/local/tmp/su -c 'cmd package set-home-activity de.ozerov.fully/.MainActivity'" || \
  echo "WARN: set-home-activity failed; will do in-app"

echo "[*] done — now configure Fully Kiosk prefs"
