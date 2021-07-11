#!/bin/bash
###############################################################################
#  Copyright (c) 2014-2020 libbitcoin-server developers (see COPYING).
#
#         GENERATED SOURCE CODE, DO NOT EDIT EXCEPT EXPERIMENTALLY
#
###############################################################################
# Script to build and install libbitcoin-server.
#
# Script options:
# --build-boost            Builds Boost libraries.
# --build-zmq              Builds ZeroMQ libraries.
# --build-dir=<path>       Location of downloaded and intermediate files.
# --prefix=<absolute-path> Library install location (defaults to /usr/local).
# --disable-shared         Disables shared library builds.
# --disable-static         Disables static library builds.
# --help                   Display usage, overriding script execution.
#
# Verified on Ubuntu 14.04, requires gcc-4.8 or newer.
# Verified on OSX 10.10, using MacPorts and Homebrew repositories, requires
# Apple LLVM version 6.0 (clang-600.0.54) (based on LLVM 3.5svn) or newer.
# This script does not like spaces in the --prefix or --build-dir, sorry.
# Values (e.g. yes|no) in the '--disable-<linkage>' options are not supported.
# All command line options are passed to 'configure' of each repo, with
# the exception of the --build-<item> options, which are for the script only.
# Depending on the caller's permission to the --prefix or --build-dir
# directory, the script may need to be sudo'd.

# Define constants.
#==============================================================================
# The default build directory.
#------------------------------------------------------------------------------
BUILD_DIR="build-libbitcoin-server"

# ZMQ archive.
#------------------------------------------------------------------------------
ZMQ_URL="https://github.com/zeromq/libzmq/releases/download/v4.3.4/zeromq-4.3.4.tar.gz"
ZMQ_ARCHIVE="zeromq-4.3.4.tar.gz"

# Boost archive.
#------------------------------------------------------------------------------
BOOST_URL="http://downloads.sourceforge.net/project/boost/boost/1.72.0/boost_1_72_0.tar.bz2"
BOOST_ARCHIVE="boost_1_72_0.tar.bz2"


# Define utility functions.
#==============================================================================
configure_links()
{
    # Configure dynamic linker run-time bindings when installing to system.
    if [[ ($OS == Linux) && ($PREFIX == "/usr/local") ]]; then
        ldconfig
    fi
}

configure_options()
{
    display_message "configure options:"
    for OPTION in "$@"; do
        if [[ $OPTION ]]; then
            display_message "$OPTION"
        fi
    done

    ./configure "$@"
}

create_directory()
{
    local DIRECTORY="$1"

    rm -rf "$DIRECTORY"
    mkdir "$DIRECTORY"
}

display_heading_message()
{
    printf "\n********************** %s **********************\n" "$@"
}

display_message()
{
    printf "%s\n" "$@"
}

display_error()
{
    >&2 printf "%s\n" "$@"
}

initialize_git()
{
    display_heading_message "Initialize git"

    # Initialize git repository at the root of the current directory.
    git init
    git config user.name anonymous
}

# make_current_directory jobs [configure_options]
make_current_directory()
{
    local JOBS=$1
    shift 1

    ./autogen.sh
    configure_options "$@"
    make_jobs "$JOBS"
    make install
    configure_links
}

# make_jobs jobs [make_options]
make_jobs()
{
    local JOBS=$1
    shift 1

    SEQUENTIAL=1
    # Avoid setting -j1 (causes problems on Travis).
    if [[ $JOBS > $SEQUENTIAL ]]; then
        make -j"$JOBS" "$@"
    else
        make "$@"
    fi
}

# make_tests jobs
make_tests()
{
    local JOBS=$1

    disable_exit_on_error

    # Build and run unit tests relative to the primary directory.
    # VERBOSE=1 ensures test runner output sent to console (gcc).
    make_jobs "$JOBS" check "VERBOSE=1"
    local RESULT=$?

    # Test runners emit to the test.log file.
    if [[ -e "test.log" ]]; then
        cat "test.log"
    fi

    if [[ $RESULT -ne 0 ]]; then
        exit $RESULT
    fi

    enable_exit_on_error
}

pop_directory()
{
    popd >/dev/null
}

push_directory()
{
    local DIRECTORY="$1"

    pushd "$DIRECTORY" >/dev/null
}

enable_exit_on_error()
{
    set -e
}

disable_exit_on_error()
{
    set +e
}

