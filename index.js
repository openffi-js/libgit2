import fs from "fs"
import os from "os"
import path from "path"
import { createRequire } from "module"

const require = createRequire(import.meta.url)

function detectPlatformAndArch() {
  // Map platform names
  let platform
  switch (os.platform()) {
    case "darwin":
      platform = "darwin"
      break
    case "linux":
      platform = "linux"
      break
    case "win32":
      platform = "windows"
      break
    default:
      platform = os.platform()
      break
  }

  // Map architecture names
  let arch
  switch (os.arch()) {
    case "x64":
      arch = "x64"
      break
    case "arm64":
      arch = "arm64"
      break
    case "arm":
      arch = "arm"
      break
    default:
      arch = os.arch()
      break
  }

  return { platform, arch }
}

function findLib() {
  const { platform, arch } = detectPlatformAndArch()
  const packageName = `@static-libs/libgit2-${platform}-${arch}`
  const extension = platform === "windows" ? "dll" : platform === "darwin" ? "dylib" : "so"

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
