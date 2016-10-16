#/bin/bash

export USE_CCACHE=1
export NDK_CCACHE=ccache
NDK_VER=android-ndk-r13

download_extract() {
    aria2c -x 16 $1 -o $2
    tar -xf $2
}

# This is used for the Android NDK.
download_extract_zip() {
    aria2c --file-allocation=none --timeout=120 --retry-wait=5 --max-tries=20 -Z -c $1 -o $2
    # This resumes the download, in case it failed (happens sometimes.)
    aria2c --file-allocation=none --timeout=120 --retry-wait=5 --max-tries=20 -Z -c $1 -o $2

    unzip $2 2>&1 | pv > /dev/null
}

force_java8() {
    sudo update-java-alternatives -v -s java-8-oracle
    # For some reason, that isn't updating JAVA_HOME, although it should.
    export JAVA_HOME=/usr/lib/jvm/java-8-oracle
}

travis_before_install() {
    git submodule update --init --recursive

    if [ ! "$TRAVIS_OS_NAME" = "osx" ]; then
        sudo apt-get update -qq
        sudo apt-get install software-properties-common aria2 pv build-essential libgl1-mesa-dev libglu1-mesa-dev -qq
    fi
}

setup_ccache_script() {
    if [ ! -e "$1" ]; then
        mkdir "$1"
    fi

    echo "#!/bin/bash" > "$1/$3"
    echo "ccache $2/$3 \$*" >> "$1/$3"
    chmod +x "$1/$3"
}

travis_install() {
    # Ubuntu Linux + GCC 4.8
    if [ "$PPSSPP_BUILD_TYPE" = "Linux" ]; then
        # For libsdl2-dev.
        sudo add-apt-repository ppa:zoogie/sdl2-snapshots -y
        if [ "$CXX" = "g++" ]; then
            sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
        fi
        if [ "$QT" = "TRUE" ]; then
            sudo add-apt-repository ppa:ubuntu-sdk-team/ppa -y
        fi

        sudo apt-get update
        sudo apt-get install libsdl2-dev -qq
        if [ "$CXX" = "g++" ]; then
            sudo apt-get install g++-4.8 -qq
        fi

        if [ "$QT" = "TRUE" ]; then
            sudo apt-get install -qq qt5-qmake qtmultimedia5-dev qtsystems5-dev qtbase5-dev qtdeclarative5-dev qttools5-dev-tools libqt5webkit5-dev libsqlite3-dev qt5-default
        fi
    fi

    if [ "$CMAKE" = "TRUE" ]; then
        download_extract "https://cmake.org/files/v3.6/cmake-3.6.2-Linux-x86_64.tar.gz" cmake-3.6.2-Linux-x86_64.tar.gz
    fi

    if [ "$PPSSPP_BUILD_TYPE" = "Android" ]; then
        mkdir -p ~/.android
        force_java8

        # Install the NDK - the SDK manager won't do this from cli.
        download_extract_zip http://dl.google.com/android/repository/${NDK_VER}-linux-x86_64.zip ${NDK_VER}-linux-x86_64.zip

        # CMake needs a newer libstdc.
        sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
        sudo apt-get update -qq
        sudo apt-get install -qq libstdc++6-4.7-dev

        # We also need to install the latest cmake for the SDK (also not cli.)
        wget https://github.com/Commit451/android-cmake-installer/releases/download/1.1.0/install-cmake.sh
        chmod +x install-cmake.sh
        ./install-cmake.sh
    fi

    # Ensure we're using ccache
    if [[ "$CXX" = "clang" && "$CC" == "clang" ]]; then
        export CXX="ccache clang" CC="ccache clang"
    fi
    if [[ "$PPSSPP_BUILD_TYPE" == "Linux" && "$CXX" == "g++" ]]; then
        # Also use gcc 4.8, instead of whatever default version.
        export CXX="ccache g++-4.8" CC="ccache gcc-4.8"
    fi
    if [[ "$CXX" != *ccache* ]]; then
        export CXX="ccache $CXX"
    fi
    if [[ "$CC" != *ccache* ]]; then
        export CC="ccache $CC"
    fi
}

travis_script() {
    if [ -d cmake-3.6.2-Linux-x86_64 ]; then
        export PATH=$(pwd)/cmake-3.6.2-Linux-x86_64/bin:$PATH
    fi

    # Compile PPSSPP
    if [ "$PPSSPP_BUILD_TYPE" = "Linux" ]; then
        if [ "$QT" = "TRUE" ]; then
            ./b.sh --qt
        else
            ./b.sh --headless
        fi
    fi
    if [ "$PPSSPP_BUILD_TYPE" = "Android" ]; then
        force_java8

        export ANDROID_NDK_HOME=$(pwd)/$NDK_VER
        export PATH=$ANDROID_NDK_HOME:$PATH

        chmod +x gradlew
        ./gradlew --debug assembleRelease
    fi
    if [ "$PPSSPP_BUILD_TYPE" = "iOS" ]; then
        ./b.sh --ios
        pushd build
        xcodebuild -configuration Release
        popd build
    fi
}

travis_after_success() {
    ccache -s

    if [ "$PPSSPP_BUILD_TYPE" = "Linux" ]; then
        ./test.py
    fi
}

set -e
set -x

$1;