display_help()
{
    display_message "Usage: ./install.sh [OPTION]..."
    display_message "Manage the installation of libbitcoin-server."
    display_message "Script options:"
    display_message "  --build-boost            Builds Boost libraries."
    display_message "  --build-zmq              Build ZeroMQ libraries."
    display_message "  --build-dir=<path>       Location of downloaded and intermediate files."
    display_message "  --prefix=<absolute-path> Library install location (defaults to /usr/local)."
    display_message "  --disable-shared         Disables shared library builds."
    display_message "  --disable-static         Disables static library builds."
    display_message "  --help                   Display usage, overriding script execution."
    display_message ""
    display_message "All unrecognized options provided shall be passed as configuration options for "
    display_message "all dependencies."
}

# Define environment initialization functions
#==============================================================================
parse_command_line_options()
{
    for OPTION in "$@"; do
        case $OPTION in
            # Standard script options.
            (--help)                DISPLAY_HELP="yes";;

            # Standard build options.
            (--prefix=*)            PREFIX="${OPTION#*=}";;
            (--disable-shared)      DISABLE_SHARED="yes";;
            (--disable-static)      DISABLE_STATIC="yes";;

            # Common project options.

            # Custom build options (in the form of --build-<option>).
            (--build-zmq)           BUILD_ZMQ="yes";;
            (--build-boost)         BUILD_BOOST="yes";;

            # Unique script options.
            (--build-dir=*)    BUILD_DIR="${OPTION#*=}";;
        esac
    done
}

handle_help_line_option()
{
    if [[ $DISPLAY_HELP ]]; then
        display_help
        exit 0
    fi
}

set_operating_system()
{
    OS=$(uname -s)
}

configure_build_parallelism()
{
    if [[ $PARALLEL ]]; then
        display_message "Using shell-defined PARALLEL value."
    elif [[ $OS == Linux ]]; then
        PARALLEL=$(nproc)
    elif [[ ($OS == Darwin) || ($OS == OpenBSD) ]]; then
        PARALLEL=$(sysctl -n hw.ncpu)
    else
        display_error "Unsupported system: $OS"
        display_error "  Explicit shell-definition of PARALLEL will avoid system detection."
        display_error ""
        display_help
        exit 1
    fi
}

set_os_specific_compiler_settings()
{
    if [[ $OS == Darwin ]]; then
        export CC="clang"
        export CXX="clang++"
        STDLIB="c++"
    elif [[ $OS == OpenBSD ]]; then
        make() { gmake "$@"; }
        export CC="egcc"
        export CXX="eg++"
        STDLIB="estdc++"
    else # Linux
        STDLIB="stdc++"
    fi
}

link_to_standard_library()
{
    if [[ ($OS == Linux && $CC == "clang") || ($OS == OpenBSD) ]]; then
        export LDLIBS="-l$STDLIB $LDLIBS"
        export CXXFLAGS="-stdlib=lib$STDLIB $CXXFLAGS"
    fi
}

normalize_static_and_shared_options()
{
    if [[ $DISABLE_SHARED ]]; then
        CONFIGURE_OPTIONS=("$@" "--enable-static")
    elif [[ $DISABLE_STATIC ]]; then
        CONFIGURE_OPTIONS=("$@" "--enable-shared")
    else
        CONFIGURE_OPTIONS=("$@" "--enable-shared")
        CONFIGURE_OPTIONS=("$@" "--enable-static")
    fi
}

handle_custom_options()
{
    # bash doesn't like empty functions.
    FOO="bar"
}

remove_build_options()
{
    # Purge custom build options so they don't break configure.
    CONFIGURE_OPTIONS=("${CONFIGURE_OPTIONS[@]/--build-*/}")
}

set_prefix()
{
    # Always set a prefix (required on OSX and for lib detection).
    if [[ ! ($PREFIX) ]]; then
        PREFIX="/usr/local"
        CONFIGURE_OPTIONS=( "${CONFIGURE_OPTIONS[@]}" "--prefix=$PREFIX")
    else
        # Incorporate the custom libdir into each object, for link time resolution.
        export LD_RUN_PATH="$PREFIX/lib"
    fi
}

set_pkgconfigdir()
{
    # Set the prefix-based package config directory.
    PREFIX_PKG_CONFIG_DIR="$PREFIX/lib/pkgconfig"

    # Prioritize prefix package config in PKG_CONFIG_PATH search path.
    export PKG_CONFIG_PATH="$PREFIX_PKG_CONFIG_DIR:$PKG_CONFIG_PATH"

    # Set a package config save path that can be passed via our builds.
    with_pkgconfigdir="--with-pkgconfigdir=$PREFIX_PKG_CONFIG_DIR"
}

