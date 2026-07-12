# JNI shim between the Kotlin platform layer (NativeBridge/NetworkStateMonitor)
# and the Go engine (libvpn_engine.so). See fastflow_jni.cpp for the design and
# data/vpn_engine/netif_bridge.h for the shared C ABI.
cmake_minimum_required(VERSION 3.22.1)
project(fastflow_jni LANGUAGES CXX)

# Single source of truth for the ABI shared with the Go engine's cgo preamble.
get_filename_component(FF_ENGINE_ABI_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../data/vpn_engine" ABSOLUTE)

add_library(fastflow_jni SHARED fastflow_jni.cpp)

target_include_directories(fastflow_jni PRIVATE "${FF_ENGINE_ABI_DIR}")
target_compile_features(fastflow_jni PRIVATE cxx_std_17)
target_compile_options(fastflow_jni PRIVATE
    -Wall -Wextra
    -fvisibility=hidden
    -fno-exceptions -fno-rtti)

# Android 15 ships 16 KB page-size devices; keep ELF segments compliant.
target_link_options(fastflow_jni PRIVATE "-Wl,-z,max-page-size=16384")

# dl: runtime binding of the engine's Netif* exports; log: __android_log_print.
target_link_libraries(fastflow_jni dl log)
