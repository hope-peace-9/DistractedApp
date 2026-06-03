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
	Sources/Localization/L10n.swift \
	Sources/Preferences/PreferencesStore.swift \
	Sources/State/AppStateCoordinator.swift \
	Sources/MenuBar/StatusBarController.swift \
	Sources/Settings/SettingsDraft.swift \
	Sources/Settings/SettingsWindowController.swift \
	Sources/Overlay/TimeOverlayWindow.swift \
	Sources/Timer/TimerService.swift

LOCALIZED_RESOURCES := $(wildcard Resources/*.lproj/Localizable.strings)

.PHONY: all build clean run

all: build

# ── Build .app bundle ──────────────────────────────────────────
build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Info.plist $(LOCALIZED_RESOURCES)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	swiftc $(SOURCES) $(SWIFT_FLAGS) -o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE)/Contents/
	rm -rf $(APP_BUNDLE)/Contents/Resources/*.lproj
	cp -R Resources/*.lproj $(APP_BUNDLE)/Contents/Resources/
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
