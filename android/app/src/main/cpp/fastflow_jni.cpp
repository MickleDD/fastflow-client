// fastflow_jni.cpp — JNI shim between the Kotlin platform layer and the Go
// engine (libvpn_engine.so).
//
// Data flow:
//
//   Kotlin NetworkStateMonitor ── nativeNetif*() downcalls (RegisterNatives)
//     └─► this shim ── dlsym'd Netif* exports ──► Go platform_android.go (Part 2)
//
//   Go engine ── function pointers handed over via NetifRegisterPlatform
//     └─► this shim ── cached JavaVM upcalls ──► NativeBridge.protectSocket /
//                                                NativeBridge.replayNetworkState
//
// The Go exports are resolved at runtime (dlopen/dlsym), never linked: the app
// keeps building and running against an engine that predates Part 2. Updates
// are dropped with a rate-limited warning until the symbols appear, and Go
// pulls a full state replay when its monitor starts, so late binding loses
// nothing.
//
// Threading: downcalls arrive serialized on the monitor's HandlerThread.
// Upcalls arrive on arbitrary Go runtime threads: those are attached on first
// use (AttachCurrentThreadAsDaemon) and detached automatically at thread exit
// through a pthread_key destructor — Go threads outlive any single call, and a
// thread that exits while still attached aborts ART.
//
// Memory: jstring buffers are pinned only for the duration of a downcall; the
// Go side receives borrowed pointers and must copy before returning (see the
// contract in netif_bridge.h).

#include <jni.h>

#include <android/log.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>

#include <atomic>
#include <mutex>

#include "netif_bridge.h"

#define FF_TAG "fastflow_jni"
#define FF_LOGI(...) __android_log_print(ANDROID_LOG_INFO, FF_TAG, __VA_ARGS__)
#define FF_LOGW(...) __android_log_print(ANDROID_LOG_WARN, FF_TAG, __VA_ARGS__)
#define FF_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, FF_TAG, __VA_ARGS__)

namespace {

// ─── Cached VM state (written once in JNI_OnLoad) ───────────────────────────

JavaVM* g_vm = nullptr;
jclass g_bridge_class = nullptr;    // global ref: com.fastflow.vpn.NativeBridge
jmethodID g_protect_mid = nullptr;  // static boolean protectSocket(int)
jmethodID g_replay_mid = nullptr;   // static void replayNetworkState()

// ─── Automatic attach/detach for Go threads ─────────────────────────────────

pthread_key_t g_detach_key;
pthread_once_t g_detach_key_once = PTHREAD_ONCE_INIT;

void DetachOnThreadExit(void* /*value*/) {
  if (g_vm != nullptr) g_vm->DetachCurrentThread();
}

void CreateDetachKey() {
  pthread_key_create(&g_detach_key, &DetachOnThreadExit);
}

// Returns a JNIEnv usable on the current thread, or nullptr. Threads we attach
// here (Go runtime threads) are detached lazily by the TLS destructor; threads
// that were already attached (Java-originated) are left untouched.
JNIEnv* GetAttachedEnv() {
  if (g_vm == nullptr) return nullptr;
  JNIEnv* env = nullptr;
  const jint state =
      g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
  if (state == JNI_OK) return env;
  if (state != JNI_EDETACHED) return nullptr;
  if (g_vm->AttachCurrentThreadAsDaemon(&env, nullptr) != JNI_OK) {
    FF_LOGE("AttachCurrentThreadAsDaemon failed");
    return nullptr;
  }
  pthread_once(&g_detach_key_once, &CreateDetachKey);
  pthread_setspecific(g_detach_key, env);
  return env;
}

}  // namespace

// ─── Upcall thunks (invoked from Go through registered pointers) ────────────

extern "C" {

static int32_t ProtectSocketThunk(int32_t fd) {
  JNIEnv* env = GetAttachedEnv();
  if (env == nullptr || g_bridge_class == nullptr || g_protect_mid == nullptr) {
    FF_LOGE("protect(%d): JNI bridge not initialised", fd);
    return -1;
  }
  const jboolean ok = env->CallStaticBooleanMethod(g_bridge_class, g_protect_mid,
                                                   static_cast<jint>(fd));
  if (env->ExceptionCheck()) {
    env->ExceptionDescribe();
    env->ExceptionClear();
    return -2;
  }
  return ok == JNI_TRUE ? 0 : -3;
}

static void RequestReplayThunk(void) {
  JNIEnv* env = GetAttachedEnv();
  if (env == nullptr || g_bridge_class == nullptr || g_replay_mid == nullptr) {
    return;
  }
  env->CallStaticVoidMethod(g_bridge_class, g_replay_mid);
  if (env->ExceptionCheck()) {
    env->ExceptionDescribe();
    env->ExceptionClear();
  }
}

}  // extern "C"

