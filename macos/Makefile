APP = Skillset.app
BIN = .build/release/Skillset
RES = $(APP)/Contents/Resources

VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)

.PHONY: app run test icon dist clean

app: $(BIN) Support/Icon.icns
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(RES)
	cp $(BIN) $(APP)/Contents/MacOS/Skillset
	cp Support/Info.plist $(APP)/Contents/Info.plist
	cp Support/Icon.icns $(RES)/Icon.icns
	cp ../catalog/catalog.json $(RES)/catalog.json
	codesign --force --deep --sign - $(APP)
	@echo "built $(APP)"

$(BIN): $(shell find Sources -name '*.swift') Package.swift
	swift build -c release

run: app
	open $(APP)

test:
	swift test

Support/Icon.icns: Support/make-icon.swift
	rm -rf Support/Icon.iconset
	mkdir -p Support/Icon.iconset
	swift Support/make-icon.swift Support/icon-1024.png
	for s in 16 32 64 128 256 512; do \
		sips -z $$s $$s Support/icon-1024.png --out Support/Icon.iconset/icon_$${s}x$${s}.png >/dev/null; \
		d=$$((s*2)); sips -z $$d $$d Support/icon-1024.png --out Support/Icon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns Support/Icon.iconset -o Support/Icon.icns
	rm -rf Support/Icon.iconset Support/icon-1024.png

icon: Support/Icon.icns

dist: app
	rm -f Skillset-$(VERSION).zip
	ditto -c -k --sequesterRsrc --keepParent $(APP) Skillset-$(VERSION).zip
	@echo "Skillset-$(VERSION).zip  $$(du -h Skillset-$(VERSION).zip | cut -f1)"

clean:
	rm -rf .build $(APP) Skillset-*.zip
