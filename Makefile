# Distracted? (分心了么) — Makefile
# Build, sign, and run entirely from command line.
# No Xcode project required.

APP_NAME          := Distracted
BUNDLE_ID         := com.distracted.app
BUILD_DIR         := build
APP_BUNDLE        := $(BUILD_DIR)/$(APP_NAME).app
APP_BUNDLE_PATH   := $(APP_BUNDLE)
BUNDLE_RESOURCES  := $(APP_BUNDLE_PATH)/Contents/Resources
SWIFT_FLAGS       := -target arm64-apple-macos14.0 -framework AppKit -framework ServiceManagement -O -whole-module-optimization

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
ASSET_IMAGES        := Resources/logo.png Resources/menubar.png Resources/menubar@2x.png
LOGO_PNG            := Resources/logo.png
MENUBAR_PNG         := Resources/menubar.png
MENUBAR_2X_PNG      := Resources/menubar@2x.png
ICONSET_DIR         := $(BUILD_DIR)/AppIcon.iconset
APP_ICON_ICNS       := $(BUNDLE_RESOURCES)/AppIcon.icns

.PHONY: all build clean run bundle-icons

all: build

# ── App icon: logo.png → AppIcon.icns inside the .app bundle ─
# Rebuilds whenever logo.png changes; iconset is regenerated each time.
bundle-icons: $(APP_ICON_ICNS)

$(APP_ICON_ICNS): $(LOGO_PNG)
	@mkdir -p $(BUNDLE_RESOURCES)
	rm -f $(APP_ICON_ICNS)
	rm -rf $(ICONSET_DIR)
	mkdir -p $(ICONSET_DIR)
	sips -z 16 16     $(LOGO_PNG) --out $(ICONSET_DIR)/icon_16x16.png
	sips -z 32 32     $(LOGO_PNG) --out $(ICONSET_DIR)/icon_16x16@2x.png
	sips -z 32 32     $(LOGO_PNG) --out $(ICONSET_DIR)/icon_32x32.png
	sips -z 64 64     $(LOGO_PNG) --out $(ICONSET_DIR)/icon_32x32@2x.png
	sips -z 128 128   $(LOGO_PNG) --out $(ICONSET_DIR)/icon_128x128.png
	sips -z 256 256   $(LOGO_PNG) --out $(ICONSET_DIR)/icon_128x128@2x.png
	sips -z 256 256   $(LOGO_PNG) --out $(ICONSET_DIR)/icon_256x256.png
	sips -z 512 512   $(LOGO_PNG) --out $(ICONSET_DIR)/icon_256x256@2x.png
	sips -z 512 512   $(LOGO_PNG) --out $(ICONSET_DIR)/icon_512x512.png
	sips -z 1024 1024 $(LOGO_PNG) --out $(ICONSET_DIR)/icon_512x512@2x.png
	iconutil -c icns $(ICONSET_DIR) -o $(APP_ICON_ICNS)

# ── Build .app bundle ──────────────────────────────────────────
build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Info.plist $(LOCALIZED_RESOURCES) $(ASSET_IMAGES)
	@mkdir -p $(APP_BUNDLE_PATH)/Contents/MacOS
	@mkdir -p $(BUNDLE_RESOURCES)
	$(MAKE) bundle-icons
	rm -f $(BUNDLE_RESOURCES)/menubar.png $(BUNDLE_RESOURCES)/menubar@2x.png
	cp -f $(MENUBAR_PNG) $(BUNDLE_RESOURCES)/menubar.png
	cp -f $(MENUBAR_2X_PNG) $(BUNDLE_RESOURCES)/menubar@2x.png
	swiftc $(SOURCES) $(SWIFT_FLAGS) -o $(APP_BUNDLE_PATH)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_BUNDLE_PATH)/Contents/
	rm -rf $(BUNDLE_RESOURCES)/*.lproj
	cp -R Resources/*.lproj $(BUNDLE_RESOURCES)/
	@test -f $(APP_ICON_ICNS) || (echo "error: $(APP_ICON_ICNS) missing" && exit 1)
	@echo "==> Signing with ad-hoc identity…"
	codesign --force --deep --sign - $(APP_BUNDLE_PATH)
	@echo "✓  $(APP_BUNDLE_PATH) built successfully"

# ── Run ────────────────────────────────────────────────────────
run: build
	@echo "==> Launching $(APP_NAME)…"
	open $(APP_BUNDLE_PATH)

# ── Clean ──────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR)
	@echo "✓  clean"