set_with_boost_prefix()
{
    if [[ $BUILD_BOOST ]]; then
        # Boost has no pkg-config, m4 searches in the following order:
        # --with-boost=<path>, /usr, /usr/local, /opt, /opt/local, $BOOST_ROOT.
        # We use --with-boost to prioritize the --prefix path when we build it.
        # Otherwise standard paths suffice for Linux, Homebrew and MacPorts.
        # ax_boost_base.m4 appends /include and adds to BOOST_CPPFLAGS
        # ax_boost_base.m4 searches for /lib /lib64 and adds to BOOST_LDFLAGS
        with_boost="--with-boost=$PREFIX"
    fi
}


# Initialize the build environment.
#==============================================================================
enable_exit_on_error
parse_command_line_options "$@"
handle_help_line_option
handle_custom_options
set_operating_system
configure_build_parallelism
set_os_specific_compiler_settings "$@"
link_to_standard_library
normalize_static_and_shared_options "$@"
remove_build_options
set_prefix
set_pkgconfigdir
set_with_boost_prefix

display_configuration()
{
    display_message "libbitcoin-server installer configuration."
    display_message "--------------------------------------------------------------------"
    display_message "OS                    : $OS"
    display_message "PARALLEL              : $PARALLEL"
    display_message "CC                    : $CC"
    display_message "CXX                   : $CXX"
    display_message "CPPFLAGS              : $CPPFLAGS"
    display_message "CFLAGS                : $CFLAGS"
    display_message "CXXFLAGS              : $CXXFLAGS"
    display_message "LDFLAGS               : $LDFLAGS"
    display_message "LDLIBS                : $LDLIBS"
    display_message "BUILD_ZMQ             : $BUILD_ZMQ"
    display_message "BUILD_BOOST           : $BUILD_BOOST"
    display_message "BUILD_DIR             : $BUILD_DIR"
    display_message "PREFIX                : $PREFIX"
    display_message "DISABLE_SHARED        : $DISABLE_SHARED"
    display_message "DISABLE_STATIC        : $DISABLE_STATIC"
    display_message "with_boost            : ${with_boost}"
    display_message "with_pkgconfigdir     : ${with_pkgconfigdir}"
    display_message "--------------------------------------------------------------------"
}


# Define build options.
#==============================================================================
# Define boost options.
#------------------------------------------------------------------------------
BOOST_OPTIONS=(
"--with-atomic" \
"--with-chrono" \
"--with-date_time" \
"--with-filesystem" \
"--with-iostreams" \
"--with-locale" \
"--with-log" \
"--with-program_options" \
"--with-regex" \
"--with-system" \
"--with-thread" \
"--with-test")

# Define secp256k1 options.
#------------------------------------------------------------------------------
SECP256K1_OPTIONS=(
"--disable-tests" \
"--enable-experimental" \
"--enable-module-recovery" \
"--enable-module-schnorrsig")

# Define bitcoin-system options.
#------------------------------------------------------------------------------
BITCOIN_SYSTEM_OPTIONS=(
"--without-tests" \
"--without-examples" \
"${with_boost}" \
"${with_pkgconfigdir}")

# Define bitcoin-consensus options.
#------------------------------------------------------------------------------
BITCOIN_CONSENSUS_OPTIONS=(
"--without-tests" \
"${with_boost}" \
"${with_pkgconfigdir}")

# Define bitcoin-database options.
#------------------------------------------------------------------------------
BITCOIN_DATABASE_OPTIONS=(
"--without-tests" \
"--without-tools" \
"${with_boost}" \
"${with_pkgconfigdir}")

# Define bitcoin-blockchain options.
#------------------------------------------------------------------------------
BITCOIN_BLOCKCHAIN_OPTIONS=(
"--without-tests" \
"--without-tools" \
"${with_boost}" \
"${with_pkgconfigdir}")

# Define bitcoin-network options.
#------------------------------------------------------------------------------
BITCOIN_NETWORK_OPTIONS=(
"--without-tests" \
"${with_boost}" \
"${with_pkgconfigdir}")

# Define bitcoin-node options.
#------------------------------------------------------------------------------
BITCOIN_NODE_OPTIONS=(
"--without-tests" \
"--without-console" \
"${with_boost}" \
"${with_pkgconfigdir}")

