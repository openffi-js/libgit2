let library;
if (process.platform === "linux" && process.arch === "x64") {
  library = require("./lib/linux-x64/libgit2.so");
} else if (process.platform === "linux" && process.arch === "arm64") {
  library = require("./lib/linux-arm64/libgit2.so");
} else if (process.platform === "win32" && process.arch === "x64") {
  library = require("./lib/win32-x64/libgit2.dll");
} else if (process.platform === "darwin" && process.arch === "x64") {
  library = require("./lib/darwin-x64/libgit2.dylib");
} else if (process.platform === "darwin" && process.arch === "arm64") {
  library = require("./lib/darwin-arm64/libgit2.dylib");
} else {
  throw new Error(`libgit2: unsupported platform or architecture: ${process.platform}-${process.arch}`);
}

export default library;
