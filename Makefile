# Top-level: builds the iOS packages. Needs Theos ($THEOS) + iOS 15 SDK on macOS/Linux.
export THEOS_PACKAGE_SCHEME = rootless
export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
SUBPROJECTS = tweaks/imessage app
include $(THEOS_MAKE_PATH)/aggregate.mk

# chatoriumd is a static Go binary: build it first, it is bundled by the app project.
.PHONY: hub
hub:
	cd hub && GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o ../layout/usr/local/bin/chatoriumd .
	ldid -S layout/usr/local/bin/chatoriumd