# Define bitcoin-protocol options.
#------------------------------------------------------------------------------
BITCOIN_PROTOCOL_OPTIONS=(
"--without-tests" \
"--without-examples" \
"${with_boost}" \
"${with_pkgconfigdir}")

# Define bitcoin-server options.
#------------------------------------------------------------------------------
BITCOIN_SERVER_OPTIONS=(
"${with_boost}" \
"${with_pkgconfigdir}")


# Define build functions.
#==============================================================================
# Because PKG_CONFIG_PATH doesn't get updated by Homebrew or MacPorts.
initialize_icu_packages()
{
    if [[ ($OS == Darwin) ]]; then
        # Update PKG_CONFIG_PATH for ICU package installations on OSX.
        # OSX provides libicucore.dylib with no pkgconfig and doesn't support
        # renaming or important features, so we can't use that.
        local HOMEBREW_ICU_PKG_CONFIG="/usr/local/opt/icu4c/lib/pkgconfig"
        local MACPORTS_ICU_PKG_CONFIG="/opt/local/lib/pkgconfig"

        if [[ -d "$HOMEBREW_ICU_PKG_CONFIG" ]]; then
            export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$HOMEBREW_ICU_PKG_CONFIG"
        elif [[ -d "$MACPORTS_ICU_PKG_CONFIG" ]]; then
            export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$MACPORTS_ICU_PKG_CONFIG"
        fi
    fi
}

# Standard build from tarball.
build_from_tarball()
{
    local URL=$1
    local ARCHIVE=$2
    local COMPRESSION=$3
    local PUSH_DIR=$4
    local JOBS=$5
    local BUILD=$6
    local OPTIONS=$7
    shift 7

    # For some platforms we need to set ICU pkg-config path.
    if [[ ! ($BUILD) ]]; then
        if [[ $ARCHIVE == "$ICU_ARCHIVE" ]]; then
            initialize_icu_packages
        fi
        return
    fi

    # Because ICU tools don't know how to locate internal dependencies.
    if [[ ($ARCHIVE == "$ICU_ARCHIVE") ]]; then
        local SAVE_LDFLAGS="$LDFLAGS"
        export LDFLAGS="-L$PREFIX/lib $LDFLAGS"
    fi

    display_heading_message "Download $ARCHIVE"

    # Use the suffixed archive name as the extraction directory.
    local EXTRACT="build-$ARCHIVE"
    push_directory "$BUILD_DIR"
    create_directory "$EXTRACT"
    push_directory "$EXTRACT"

    # Extract the source locally.
    wget --output-document "$ARCHIVE" "$URL"
    tar --extract --file "$ARCHIVE" "--$COMPRESSION" --strip-components=1
    push_directory "$PUSH_DIR"

    # Join generated and command line options.
    local CONFIGURATION=("${OPTIONS[@]}" "$@")

    if [[ $ARCHIVE == "$MBEDTLS_ARCHIVE" ]]; then
        make -j "$JOBS" lib
        make DESTDIR=$PREFIX install
    else
        configure_options "${CONFIGURATION[@]}"
        make_jobs "$JOBS" --silent
        make install
    fi

    configure_links

    pop_directory
    pop_directory

    # Restore flags to prevent side effects.
    export LDFLAGS=$SAVE_LDFLAGS
    export CPPFLAGS=$SAVE_CPPFLAGS

    pop_directory
}

# Because boost ICU static lib detection assumes in incorrect ICU path.
circumvent_boost_icu_detection()
{
    # Boost expects a directory structure for ICU which is incorrect.
    # Boost ICU discovery fails when using prefix, can't fix with -sICU_LINK,
    # so we rewrite the two 'has_icu_test.cpp' files to always return success.

    local SUCCESS="int main() { return 0; }"
    local REGEX_TEST="libs/regex/build/has_icu_test.cpp"
    local LOCALE_TEST="libs/locale/build/has_icu_test.cpp"

    printf "%s" "$SUCCESS" > $REGEX_TEST
    printf "%s" "$SUCCESS" > $LOCALE_TEST

    # display_message "Hack: ICU detection modified, will always indicate found."
}

