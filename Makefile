# FastFlow VPN — build orchestration.
#
# Two artifacts feed the Flutter app over FFI:
#   * Android:  libvpn_engine.so  (one per ABI, under android/app/src/main/jniLibs/<abi>/)
#   * Windows:  vpn_engine.dll     (next to the built .exe, so DynamicLibrary.open finds it)
#
# The Go engine lives in data/vpn_engine (module "vpnengine"). It targets a
# sing-box fork (hiddify/FastFlow) that understands the tls_tricks / tls_fragment
# extensions — see data/vpn_engine/go.mod. Run `go mod tidy` there once (network
# required) before the first build.

ENGINE_DIR := data/vpn_engine
ANDROID_JNILIBS := android/app/src/main/jniLibs
# The Windows runner CMake copies this next to the built .exe (see
# windows/runner/CMakeLists.txt), so DynamicLibrary.open('vpn_engine.dll') works.
WINDOWS_ENGINE_DLL := windows/vpn_engine.dll

# --- Android engine (requires ANDROID_NDK_HOME) -----------------------------
NDK_BIN := $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin

.PHONY: engine-android
engine-android:
	cd $(ENGINE_DIR) && \
	CGO_ENABLED=1 GOOS=android GOARCH=arm64 \
	CC=$(NDK_BIN)/aarch64-linux-android21-clang \
	go build -tags with_utls,with_reality_client,with_clash_api \
	  -buildmode=c-shared -trimpath -ldflags="-s -w" \
	  -o $(CURDIR)/$(ANDROID_JNILIBS)/arm64-v8a/libvpn_engine.so .
	cd $(ENGINE_DIR) && \
	CGO_ENABLED=1 GOOS=android GOARCH=arm \
	CC=$(NDK_BIN)/armv7a-linux-androideabi21-clang \
	go build -tags with_utls,with_reality_client,with_clash_api \
	  -buildmode=c-shared -trimpath -ldflags="-s -w" \
	  -o $(CURDIR)/$(ANDROID_JNILIBS)/armeabi-v7a/libvpn_engine.so .

# --- Windows engine (cross-compiled from Linux via mingw, or native) --------
.PHONY: engine-windows
engine-windows:
	cd $(ENGINE_DIR) && \
	CGO_ENABLED=1 GOOS=windows GOARCH=amd64 \
	CC=x86_64-w64-mingw32-gcc \
	go build -tags with_utls,with_reality_client,with_clash_api \
	  -buildmode=c-shared -trimpath -ldflags="-s -w" \
	  -o $(CURDIR)/$(WINDOWS_ENGINE_DLL) .

# --- Flutter apps -----------------------------------------------------------
.PHONY: app-android
app-android: engine-android
	flutter build apk -t main.dart --release

.PHONY: app-windows
app-windows: engine-windows
	# Engine built first so the CMake POST_BUILD step bundles vpn_engine.dll.
	flutter build windows -t main.dart --release

# --- Windows helper daemon (elevated service) -------------------------------
DAEMON_DIR := windows_daemon

.PHONY: daemon-windows
daemon-windows:
	cd $(DAEMON_DIR) && \
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 \
	go build -trimpath -ldflags "-s -w" -o fastflow-daemon.exe .

# --- Single-file installer (requires Inno Setup 6 `iscc` on PATH; Windows) ---
.PHONY: installer-windows
installer-windows: app-windows daemon-windows
	iscc installer/inno_setup.iss

.PHONY: tidy
tidy:
	cd $(ENGINE_DIR) && go mod tidy
	cd $(DAEMON_DIR) && go mod tidy

.PHONY: fmt
fmt:
	cd $(ENGINE_DIR) && gofmt -w .
	cd $(DAEMON_DIR) && gofmt -w .
	flutter format .
