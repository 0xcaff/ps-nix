{
  self,
  flake-utils,
  nixpkgs,
  ...
}:
let
  supported-systems = with flake-utils.lib.system; [
    x86_64-linux
  ];
in
flake-utils.lib.eachSystem supported-systems (
  system:
  let
    pkgs = import nixpkgs { inherit system; };
    localPkgs = self.packages.${system};

    itemzflowSrc = pkgs.fetchFromGitHub {
      owner = "LightningMods";
      repo = "Itemzflow";
      rev = "1.08";
      sha256 = "sha256-bxUABl9RY2GegCHNC3OH9ChWT/fOcIPn+Nc/WZ7Tx2w=";
    };

    ps4sdkSrc = pkgs.fetchFromGitHub {
      owner = "orbisdev";
      repo = "PS4SDK";
      rev = "29878ae49ef645be83f8275b3eb8e0e2def53304";
      sha256 = "sha256-HJdrJ6B6i+h0oZl5l7Ah8O11396Wv2VxtnANBV9DDJc=";
    };

    sdkvanillaSrc = pkgs.fetchFromGitHub {
      owner = "orbisdev";
      repo = "orbisdev-sdkvanilla";
      rev = "9b28415267bf8cfa826064efa6566afd883014a0";
      sha256 = "sha256-As1opKq+m38mmOUpPaNTsDWrDoSAd3F2jgXNeZIQjKQ=";
    };

    headersSrc = pkgs.fetchFromGitHub {
      owner = "orbisdev";
      repo = "orbisdev-headers";
      rev = "7bd7e410b143f89c97af3c48bf6d552fda611ab2";
      sha256 = "sha256-3ur18F1WyeADY6Rk64IVqK3/ED3xZ0Z5fMc3Ux60hXY=";
    };

    libSQLiteSrc = pkgs.fetchFromGitHub {
      owner = "orbisdev";
      repo = "orbisdev-libSQLite";
      rev = "2615ca484f1f566304fda48399fa66f864c695a8";
      sha256 = "sha256-Euad5YlGFv0A8owLrUXaRs/oZUK4YGPOuqtuRprlHN0=";
    };

    utilsSrc = pkgs.fetchFromGitHub {
      owner = "orbisdev";
      repo = "orbisdev-utils";
      rev = "92eb8826999a7fe76e81264273762287673c76e0";
      sha256 = "sha256-2GlNu98+kw3Mw42aTgaB9NOuKmZzokdvds0zxLqMocc=";
    };

    liborbisSrc = pkgs.fetchFromGitHub {
      owner = "orbisdev";
      repo = "liborbis";
      rev = "d0b11bdbd1a5ddab02cf534d145208561407847e";
      sha256 = "sha256-8KTf/DThmh0GjBrQqQePAk4FT71sSpUV4SeS1B7MlyQ=";
    };
  in
  {
    packages.itemzflow = pkgs.stdenv.mkDerivation rec {
      pname = "itemzflow";
      version = "1.08";

      src = itemzflowSrc;

      nativeBuildInputs = with pkgs; [
        gnumake
        llvmPackages_18.bintools-unwrapped
        llvmPackages_18.clang-unwrapped
        perl
        rsync
        sqlite
      ];

      dontConfigure = true;
      dontFixup = true;
      enableParallelBuilding = true;

      postPatch = ''
                substituteInPlace external/libfuse/include/config.h \
                  --replace-fail "/* #undef HAVE_STRUCT_STAT_ST_ATIM */" "#define HAVE_STRUCT_STAT_ST_ATIM 1" \
                  --replace-fail "#define HAVE_STRUCT_STAT_ST_ATIMESPEC 1" "/* #undef HAVE_STRUCT_STAT_ST_ATIMESPEC */"

                substituteInPlace itemz-loader/Makefile \
                  --replace-fail "LinkerFlags += -lSceLncUtil_stub" "LinkerFlags += -lkernel -lSceLncUtil_stub"
                substituteInPlace itemz-daemon/Makefile \
                  --replace-fail "LinkerFlags +=  -lfuse" "LinkerFlags +=  -lkernel -lfuse"
                substituteInPlace itemzflow/Makefile \
                  --replace-fail "LinkerFlags +=  -ltag" "LinkerFlags +=  -lkernel -ltag"

                substituteInPlace itemzflow/include/net.h \
                  --replace-fail "_SCE_SSL_H_" "ITEMZFLOW_NET_H_"

                substituteInPlace itemzflow/include/mp3/dr_mp3.h \
                  --replace-fail "#define DRMP3_HAVE_SSE 1" "#ifndef DR_MP3_NO_SIMD"$'\n'"#define DRMP3_HAVE_SSE 1"$'\n'"#endif"

                substituteInPlace itemzflow/source/GLES2_itemzflow.cpp \
                  --replace-fail "// redef for yaml-cpp"$'\n'"int isascii(int c)" \
                                 "// redef for yaml-cpp"$'\n'"#ifdef isascii"$'\n'"#undef isascii"$'\n'"#endif"$'\n'"int isascii(int c)"

                substituteInPlace itemzflow/source/demo-font.cpp \
                  --replace-fail "#include <string.h>" "#include <string.h>"$'\n'"#include <vector>" \
                  --replace-fail "  } pkg_table_entry[pkg_file_count];" "  };"$'\n'"  std::vector<pkg_table_entry> pkg_table_entries(pkg_file_count);" \
                  --replace-fail "  fread(pkg_table_entry, sizeof (struct pkg_table_entry), pkg_file_count, file);" "  fread(pkg_table_entries.data(), sizeof (struct pkg_table_entry), pkg_file_count, file);" \
                  --replace-fail "    if (pkg_table_entry[i].id == 1048576) { // param.sfo ID" "    if (pkg_table_entries[i].id == 1048576) { // param.sfo ID" \
                  --replace-fail "      return bswap_32(pkg_table_entry[i].offset);" "      return bswap_32(pkg_table_entries[i].offset);"

        substituteInPlace itemzflow/source/sig_handler.cpp \
          --replace-fail '  options.sb_copy = false;


          if(Confirmation_Msg(SAMPLER_MSG) == YES){
               options.sb_copy = true;
          }
        ' ""

        substituteInPlace itemzflow/include/defines.h \
          --replace-fail "#define VERSION_MINOR 07" "#define VERSION_MINOR 8"
      '';

      buildPhase = ''
        runHook preBuild

        cp -R ${ps4sdkSrc} ps4sdk-src
        cp -R ${sdkvanillaSrc} sdkvanilla-src
        cp -R ${headersSrc} headers-src
        cp -R ${libSQLiteSrc} libSQLite-src
        cp -R ${utilsSrc} utils-src
        cp -R ${liborbisSrc} liborbis-src
        chmod -R u+w ps4sdk-src sdkvanilla-src headers-src libSQLite-src utils-src liborbis-src

        export SDK="$TMPDIR/itemzflow-orbisdev"
        mkdir -p "$SDK"
        cp -a ${localPkgs.toolchain}/. "$SDK"/
        chmod -R u+w "$SDK"
        mkdir -p "$SDK"/{bin,lib,make,usr}
        rm -rf "$SDK/usr/include" "$SDK/usr/lib"
        ln -sfn ../include "$SDK/usr/include"
        ln -sfn ../lib "$SDK/usr/lib"

        cp -R sdkvanilla-src/makefiles/make/. "$SDK/make"
        cp "$SDK/link.x" "$SDK/lib/linker.x"

        clang --target=x86_64-scei-ps4 \
          -isysroot "$SDK" \
          -I"$SDK/include" \
          -include stdint.h \
          -fPIE \
          -c sdkvanilla-src/makefiles/usr/lib/crt0.c \
          -o "$SDK/lib/crt0.o"

        cat > "$SDK/bin/orbis-ld" <<EOF
        #!${pkgs.runtimeShell}
        exec ld.lld "\$@"
        EOF
        cat > "$SDK/bin/orbis-ar" <<EOF
        #!${pkgs.runtimeShell}
        exec llvm-ar "\$@"
        EOF
        cat > "$SDK/bin/orbis-objcopy" <<EOF
        #!${pkgs.runtimeShell}
        exec llvm-objcopy "\$@"
        EOF
        cat > "$SDK/bin/pkgTool" <<EOF
        #!${pkgs.runtimeShell}
        exec ${localPkgs.pkg-tool}/bin/PkgTool.Core "\$@"
        EOF
        chmod +x "$SDK/bin"/orbis-ld "$SDK/bin"/orbis-ar "$SDK/bin"/orbis-objcopy "$SDK/bin"/pkgTool

        for so in "$SDK"/lib/libSce*.so "$SDK"/lib/libkernel*.so; do
          [ -e "$so" ] || continue
          ln -sfn "$(basename "$so")" "$SDK/lib/$(basename "''${so%.so}")_stub.so"
        done
        ln -sfn libSceFreeTypeOptOl.so "$SDK/lib/libSceFreeTypeOl_stub.so"
        ln -sfn libSceShellCoreUtil.so "$SDK/lib/libSceShellUIUtil_stub.so"

        install -Dm644 headers-src/include/ps4sdk.h "$SDK/include/ps4sdk.h"
        install -Dm644 headers-src/include/orbis/libkernel.h "$SDK/include/orbis/libkernel.h"
        install -Dm644 headers-src/include/orbis/libSceLibcInternal.h "$SDK/include/orbis/libSceLibcInternal.h"
        cp headers-src/include/orbis/libSce*.h "$SDK/include/orbis/"

        mkdir -p "$SDK/include/types"
        cp -R ps4sdk-src/include/EGL ps4sdk-src/include/GLES2 ps4sdk-src/include/KHR "$SDK/include/"
        cp -R ps4sdk-src/include/sce "$SDK/include/"
        cp ps4sdk-src/include/piglet.h ps4sdk-src/include/prerequisites.h "$SDK/include/"
        cp ps4sdk-src/include/sce/sysmodule.h "$SDK/include/sysmodule.h"
        cp ps4sdk-src/include/sce/types/pad.h "$SDK/include/types/pad.h"
        cp ps4sdk-src/include/sce/types/userservice.h "$SDK/include/types/userservice.h"
        cp ps4sdk-src/include/sce/types/videoout.h "$SDK/include/types/videoout.h"
        cp liborbis-src/liborbisFile/include/orbisFile.h "$SDK/include/orbisFile.h"

        cat > "$SDK/include/net.h" <<'EOF'
        #pragma once
        #include <orbis/libSceNet.h>
        EOF

        cat > "$SDK/include/types/kernel.h" <<'EOF'
        #pragma once
        #include <stdint.h>
        #include <sys/time.h>
        typedef void *ScePthread;
        typedef void *ScePthreadAttr;
        typedef void *ScePthreadMutex;
        typedef void *ScePthreadMutexattr;
        typedef void *SceKernelSema;
        typedef unsigned int SceKernelUseconds;
        typedef uint32_t SceKernelModule;
        typedef int64_t SceKernelEqueue;
        typedef struct timeval SceKernelTimeval;
        EOF

        cat > "$SDK/include/sce/kernel.h" <<'EOF'
        #pragma once
        #include <stdint.h>
        #include <stddef.h>
        #include <types/kernel.h>
        int sceKernelUsleep(unsigned int microseconds);
        EOF

        cat > "$SDK/include/audioout.h" <<'EOF'
        #pragma once
        #include <stdint.h>
        #include <types/kernel.h>
        #include <types/userservice.h>
        #ifdef __cplusplus
        extern "C" {
        #endif
        int sceAudioOutInit(void);
        int sceAudioOutOpen(SceUserServiceUserId userId, unsigned int channel, int unknown, unsigned int samples, unsigned int frequency, unsigned int format);
        int sceAudioOutClose(int handle);
        int sceAudioOutOutput(int handle, void *buf);
        int sceAudioOutSetVolume(int handle, int filter, int *value);
        #ifdef __cplusplus
        }
        #endif
        EOF

        cat > "$SDK/include/userservice.h" <<'EOF'
        #pragma once
        #include <types/userservice.h>
        #ifdef __cplusplus
        extern "C" {
        #endif
        int sceUserServiceInitialize(int *params);
        int sceUserServiceTerminate(void);
        int sceUserServiceGetInitialUser(SceUserServiceUserId *userId);
        int sceUserServiceGetForegroundUser(SceUserServiceUserId *userId);
        #ifdef __cplusplus
        }
        #endif
        EOF

        cat > "$SDK/include/pad.h" <<'EOF'
        #pragma once
        #include <stdint.h>
        #include <types/pad.h>
        #include <types/userservice.h>
        #ifdef __cplusplus
        extern "C" {
        #endif
        int scePadInit(void);
        int scePadOpen(SceUserServiceUserId userId, int type, int index, uint8_t *param);
        int scePadClose(int handle);
        int scePadRead(int handle, ScePadData *data, int count);
        int scePadReadState(int handle, ScePadData *data);
        int scePadSetProcessPrivilege(int privilege);
        #ifdef __cplusplus
        }
        #endif
        EOF

        cat > "$SDK/include/videoout.h" <<'EOF'
        #pragma once
        #include <stdint.h>
        #include <types/kernel.h>
        #include <types/userservice.h>
        #include <types/videoout.h>
        #ifdef __cplusplus
        extern "C" {
        #endif
        int sceVideoOutOpen(SceUserServiceUserId userId, int type, int index, const void *param);
        int sceVideoOutClose(int handle);
        int sceVideoOutRegisterBuffers(int handle, int initialIndex, void * const *addr, int numBuf, const SceVideoOutBufferAttribute *attr);
        int sceVideoOutUnregisterBuffers(int handle, int indexAttr);
        int sceVideoOutSubmitFlip(int handle, int indexBuf, unsigned int flipMode, int64_t flipArg);
        void sceVideoOutSetBufferAttribute(SceVideoOutBufferAttribute *attr, unsigned int format, unsigned int tmode, unsigned int aspect, unsigned int width, unsigned int height, unsigned int pixelPitch);
        int sceVideoOutSetFlipRate(int handle, int flipRate);
        int sceVideoOutAddFlipEvent(SceKernelEqueue eq, int handle, void *data);
        int sceVideoOutGetFlipStatus(int handle, SceVideoOutFlipStatus *status);
        #ifdef __cplusplus
        }
        #endif
        EOF

        cat > "$SDK/include/libkernel.h" <<'EOF'
        #pragma once
        #include <orbis/libkernel.h>
        EOF

        cat > "$SDK/include/libSceSysmodule.h" <<'EOF'
        #pragma once
        #include <orbis/libSceSysmodule.h>
        EOF

        cat > "$SDK/include/orbislink.h" <<'EOF'
        #pragma once
        EOF

        cat > "$SDK/include/ps4link.h" <<'EOF'
        #pragma once
        EOF

        cat > "$SDK/include/stdatomic.h" <<'EOF'
        #pragma once
        #ifdef __cplusplus
        #include <atomic>
        using atomic_bool = std::atomic_bool;
        #ifndef ATOMIC_VAR_INIT
        #define ATOMIC_VAR_INIT(value) (value)
        #endif
        #else
        #include <stdbool.h>
        typedef bool atomic_bool;
        #ifndef ATOMIC_VAR_INIT
        #define ATOMIC_VAR_INIT(value) (value)
        #endif
        #endif
        EOF

        mkdir -p "$SDK/include/sys"
        cat > "$SDK/include/sys/_types.h" <<'EOF'
        #pragma once
        #include <sys/types.h>
        EOF

        cat > "$SDK/include/sys/_iovec.h" <<'EOF'
        #pragma once
        #include <sys/uio.h>
        EOF

        cat > "$SDK/include/sys/sysctl.h" <<'EOF'
        #pragma once
        #include <stddef.h>
        #ifdef __cplusplus
        extern "C" {
        #endif
        int sysctlbyname(const char *name, void *oldp, size_t *oldlenp, const void *newp, size_t newlen);
        #ifdef __cplusplus
        }
        #endif
        EOF

        cat > "$SDK/include/sys/dirent.h" <<'EOF'
        #pragma once
        #include <features.h>
        #define __NEED_ino_t
        #define __NEED_off_t
        #include <bits/alltypes.h>
        #include <bits/dirent.h>
        EOF

        cat > "$SDK/include/sys/mount.h" <<'EOF'
        #ifndef _SYS_MOUNT_H
        #define _SYS_MOUNT_H

        #ifdef __cplusplus
        extern "C" {
        #endif

        #include <sys/ioctl.h>
        #include <sys/statfs.h>
        #include <sys/uio.h>

        #define BLKROSET   _IO(0x12, 93)
        #define BLKROGET   _IO(0x12, 94)
        #define BLKRRPART  _IO(0x12, 95)
        #define BLKGETSIZE _IO(0x12, 96)
        #define BLKFLSBUF  _IO(0x12, 97)
        #define BLKRASET   _IO(0x12, 98)
        #define BLKRAGET   _IO(0x12, 99)
        #define BLKFRASET  _IO(0x12,100)
        #define BLKFRAGET  _IO(0x12,101)
        #define BLKSECTSET _IO(0x12,102)
        #define BLKSECTGET _IO(0x12,103)
        #define BLKSSZGET  _IOR(0x12,104,size_t)
        #define BLKBSZGET  _IOR(0x12,112,size_t)
        #define BLKBSZSET  _IOW(0x12,113,size_t)
        #define BLKGETSIZE64 _IOR(0x12,114,size_t)

        #define MS_RDONLY      1
        #define MS_NOSUID      2
        #define MS_NODEV       4
        #define MS_NOEXEC      8
        #define MS_SYNCHRONOUS 16
        #define MS_REMOUNT     32
        #define MS_MANDLOCK    64
        #define MS_DIRSYNC     128
        #define MS_NOATIME     1024
        #define MS_NODIRATIME  2048
        #define MS_BIND        4096
        #define MS_MOVE        8192
        #define MS_REC         16384
        #define MS_SILENT      32768
        #define MS_POSIXACL    (1<<16)
        #define MS_UNBINDABLE  (1<<17)
        #define MS_PRIVATE     (1<<18)
        #define MS_SLAVE       (1<<19)
        #define MS_SHARED      (1<<20)
        #define MS_RELATIME    (1<<21)
        #define MS_KERNMOUNT   (1<<22)
        #define MS_I_VERSION   (1<<23)
        #define MS_STRICTATIME (1<<24)
        #define MS_LAZYTIME    (1<<25)
        #define MS_NOREMOTELOCK (1<<27)
        #define MS_NOSEC       (1<<28)
        #define MS_BORN        (1<<29)
        #define MS_ACTIVE      (1<<30)
        #define MS_NOUSER      (1U<<31)

        #define MS_RMT_MASK (MS_RDONLY|MS_SYNCHRONOUS|MS_MANDLOCK|MS_I_VERSION|MS_LAZYTIME)
        #define MS_MGC_VAL 0xc0ed0000
        #define MS_MGC_MSK 0xffff0000

        #define MNT_FORCE       1
        #define MNT_DETACH      2
        #define MNT_EXPIRE      4
        #define UMOUNT_NOFOLLOW 8

        #ifndef MFSNAMELEN
        #define MFSNAMELEN 16
        #endif

        struct vfsops;
        struct vfsoptdecl;
        struct vfsconf {
          unsigned int vfc_version;
          char vfc_name[MFSNAMELEN];
          struct vfsops *vfc_vfsops;
          int vfc_typenum;
          int vfc_refcount;
          int vfc_flags;
          struct vfsoptdecl *vfc_opts;
          struct {
            struct vfsconf *tqe_next;
            struct vfsconf **tqe_prev;
          } vfc_list;
        };

        int mount(const char *, const char *, const char *, unsigned long, const void *);
        int umount(const char *);
        int umount2(const char *, int);
        int nmount(struct iovec *iov, unsigned int iovlen, int flags);

        #ifdef __cplusplus
        }

        static inline int mount(const char *type, const char *dir, int flags, const void *data)
        {
          return mount(type, dir, (const char *)0, (unsigned long)flags, data);
        }
        #endif

        #endif
        EOF

        substituteInPlace "$SDK/include/dirent.h" \
          --replace-fail "int getdents(int, struct dirent *, size_t);" "int getdents(int, void *, size_t);"
        cat > "$SDK/include/sys/fcntl.h" <<'EOF'
        #pragma once
        #include <fcntl.h>
        EOF
        cat > "$SDK/include/sys/signal.h" <<'EOF'
        #pragma once
        #include <signal.h>
        EOF
        cat > "$SDK/include/sys/errno.h" <<'EOF'
        #pragma once
        #include <errno.h>
        EOF
        cat > "$SDK/include/sys/poll.h" <<'EOF'
        #pragma once
        #include <poll.h>
        EOF
        cat > "$SDK/include/sys/termios.h" <<'EOF'
        #pragma once
        #include <termios.h>
        EOF
        substituteInPlace "$SDK/include/ps4sdk.h" \
          --replace-fail "#include <orbis/libScePad.h>" "#include <pad.h>"
        cat >> "$SDK/include/sys/types.h" <<'EOF'

        #ifndef major
        #define major(x) ((int)(((unsigned)(x) >> 8) & 0xff))
        #endif
        #ifndef minor
        #define minor(x) ((int)((x) & 0xff))
        #endif
        EOF

        export PATH="$SDK/bin:$SDK/bin/linux:$PATH"
        export ORBISDEV="$SDK"
        export OO_PS4_TOOLCHAIN="$SDK"
        export PS4SDK="$SDK"
        export Ps4Sdk="$SDK"

        COMMON_CF="-D_GNU_SOURCE -I$SDK/usr/include -I$SDK/include -I$SDK/include/c++/v1 -I$SDK/include/orbis/_types"
        COMMON_CXXF="$COMMON_CF"

        build_liborbis_lib() {
          local dir="$1"
          make -C "$dir" clean all install Cf="$COMMON_CF" Cppf="$COMMON_CXXF"
        }

        build_orbisdev_lib() {
          local dir="$1"
          make -C "$dir" clean all install Cf="$COMMON_CF" Cppf="$COMMON_CXXF"
        }

        build_liborbis_lib liborbis-src/libdebugnet
        build_liborbis_lib liborbis-src/liborbisPad
        build_liborbis_lib liborbis-src/liborbisAudio
        build_liborbis_lib liborbis-src/liborbisGl
        build_liborbis_lib liborbis-src/liborbisNfs
        build_liborbis_lib liborbis-src/portlibs/libz
        build_liborbis_lib liborbis-src/portlibs/libpng

        cp liborbis-src/liborbisFile/include/orbisFile.h "$SDK/include/orbisFile.h"

        substituteInPlace "$SDK/include/debugnet.h" \
          --replace-fail "#define NONE 0" "#ifndef __cplusplus"$'\n'"#define NONE 0" \
          --replace-fail "#define DEBUG 3" "#define DEBUG 3"$'\n'"#endif"
        cat >> "$SDK/include/debugnet.h" <<'EOF'

        #ifndef DEBUGNET_NONE
        #define DEBUGNET_NONE 0
        #endif
        #ifndef DEBUGNET_INFO
        #define DEBUGNET_INFO 1
        #endif
        #ifndef DEBUGNET_ERROR
        #define DEBUGNET_ERROR 2
        #endif
        #ifndef DEBUGNET_DEBUG
        #define DEBUGNET_DEBUG 3
        #endif
        EOF

        mkdir -p "$TMPDIR/orbis-archive"/{debugnet,pad,audio}
        (cd "$TMPDIR/orbis-archive/debugnet" && llvm-ar x "$SDK/lib/libdebugnet.a")
        (cd "$TMPDIR/orbis-archive/pad" && llvm-ar x "$SDK/lib/liborbisPad.a")
        (cd "$TMPDIR/orbis-archive/audio" && llvm-ar x "$SDK/lib/liborbisAudio.a")
        cat > "$TMPDIR/orbis-file-compat.c" <<'EOF'
        #include <stdio.h>
        #include <stdlib.h>
        #include <orbisFile.h>
        size_t _orbisFile_lastopenFile_size;
        unsigned char *orbisFileGetFileContent(const char *filename) {
          FILE *f = fopen(filename, "rb");
          if (!f) return NULL;
          if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
          long size = ftell(f);
          if (size < 0) { fclose(f); return NULL; }
          rewind(f);
          unsigned char *buffer = (unsigned char *)malloc((size_t)size + 1);
          if (!buffer) { fclose(f); return NULL; }
          size_t read_size = fread(buffer, 1, (size_t)size, f);
          fclose(f);
          if (read_size != (size_t)size) { free(buffer); return NULL; }
          buffer[size] = 0;
          _orbisFile_lastopenFile_size = (size_t)size;
          return buffer;
        }
        int orbisFileInit(void) { return 0; }
        void orbisFileFinish(void) {}
        EOF
        clang --target=x86_64-scei-ps4 -isysroot "$SDK" -I"$SDK/include" -c "$TMPDIR/orbis-file-compat.c" -o "$TMPDIR/orbis-file-compat.o"
        llvm-ar rcs "$SDK/lib/liborbis.a" \
          "$TMPDIR"/orbis-archive/debugnet/*.o \
          "$TMPDIR"/orbis-archive/pad/*.o \
          "$TMPDIR"/orbis-archive/audio/*.o \
          "$TMPDIR/orbis-file-compat.o"

        build_orbisdev_lib utils-src
        substituteInPlace "$SDK/include/user_mem.h" \
          --replace-fail "#define SCE_KERNEL_MAP_FIXED 0x10" "#define SCE_KERNEL_MAP_FIXED 0x10"$'\n'"#if defined(__cplusplus)"$'\n'"#include <cstddef>"$'\n'"#include <new>"$'\n'"#endif" \
          --replace-fail "void *user_new(std::size_t size) throw(std::bad_alloc);" "void *user_new(std::size_t size) noexcept(false);" \
          --replace-fail "void *user_new_array(std::size_t size) throw(std::bad_alloc);" "void *user_new_array(std::size_t size) noexcept(false);"

        build_orbisdev_lib libSQLite-src

        cat > liborbis-src/portlibs/libfreetype-gl/include/vec234.h <<'EOF'
        #ifndef __VEC234_H__
        #define __VEC234_H__
        typedef int ivec2 __attribute__((ext_vector_type(2)));
        typedef int ivec3 __attribute__((ext_vector_type(3)));
        typedef int ivec4 __attribute__((ext_vector_type(4)));
        typedef float vec2 __attribute__((ext_vector_type(2)));
        typedef float vec3 __attribute__((ext_vector_type(3)));
        typedef float vec4 __attribute__((ext_vector_type(4)));
        #endif /* __VEC234_H__ */
        EOF

        substituteInPlace liborbis-src/portlibs/libfreetype-gl/source/texture-atlas.c \
          --replace-fail "ivec3 node = {{1,1,width-2}};" "ivec3 node = {1, 1, width - 2};" \
          --replace-fail "ivec4 region = {{0,0,width,height}};" "ivec4 region = {0, 0, width, height};" \
          --replace-fail "region.width = 0;" "region.z = 0;" \
          --replace-fail "region.height = 0;" "region.w = 0;" \
          --replace-fail "ivec3 node = {{1,1,1}};" "ivec3 node = {1, 1, 1};"
        substituteInPlace liborbis-src/portlibs/libfreetype-gl/source/vertex-buffer.c \
          --replace-fail "item->istart" "item->z" \
          --replace-fail "item->icount" "item->w" \
          --replace-fail "item->vstart" "item->x" \
          --replace-fail "item->vcount" "item->y"

        perl -0pi -e 's/(Texture font structure\.\s+\*\/\s*)typedef struct/$1typedef struct texture_font_t/s' liborbis-src/portlibs/libfreetype-gl/include/texture-font.h
        perl -0pi -e 's/(texture_font_new\( texture_atlas_t \* atlas,\s*const char \* filename,\s*const float size \);)/$1\n\n  texture_font_t *\n  texture_font_new_from_memory( texture_atlas_t * atlas,\n                                const float size,\n                                const void * memory_base,\n                                size_t memory_size );/s' liborbis-src/portlibs/libfreetype-gl/include/texture-font.h
        perl -0pi -e 's/#ifdef __cplusplus\s*\}\s*#endif\s*#endif \/\* __TEXTURE_FONT_H__ \*\//#ifdef __cplusplus\n}\n\n#include <cstring>\n#include <vector>\n\nstatic inline texture_glyph_t *\ntexture_font_get_glyph(texture_font_t *self, const char *charcode)\n{\n    return texture_font_get_glyph(self, charcode && *charcode ? (wchar_t)(unsigned char)*charcode : 0);\n}\n\nstatic inline size_t\ntexture_font_load_glyphs(texture_font_t *self, const char *charcodes)\n{\n    if (!charcodes) {\n        return texture_font_load_glyphs(self, (const wchar_t *)0);\n    }\n\n    const size_t length = std::strlen(charcodes);\n    std::vector<wchar_t> wide(length + 1);\n    for (size_t i = 0; i < length; ++i) {\n        wide[i] = (wchar_t)(unsigned char)charcodes[i];\n    }\n    wide[length] = 0;\n    return texture_font_load_glyphs(self, wide.data());\n}\n\nstatic inline float\ntexture_glyph_get_kerning(const texture_glyph_t *self, const char *charcode)\n{\n    return texture_glyph_get_kerning(self, charcode && *charcode ? (wchar_t)(unsigned char)*charcode : 0);\n}\n#endif\n\n#endif \/* __TEXTURE_FONT_H__ *\//s' liborbis-src/portlibs/libfreetype-gl/include/texture-font.h

        substituteInPlace liborbis-src/portlibs/libfreetype-gl/source/texture-font.c \
          --replace-fail "static FT_Byte *buffer = NULL;  // stores ttf font data" "static FT_Byte *buffer = NULL;  // stores ttf font data"$'\n'"static int buffer_owned = 0;" \
          --replace-fail "if(!buffer) buffer = orbisFileGetFileContent(filename);" "if(!buffer) {"$'\n'"        buffer = orbisFileGetFileContent(filename);"$'\n'"        buffer_owned = buffer != NULL;"$'\n'"    }" \
          --replace-fail "if(buffer) free(buffer), buffer = NULL;" "if(buffer && buffer_owned) free(buffer);"$'\n'"    buffer = NULL;"$'\n'"    buffer_owned = 0;"
        perl -0pi -e 's!(// ------------------------------------------------------- texture_font_new ---)!// ------------------------------------------- texture_font_new_from_memory ---\ntexture_font_t *\ntexture_font_new_from_memory( texture_atlas_t * atlas,\n                              const float size,\n                              const void * memory_base,\n                              size_t memory_size )\n{\n    assert( memory_base );\n    assert( memory_size );\n\n    buffer = (FT_Byte *) memory_base;\n    _orbisFile_lastopenFile_size = memory_size;\n    buffer_owned = 0;\n\n    return texture_font_new( atlas, "<memory>", size );\n}\n\n\n$1!s' liborbis-src/portlibs/libfreetype-gl/source/texture-font.c

        cat > "$TMPDIR/freetype-gl-compat.h" <<'EOF'
        #include <proto-include.h>
        #ifdef __cplusplus
        extern "C" {
        #endif
        void FT_Set_Transform(FT_Face face, FT_Matrix *matrix, FT_Vector *delta);
        #ifdef __cplusplus
        }
        #endif
        EOF
        make -C liborbis-src/portlibs/libfreetype-gl clean all install \
          Cf="-include $TMPDIR/freetype-gl-compat.h $COMMON_CF -I$SDK/include/freetype2 -I$SDK/include/freetype2/freetype/config" \
          Cppf="-include $TMPDIR/freetype-gl-compat.h $COMMON_CXXF -I$SDK/include/freetype2 -I$SDK/include/freetype2/freetype/config"

        build_orbisdev_lib external/taglib
        build_orbisdev_lib external/libfuse
        build_orbisdev_lib external/libdumper

        cat > "$SDK/include/itemzflow-app-compat.hpp" <<'EOF'
        #pragma once
        #include <sys/time.h>
        #include <audioout.h>
        #include <orbisAudio.h>
        #include <orbisNfs.h>
        #include <orbisPad.h>

        #ifdef __cplusplus
        extern "C" {
        #endif
        void finishOrbisLinkApp(void);
        int sceShellUIUtilInitialize(void);
        #ifdef __cplusplus
        }
        #endif

        typedef struct OrbisGlobalConf
        {
            void *conf;
            OrbisPadConfig *confPad;
            OrbisAudioConfig *confAudio;
            void *confKeyboard;
            void *confLink;
            int orbisLinkFlag;
        } OrbisGlobalConf;
        EOF
        cat > "$TMPDIR/itemzflow-compat.c" <<'EOF'
        void loadModulesVanilla(void) {}
        EOF
        cat > "$TMPDIR/itemzflow-compat.cpp" <<'EOF'
        #include "itemzflow-app-compat.hpp"
        OrbisGlobalConf globalConf = {};
        extern "C" void finishOrbisLinkApp(void) {}
        extern "C" int sceShellCoreUtilLaunchByUri(const char *uri, void *param);
        extern "C" int sceShellUIUtilInitialize(void) { return 0; }
        extern "C" int sceShellUIUtilLaunchByUri(const char *uri, void *param) {
            return sceShellCoreUtilLaunchByUri(uri, param);
        }
        EOF
        clang --target=x86_64-scei-ps4 -isysroot "$SDK" -I"$SDK/include" -I"$SDK/include/c++/v1" -c "$TMPDIR/itemzflow-compat.c" -o "$TMPDIR/itemzflow-compat-c.o"
        clang++ --target=x86_64-scei-ps4 -isysroot "$SDK" -I"$SDK/include" -I"$SDK/include/c++/v1" -std=c++17 -c "$TMPDIR/itemzflow-compat.cpp" -o "$TMPDIR/itemzflow-compat-cxx.o"
        llvm-ar rcs "$SDK/lib/libitemzflow-compat.a" "$TMPDIR/itemzflow-compat-c.o" "$TMPDIR/itemzflow-compat-cxx.o"

        sqlite3 App-Media-Assets/assets/vapps.db \
          "CREATE TABLE itemzflow_usb_games (TID TEXT PRIMARY KEY, Title TEXT NOT NULL, GM_PATH TEXT NOT NULL);"
        pkgTool sfo_setentry --value 01.08 App-Media-Assets/sce_sys/param.sfo APP_VER
        pkgTool sfo_setentry --value 01.08 App-Media-Assets/sce_sys/param.sfo VERSION

        APP_COMMON_CF="-DSTBI_NO_SIMD -DDR_MP3_NO_SIMD -D_GNU_SOURCE -I$SDK/usr/include -I$SDK/include -I$SDK/include/c++/v1 -I$SDK/include/orbis/_types -I$SDK/include/freetype-gl"
        APP_CF="-Iinclude -I. -include stdbool.h -include dirent.h $APP_COMMON_CF"
        APP_CXXF="-Iinclude -I. -include $SDK/include/itemzflow-app-compat.hpp -include stdbool.h -include dirent.h -Wno-macro-redefined -Wno-missing-braces $APP_COMMON_CF"
        AUTH_INFO="000000000000000000000000001C004000FF000000000080000000000000000000000000000000000000008000400040000000000000008000000000000000080040FFFF000000F000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

        make -C itemz-loader clean all \
          Lf="--as-needed" \
          Cf="$APP_CF -Wno-implicit-function-declaration" \
          Cppf="$APP_CXXF" \
          Libraries="-lc"
        create-fself \
          -in itemz-loader/bin/homebrew.elf \
          -out itemz-loader/bin/homebrew.oelf \
          -eboot itemz-loader/bin/eboot.bin \
          -ptype fake \
          -authinfo "$AUTH_INFO"

        make -C itemz-daemon clean all \
          Lf="--as-needed" \
          Cf="$APP_CF" \
          Cppf="$APP_CXXF" \
          Libraries="-litemzflow-compat -lorbisNfs -lorbis -lc"
        create-fself \
          -in itemz-daemon/bin/daemon.elf \
          -out itemz-daemon/bin/daemon.oelf \
          -eboot itemz-daemon/bin/eboot.bin \
          -ptype fake \
          -authinfo "$AUTH_INFO"

        make -C itemzflow clean all \
          Lf="--as-needed" \
          Cf="$APP_CF" \
          Cppf="$APP_CXXF" \
          Libraries="-litemzflow-compat -lorbisNfs -lorbis -lSceFreeType_stub -lpng -lz -lc"
        create-fself \
          -in itemzflow/bin/homebrew.elf \
          -out itemzflow/bin/homebrew.oelf \
          -eboot itemzflow/bin/ItemzCore.self \
          -ptype fake \
          -authinfo "$AUTH_INFO"

        (cd itemzflow && pkgTool pkg_build ../App-Media-Assets/itemzflow.gp4 .)

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        install -Dm644 itemzflow/IV0002-ITEM00001_00-STOREUPD00000000.pkg \
          "$out/share/itemzflow/IV0002-ITEM00001_00-STOREUPD00000000.pkg"
        install -Dm644 itemz-loader/bin/eboot.bin "$out/share/itemzflow/eboot.bin"
        install -Dm644 itemz-daemon/bin/eboot.bin "$out/share/itemzflow/daemon.self"
        install -Dm644 itemz-daemon/bin/daemon.oelf "$out/share/itemzflow/daemon.oelf"
        install -Dm644 itemzflow/bin/ItemzCore.self "$out/share/itemzflow/ItemzCore.self"

        runHook postInstall
      '';

      meta = {
        description = "Itemzflow Game Manager for PS4";
        homepage = "https://github.com/LightningMods/Itemzflow";
        platforms = [ "x86_64-linux" ];
      };
    };
  }
)