namespace {

// ─── Late-bound Go exports (contract: netif_bridge.h) ───────────────────────

using NetifUpdateFn = void (*)(FFNetworkInfo*);
using NetifLostFn = void (*)(int64_t);
using NetifDefaultChangedFn = void (*)(FFNetworkInfo*);
using NetifResetFn = void (*)(void);
using NetifRegisterPlatformFn = void (*)(ff_protect_fn, ff_replay_fn);

struct GoNetifApi {
  NetifUpdateFn update;
  NetifLostFn lost;
  NetifDefaultChangedFn default_changed;
  NetifResetFn reset;
  NetifRegisterPlatformFn register_platform;
};

GoNetifApi g_go = {};
std::atomic<bool> g_go_bound{false};
std::mutex g_bind_mutex;
std::atomic<uint32_t> g_dropped{0};

void WarnDropped(const char* what) {
  const uint32_t n = g_dropped.fetch_add(1, std::memory_order_relaxed);
  if (n == 0 || n % 100 == 0) {
    FF_LOGW(
        "dropping %s (#%u): Go Netif* exports not bound "
        "(engine built without platform-monitor support?)",
        what, n + 1);
  }
}

bool BindGoEngine(const char* soname) {
  std::lock_guard<std::mutex> lock(g_bind_mutex);
  if (g_go_bound.load(std::memory_order_acquire)) return true;
  if (soname == nullptr || soname[0] == '\0') return false;

  // Refcounted and idempotent: Dart FFI / System.loadLibrary usually mapped
  // the engine already, in which case this only bumps the reference count.
  void* lib = dlopen(soname, RTLD_NOW | RTLD_LOCAL);
  if (lib == nullptr) {
    FF_LOGE("dlopen(%s) failed: %s", soname, dlerror());
    return false;
  }

  GoNetifApi api = {};
  bool complete = true;
  const auto resolve = [&](const char* name) -> void* {
    void* sym = dlsym(lib, name);
    if (sym == nullptr) {
      FF_LOGW("engine lacks export %s", name);
      complete = false;
    }
    return sym;
  };
  api.update = reinterpret_cast<NetifUpdateFn>(resolve("NetifUpdate"));
  api.lost = reinterpret_cast<NetifLostFn>(resolve("NetifLost"));
  api.default_changed =
      reinterpret_cast<NetifDefaultChangedFn>(resolve("NetifDefaultChanged"));
  api.reset = reinterpret_cast<NetifResetFn>(resolve("NetifReset"));
  api.register_platform =
      reinterpret_cast<NetifRegisterPlatformFn>(resolve("NetifRegisterPlatform"));

  if (!complete) {
    dlclose(lib);  // drops only our refcount; the engine stays loaded for FFI
    return false;
  }

  // Publish the table BEFORE registering: if Go replays synchronously from
  // inside NetifRegisterPlatform, the resulting downcalls must not be dropped.
  g_go = api;
  g_go_bound.store(true, std::memory_order_release);
  api.register_platform(&ProtectSocketThunk, &RequestReplayThunk);
  FF_LOGI("bound Go Netif exports from %s", soname);
  return true;
}

// ─── RAII pin for jstring UTF-8 buffers ─────────────────────────────────────

class ScopedUtf {
 public:
  ScopedUtf(JNIEnv* env, jstring s) : env_(env), s_(s), chars_(nullptr) {
    if (s_ != nullptr) chars_ = env_->GetStringUTFChars(s_, nullptr);
  }
  ~ScopedUtf() {
    // ReleaseStringUTFChars is safe to call with an exception pending.
    if (s_ != nullptr && chars_ != nullptr) env_->ReleaseStringUTFChars(s_, chars_);
  }
  ScopedUtf(const ScopedUtf&) = delete;
  ScopedUtf& operator=(const ScopedUtf&) = delete;

  // Never returns NULL: an allocation failure degrades to "".
  const char* c_str() const { return chars_ != nullptr ? chars_ : ""; }

