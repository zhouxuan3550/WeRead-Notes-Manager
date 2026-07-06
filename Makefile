# Makefile for 树懒书摘 (WeReadNotesManager)
# Usage:
#   make build      # swift build
#   make test       # swift test
#   make run        # swift run
#   make app        # build .app bundle (unsigned, for local testing)
#   make dmg        # build signed/unsigned .dmg (set SIGNING_IDENTITY for signed)

APP_NAME      := 树懒书摘
EXEC_NAME     := WeReadNotesManager
SCHEME        := WeReadNotesManager
BUILD_DIR     := .build/release
APP_BUNDLE    := $(BUILD_DIR)/$(APP_NAME).app
DMG_PATH      := $(BUILD_DIR)/$(APP_NAME).dmg

# Optional: set your Apple Developer ID for signed builds
# SIGNING_IDENTITY ?= "Developer ID Application: Your Name (TEAM_ID)"
SIGNING_IDENTITY ?=

.PHONY: build test run clean app dmg

build:
	swift build -c release

test:
	swift test

run:
	swift run $(EXEC_NAME)

clean:
	rm -rf .build/release
	rm -rf .build/debug

app: build
	@echo "Building $(APP_NAME).app..."
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp .build/release/$(EXEC_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	cp Sources/WeReadNotesManager/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/" 2>/dev/null || true
	cp Info.plist "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@echo "Done: $(APP_BUNDLE)"

dmg: app
	@echo "Creating DMG..."
	mkdir -p $(BUILD_DIR)/dmg-staging
	cp -R "$(APP_BUNDLE)" $(BUILD_DIR)/dmg-staging/
ifdef SIGNING_IDENTITY
	codesign --force --deep --sign "$(SIGNING_IDENTITY)" $(BUILD_DIR)/dmg-staging/$(APP_NAME).app
endif
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(BUILD_DIR)/dmg-staging -ov "$(DMG_PATH)"
	@echo "Done: $(DMG_PATH)"