# Because boost doesn't support autoconfig and doesn't like empty settings.
initialize_boost_configuration()
{
    if [[ $DISABLE_STATIC ]]; then
        BOOST_LINK="shared"
    elif [[ $DISABLE_SHARED ]]; then
        BOOST_LINK="static"
    else
        BOOST_LINK="static,shared"
    fi

    if [[ $CC ]]; then
        BOOST_TOOLSET="toolset=$CC"
    fi

    if [[ ($OS == Linux && $CC == "clang") || ($OS == OpenBSD) ]]; then
        STDLIB_FLAG="-stdlib=lib$STDLIB"
        BOOST_CXXFLAGS="cxxflags=$STDLIB_FLAG"
        BOOST_LINKFLAGS="linkflags=$STDLIB_FLAG"
    fi
}

# Because boost doesn't use pkg-config.
# The hacks below are still required as of boost 1.72.0.
initialize_boost_icu_configuration()
{
    BOOST_ICU_ICONV="on"
    BOOST_ICU_POSIX="on"

    if [[ $WITH_ICU ]]; then
        # Restrict other locale options when compiling boost with icu.
        BOOST_ICU_ICONV="off"
        BOOST_ICU_POSIX="off"

        # Work around boost ICU static lib discovery bug.
        circumvent_boost_icu_detection

        # Extract ICU prefix directory from package config variable.
        ICU_PREFIX=$(pkg-config icu-i18n --variable=prefix)

        # Extract ICU libs from package config variables and augment with -ldl.
        ICU_LIBS="$(pkg-config icu-i18n --libs) -ldl"

        # This is a hack for boost m4 scripts that fail with ICU dependency.
        export BOOST_ICU_LIBS=("${ICU_LIBS[@]}")
    fi
}

# Because boost doesn't use autoconfig.
build_from_tarball_boost()
{
    local SAVE_IFS="$IFS"
    IFS=' '

    local URL=$1
    local ARCHIVE=$2
    local COMPRESSION=$3
    local PUSH_DIR=$4
    local JOBS=$5
    local BUILD=$6
    shift 6

    if [[ ! ($BUILD) ]]; then
        return
    fi

    display_heading_message "Download $ARCHIVE"

    # Use the suffixed archive name as the extraction directory.
    local EXTRACT="build-$ARCHIVE"
    push_directory "$BUILD_DIR"
    create_directory "$EXTRACT"
    push_directory "$EXTRACT"

    # Extract the source locally.
    wget --output-document "$ARCHIVE" "$URL"
    tar --extract --file "$ARCHIVE" "--$COMPRESSION" --strip-components=1

    initialize_boost_configuration
    initialize_boost_icu_configuration

    display_message "Libbitcoin boost configuration."
    display_message "--------------------------------------------------------------------"
    display_message "variant               : release"
    display_message "threading             : multi"
    display_message "toolset               : $CC"
    display_message "cxxflags              : $STDLIB_FLAG"
    display_message "linkflags             : $STDLIB_FLAG"
    display_message "link                  : $BOOST_LINK"
    display_message "boost.locale.iconv    : $BOOST_ICU_ICONV"
    display_message "boost.locale.posix    : $BOOST_ICU_POSIX"
    display_message "-sNO_BZIP2            : 1"
    display_message "-sICU_PATH            : $ICU_PREFIX"
  # display_message "-sICU_LINK            : " "${ICU_LIBS[*]}"
    display_message "-j                    : $JOBS"
    display_message "-d0                   : [supress informational messages]"
    display_message "-q                    : [stop at the first error]"
    display_message "--reconfigure         : [ignore cached configuration]"
    display_message "--prefix              : $PREFIX"
    display_message "BOOST_OPTIONS         : $*"
    display_message "--------------------------------------------------------------------"

    ./bootstrap.sh \
        "--prefix=$PREFIX" \
        "--with-icu=$ICU_PREFIX"

    # boost_regex:
    # As of boost 1.72.0 the ICU_LINK symbol is no longer supported and
    # produces a hard stop if WITH_ICU is also defined. Removal is sufficient.
    # github.com/libbitcoin/libbitcoin-system/issues/1192
    # "-sICU_LINK=${ICU_LIBS[*]}"

    ./b2 install \
        "variant=release" \
        "threading=multi" \
        "$BOOST_TOOLSET" \
        "$BOOST_CXXFLAGS" \
        "$BOOST_LINKFLAGS" \
        "link=$BOOST_LINK" \
        "boost.locale.iconv=$BOOST_ICU_ICONV" \
        "boost.locale.posix=$BOOST_ICU_POSIX" \
        "-sNO_BZIP2=1" \
        "-sICU_PATH=$ICU_PREFIX" \
        "-j $JOBS" \
        "-d0" \
        "-q" \
        "--reconfigure" \
        "--prefix=$PREFIX" \
        "$@"

    pop_directory
    pop_directory

    IFS="$SAVE_IFS"
}

