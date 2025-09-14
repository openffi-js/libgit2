import { dlopen, FFIType } from "bun:ffi";
import os from "os";

let path: string;
const platform = os.platform();
if (platform === "darwin") {
  path = "./result-lib/lib/libgit2.1.9.dylib";
} else {
  path = "./result-lib/bin/libgit2.so.1.9.1";
}

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