 private:
  JNIEnv* env_;
  jstring s_;
  const char* chars_;
};

// ─── Native method implementations (RegisterNatives → NativeBridge) ─────────

jboolean JNICALL NativeInit(JNIEnv* env, jclass /*clazz*/, jstring soname) {
  ScopedUtf name(env, soname);
  if (env->ExceptionCheck()) {
    env->ExceptionClear();
    return JNI_FALSE;
  }
  return BindGoEngine(name.c_str()) ? JNI_TRUE : JNI_FALSE;
}

void JNICALL NativeNetifUpdate(JNIEnv* env, jclass /*clazz*/, jlong handle,
                               jstring if_name, jint if_index, jint mtu,
                               jint flags, jstring addresses, jstring dns) {
  if (!g_go_bound.load(std::memory_order_acquire)) {
    WarnDropped("netif update");
    return;
  }
  ScopedUtf name(env, if_name);
  ScopedUtf addr(env, addresses);
  ScopedUtf dns_servers(env, dns);
  if (env->ExceptionCheck()) {  // OOM while pinning: bail out cleanly
    env->ExceptionClear();
    return;
  }

  FFNetworkInfo info;
  info.net_handle = static_cast<int64_t>(handle);
  info.if_index = static_cast<int32_t>(if_index);
  info.mtu = static_cast<int32_t>(mtu);
  info.flags = static_cast<uint32_t>(flags);
  info.if_name = name.c_str();
  info.addresses = addr.c_str();
  info.dns_servers = dns_servers.c_str();
  g_go.update(&info);  // borrowed pointers: Go copies before returning
}

void JNICALL NativeNetifLost(JNIEnv* /*env*/, jclass /*clazz*/, jlong handle) {
  if (!g_go_bound.load(std::memory_order_acquire)) {
    WarnDropped("netif lost");
    return;
  }
  g_go.lost(static_cast<int64_t>(handle));
}

void JNICALL NativeNetifDefaultChanged(JNIEnv* env, jclass /*clazz*/,
                                       jlong handle, jstring if_name,
                                       jint if_index, jint flags) {
  if (!g_go_bound.load(std::memory_order_acquire)) {
    WarnDropped("default-network change");
    return;
  }
  if (handle < 0) {  // FF_NETIF_NO_HANDLE: no usable underlying network
    g_go.default_changed(nullptr);
    return;
  }
  ScopedUtf name(env, if_name);
  if (env->ExceptionCheck()) {
    env->ExceptionClear();
    return;
  }
  FFNetworkInfo info;
  info.net_handle = static_cast<int64_t>(handle);
  info.if_index = static_cast<int32_t>(if_index);
  info.mtu = 0;
  info.flags = static_cast<uint32_t>(flags);
  info.if_name = name.c_str();
  info.addresses = "";
  info.dns_servers = "";
  g_go.default_changed(&info);
}

void JNICALL NativeNetifReset(JNIEnv* /*env*/, jclass /*clazz*/) {
  if (!g_go_bound.load(std::memory_order_acquire)) return;
  g_go.reset();
}

}  // namespace

// ─── Library entry points ───────────────────────────────────────────────────

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* /*reserved*/) {
  g_vm = vm;
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }

  jclass local = env->FindClass("com/fastflow/vpn/NativeBridge");
  if (local == nullptr) {
    FF_LOGE("com.fastflow.vpn.NativeBridge not found (R8 rename? check keep rules)");
    return JNI_ERR;  // System.loadLibrary throws; Kotlin degrades gracefully
  }
  g_bridge_class = static_cast<jclass>(env->NewGlobalRef(local));
  env->DeleteLocalRef(local);
  if (g_bridge_class == nullptr) return JNI_ERR;

  g_protect_mid = env->GetStaticMethodID(g_bridge_class, "protectSocket", "(I)Z");
  g_replay_mid =
      env->GetStaticMethodID(g_bridge_class, "replayNetworkState", "()V");
  if (g_protect_mid == nullptr || g_replay_mid == nullptr) {
    if (env->ExceptionCheck()) env->ExceptionClear();
    FF_LOGE("NativeBridge upcall methods missing");
    return JNI_ERR;
  }

  static const JNINativeMethod kMethods[] = {
      {"nativeInit", "(Ljava/lang/String;)Z",
       reinterpret_cast<void*>(&NativeInit)},
      {"nativeNetifUpdate",
       "(JLjava/lang/String;IIILjava/lang/String;Ljava/lang/String;)V",
       reinterpret_cast<void*>(&NativeNetifUpdate)},
      {"nativeNetifLost", "(J)V", reinterpret_cast<void*>(&NativeNetifLost)},
      {"nativeNetifDefaultChanged", "(JLjava/lang/String;II)V",
       reinterpret_cast<void*>(&NativeNetifDefaultChanged)},
      {"nativeNetifReset", "()V", reinterpret_cast<void*>(&NativeNetifReset)},
  };
  if (env->RegisterNatives(g_bridge_class, kMethods,
                           sizeof(kMethods) / sizeof(kMethods[0])) != JNI_OK) {
    FF_LOGE("RegisterNatives failed");
    return JNI_ERR;
  }
  return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void* /*reserved*/) {
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_OK &&
      g_bridge_class != nullptr) {
    env->DeleteGlobalRef(g_bridge_class);
  }
  g_bridge_class = nullptr;
  g_vm = nullptr;
}
