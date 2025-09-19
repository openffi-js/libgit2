# Static LibGit2

Use libgit2 seamlessly in JavaScript without any external dependencies. This package provides libgit2 as a dynamic library, statically compiled against its dependencies. This enables usage of the library with Bun/Node.js FFI.

## Installation

```bash
npm install @openffi/libgit2 # with npm
bun add @openffi/libgit2     # with Bun
```

## Usage

### Bun FFI Example

```typescript
import { dlopen, FFIType } from "bun:ffi";
import libgit2 from "@openffi/libgit2";

// int git_libgit2_version(int *major, int *minor, int *rev);
const {
  symbols: { git_libgit2_version },
} = dlopen(libgit2, {
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
```

## Platform Support

- ✅ Linux (x64, ARM64)
- ✅ macOS (x64, ARM64)
- ✅ Windows (x64)

## Development

This project uses Nix for reproducible builds. To build the static libraries:

```bash
nix build
```

## License

MIT License - see LICENSE file for details.
