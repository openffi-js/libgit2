import fs from "fs"
import os from "os"
import path from "path"
import { createRequire } from "module"

const require = createRequire(import.meta.url)

function findLib() {
  const platform = os.platform();
  const arch = os.arch();
  const packageName = `@openffi/libgit2-${platform}-${arch}`
  const extension = platform === "win32" ? "dll" : platform === "darwin" ? "dylib" : "so"

  try {
    // Use require.resolve to find the package
    const packageJsonPath = require.resolve(`${packageName}/package.json`)
    const packageDir = path.dirname(packageJsonPath)
    const libraryPath = path.join(packageDir, "lib", `libgit2.${extension}`)

    if (!fs.existsSync(libraryPath)) {
      throw new Error(`Library not found at ${libraryPath}`)
    }

    return libraryPath
  } catch (error) {
    throw new Error(`Could not find package ${packageName}: ${error.message}`)
  }
}

const libraryPath = findLib()
export default libraryPath
