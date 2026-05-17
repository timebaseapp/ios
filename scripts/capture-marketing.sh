#!/usr/bin/env bash
# Builds Timebase in Debug for the simulator, then launches it twice
# (light + dark) with -MarketingCapture 1 so MarketingCapture.swift
# walks its step list. Pulls the resulting PNGs out via simctl into
# ./marketing/<appearance>/.

set -euo pipefail

DEVICE="iPhone 17 Pro"
BUNDLE_ID="cc.timebase.ios"
SCHEME="Timebase"
PROJECT="Timebase.xcodeproj"
OUT_DIR="marketing"

cd "$(dirname "$0")/.."

echo "==> xcodegen generate"
xcodegen generate >/dev/null

echo "==> Booting simulator: $DEVICE"
SIM_UDID=$(xcrun simctl list devices available | grep -E "^\s*$DEVICE \(" | head -1 | awk -F '[()]' '{print $2}')
if [ -z "$SIM_UDID" ]; then
    echo "ERROR: simulator '$DEVICE' not found. Run: xcrun simctl list devices available"
    exit 1
fi
xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID"

echo "==> Building for simulator"
DERIVED="$(pwd)/build/derived"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    build >/dev/null

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/Timebase.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: app not found at $APP_PATH"
    exit 1
fi

echo "==> Installing $APP_PATH"
xcrun simctl install "$SIM_UDID" "$APP_PATH"

# Reset content if you want a guaranteed clean slate. We don't reset to
# preserve any user state — marketing seed overrides everything anyway.

mkdir -p "$OUT_DIR"

run_locale() {
    local appearance="$1"
    echo ""
    echo "==> Launching ($appearance)"
    # Set the simulator's appearance before launch
    xcrun simctl ui "$SIM_UDID" appearance "$appearance"
    xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true

    # Clear stale marketing output in the sandbox so the sentinel-check
    # below actually waits for THIS run, not the last one.
    CONTAINER=$(xcrun simctl get_app_container "$SIM_UDID" "$BUNDLE_ID" data 2>/dev/null || echo "")
    if [ -n "$CONTAINER" ]; then
        rm -rf "$CONTAINER/Documents/marketing/$appearance"
    fi

    xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" \
        -MarketingCapture 1 \
        -MarketingAppearance "$appearance"

    # Wait for the sentinel file inside the app sandbox
    CONTAINER=$(xcrun simctl get_app_container "$SIM_UDID" "$BUNDLE_ID" data)
    SENTINEL="$CONTAINER/Documents/marketing/$appearance/_done"
    echo "  waiting on $SENTINEL"
    for i in $(seq 1 60); do
        if [ -f "$SENTINEL" ]; then
            echo "  sentinel reached after ${i}s"
            break
        fi
        sleep 1
    done
    if [ ! -f "$SENTINEL" ]; then
        echo "ERROR: capture timed out for $appearance"
        exit 1
    fi

    # Pull the captures out of the sandbox into ./marketing/<appearance>/
    rm -rf "$OUT_DIR/$appearance"
    cp -R "$CONTAINER/Documents/marketing/$appearance" "$OUT_DIR/$appearance"
    echo "  pulled to $OUT_DIR/$appearance"
}

run_locale light
run_locale dark

echo ""
echo "✓ Marketing capture complete."
echo "  Output: $OUT_DIR/{light,dark}/"
ls -la "$OUT_DIR/light" 2>/dev/null
ls -la "$OUT_DIR/dark" 2>/dev/null