# Standard build from github.
build_from_github()
{
    push_directory "$BUILD_DIR"

    local ACCOUNT=$1
    local REPO=$2
    local BRANCH=$3
    local JOBS=$4
    local OPTIONS=$5
    shift 5

    FORK="$ACCOUNT/$REPO"
    display_heading_message "Download $FORK/$BRANCH"

    # Clone the repository locally.
    git clone --depth 1 --branch "$BRANCH" --single-branch "https://github.com/$FORK"

    # Join generated and command line options.
    local CONFIGURATION=("${OPTIONS[@]}" "$@")

    # Build the local repository clone.
    push_directory "$REPO"
    make_current_directory "$JOBS" "${CONFIGURATION[@]}"
    pop_directory
    pop_directory
}

# Standard build of current directory.
build_from_local()
{
    local MESSAGE="$1"
    local JOBS=$2
    local OPTIONS=$3
    shift 3

    display_heading_message "$MESSAGE"

    # Join generated and command line options.
    local CONFIGURATION=("${OPTIONS[@]}" "$@")

    # Build the current directory.
    make_current_directory "$JOBS" "${CONFIGURATION[@]}"
}

# Because Travis alread has downloaded the primary repo.
build_from_travis()
{
    local ACCOUNT=$1
    local REPO=$2
    local BRANCH=$3
    local JOBS=$4
    local OPTIONS=$5
    shift 5

    # The primary build is not downloaded if we are running in Travis.
    if [[ $TRAVIS == true ]]; then
        build_from_local "Local $TRAVIS_REPO_SLUG" "$JOBS" "${OPTIONS[@]}" "$@"
        make_tests "$JOBS"
    else
        build_from_github "$ACCOUNT" "$REPO" "$BRANCH" "$JOBS" "${OPTIONS[@]}" "$@"
        push_directory "$BUILD_DIR"
        push_directory "$REPO"
        make_tests "$JOBS"
        pop_directory
        pop_directory
    fi
}


# The master build function.
#==============================================================================
build_all()
{
    build_from_tarball_boost "$BOOST_URL" "$BOOST_ARCHIVE" bzip2 . "$PARALLEL" "$BUILD_BOOST" "${BOOST_OPTIONS[@]}"
    build_from_tarball "$ZMQ_URL" "$ZMQ_ARCHIVE" gzip . "$PARALLEL" "$BUILD_ZMQ" "${ZMQ_OPTIONS[@]}" "$@"
    build_from_github libbitcoin secp256k1 version7 "$PARALLEL" "${SECP256K1_OPTIONS[@]}" "$@"
    build_from_github libbitcoin libbitcoin-system master "$PARALLEL" "${BITCOIN_SYSTEM_OPTIONS[@]}" "$@"
    build_from_github libbitcoin libbitcoin-consensus master "$PARALLEL" "${BITCOIN_CONSENSUS_OPTIONS[@]}" "$@"
    build_from_github libbitcoin libbitcoin-database master "$PARALLEL" "${BITCOIN_DATABASE_OPTIONS[@]}" "$@"
    build_from_github libbitcoin libbitcoin-blockchain master "$PARALLEL" "${BITCOIN_BLOCKCHAIN_OPTIONS[@]}" "$@"
    build_from_github libbitcoin libbitcoin-network master "$PARALLEL" "${BITCOIN_NETWORK_OPTIONS[@]}" "$@"
    build_from_github libbitcoin libbitcoin-node master "$PARALLEL" "${BITCOIN_NODE_OPTIONS[@]}" "$@"
    build_from_github libbitcoin libbitcoin-protocol master "$PARALLEL" "${BITCOIN_PROTOCOL_OPTIONS[@]}" "$@"
    build_from_travis libbitcoin libbitcoin-server master "$PARALLEL" "${BITCOIN_SERVER_OPTIONS[@]}" "$@"
}


# Build the primary library and all dependencies.
#==============================================================================
display_configuration
create_directory "$BUILD_DIR"
push_directory "$BUILD_DIR"
initialize_git
pop_directory
time build_all "${CONFIGURE_OPTIONS[@]}"
