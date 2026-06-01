# Distracted? (分心了么) — Makefile
# Build, sign, and run entirely from command line.
# No Xcode project required.

APP_NAME     := Distracted
BUNDLE_ID    := com.distracted.app
BUILD_DIR    := build
APP_BUNDLE   := $(BUILD_DIR)/$(APP_NAME).app
SWIFT_FLAGS  := -target arm64-apple-macos14.0 -framework AppKit -O -whole-module-optimization

SOURCES := \
	Sources/main.swift \
	Sources/AppDelegate.swift \
	Sources/Utils/Constants.swift \
	Sources/MenuBar/StatusBarController.swift \
	Sources/Overlay/TimeOverlayWindow.swift \
	Sources/Timer/TimerService.swift

.PHONY: all build clean run

all: build

# ── Build .app bundle ──────────────────────────────────────────
build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Info.plist
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	swiftc $(SOURCES) $(SWIFT_FLAGS) -o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/
	@echo "==> Signing with ad-hoc identity…"
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "✓  $(APP_BUNDLE) built successfully"

# ── Run ────────────────────────────────────────────────────────
run: build
	@echo "==> Launching $(APP_NAME)…"
	open $(APP_BUNDLE)

# ── Clean ──────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR)
	@echo "✓  clean"
