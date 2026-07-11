# Базовый образ с установленными утилитами
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Tallinn

# Установка базовых зависимостей
# mingw-w64 нужен для кросс-компиляции Windows .dll движка (CGO) из Linux.
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    wget clang cmake ninja-build pkg-config \
    libgtk-3-dev openjdk-17-jdk \
    gcc-mingw-w64-x86-64

# Установка Go
ENV GO_VERSION=1.22.1
RUN wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Установка Android SDK (Command line tools)
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d $ANDROID_HOME/cmdline-tools && \
    mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
    rm cmdline-tools.zip && \
    yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" \
               "ndk;26.1.10909125"

# NDK нужен для сборки Go c-shared движка (.so) под Android ABI через CGO.
ENV ANDROID_NDK_HOME=$ANDROID_HOME/ndk/26.1.10909125

# Установка Flutter
ENV FLUTTER_VERSION=3.24.0
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} /opt/flutter
ENV PATH=$PATH:/opt/flutter/bin
RUN flutter config --no-analytics && flutter precache

WORKDIR /app
CMD ["bash"]