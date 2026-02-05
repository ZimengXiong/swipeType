.PHONY: build-website serve build-mac dmg-mac mac-run release clean sync-version bump-build

# Paths
VERSION_FILE := VERSION
BUILD_NUMBER_FILE := BUILD_NUMBER
MAC_APP_DIR := apps/mac
RUST_SRC := crates/swipe-engine
RUST_TARGET := aarch64-apple-darwin
RUST_LIB_NAME := libswipe_engine.a

# --- Website ---
build-website:
	cd apps/web && wasm-pack build --target web
	mkdir -p build
	cp apps/web/pkg/swipe_web.js apps/web/pkg/swipe_web_bg.wasm build/
	cp apps/web/www/index.html build/

serve: build-website
	cd build && python3 -m http.server 8000

# --- Versioning ---
sync-version:
	./scripts/sync_version.sh

bump-build:
	@if [ -f $(BUILD_NUMBER_FILE) ]; then \
		BUILD=$$(cat $(BUILD_NUMBER_FILE) | tr -d '[:space:]'); \
		NEW_BUILD=$$(($$BUILD + 1)); \
		echo $$NEW_BUILD > $(BUILD_NUMBER_FILE); \
		echo "Bumped build number to $$NEW_BUILD"; \
	else \
		echo "1" > $(BUILD_NUMBER_FILE); \
		echo "Created BUILD_NUMBER file with 1"; \
	fi

# --- Mac App ---
rust-release-mac:
	cd $(RUST_SRC) && cargo build --release --features ffi --target $(RUST_TARGET)
	mkdir -p $(MAC_APP_DIR)/Rust
	cp target/$(RUST_TARGET)/release/$(RUST_LIB_NAME) $(MAC_APP_DIR)/Rust/$(RUST_LIB_NAME)

xcode-project: sync-version
	cd $(MAC_APP_DIR) && xcodegen generate

build-mac: bump-build xcode-project rust-release-mac
	cd $(MAC_APP_DIR) && xcodebuild -project SwipeTypeMac.xcodeproj -scheme SwipeTypeMac -configuration Release -derivedDataPath BuildData build
	mkdir -p $(MAC_APP_DIR)/build/Release
	cp -R $(MAC_APP_DIR)/BuildData/Build/Products/Release/SwipeType.app $(MAC_APP_DIR)/build/Release/

mac-run:
	./$(MAC_APP_DIR)/build/Release/SwipeType.app/Contents/MacOS/SwipeType

dmg-mac: build-mac
	@echo "Packaging into DMG..."
	mkdir -p $(MAC_APP_DIR)/build/dmg
	rm -rf $(MAC_APP_DIR)/build/dmg/*
	cp -R $(MAC_APP_DIR)/build/Release/SwipeType.app $(MAC_APP_DIR)/build/dmg/
	ln -s /Applications $(MAC_APP_DIR)/build/dmg/Applications
	hdiutil create -volname "SwipeType" -srcfolder $(MAC_APP_DIR)/build/dmg -ov -format UDZO $(MAC_APP_DIR)/build/SwipeType.dmg
	@echo "Created $(MAC_APP_DIR)/build/SwipeType.dmg"

# --- Release Pipeline ---
release:
	@./scripts/release.sh

# --- Cleanup ---
clean:
	rm -rf build
	rm -rf $(MAC_APP_DIR)/build
	rm -rf $(MAC_APP_DIR)/BuildData
	rm -rf $(MAC_APP_DIR)/Rust/*.a
	rm -rf $(MAC_APP_DIR)/SwipeTypeMac.xcodeproj
	cd apps/web && rm -rf pkg target
	cd $(RUST_SRC) && cargo clean