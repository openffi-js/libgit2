import { dlopen, FFIType } from "bun:ffi";

const path = "/nix/store/798sjv6krarrqs7glw6s93mc33bwav1a-tarunlibgit2-1.9.1-lib/lib/libgit2.so.1.9.1";

// int git_libgit2_version(int *major, int *minor, int *rev);
const {
  symbols: { git_libgit2_version },
} = dlopen(path, {
  git_libgit2_version: {
    args: ["ptr", "ptr", "ptr"],
    returns: FFIType.i32,
  },
});

const major = new Int32Array(1);
const minor = new Int32Array(1);
const rev = new Int32Array(1);
const ret = git_libgit2_version(major, minor, rev);
console.log(ret, major[0], minor[0], rev[0]);
