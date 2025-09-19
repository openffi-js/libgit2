#!/usr/bin/env nu

let ORG = "@static-libs";
let NAME = "libgit2";
let TARGETS = [
  [os arch];
  ["linux" "x64"]
  ["linux" "arm64"]
  ["darwin" "x64"]
  ["darwin" "arm64"]
  ["windows" "x64"]
];

def create-package [name: string, version: string, os: string, arch: string] {
  let full_name = $"($name)-($os)-($arch)";
  print $"Creating package '($full_name)'...";
  if not ($full_name | path exists) {
    print $"Error: directory '($full_name)' does not exist.";
    exit 1;
  }

  let lib_files = glob $"($full_name)/*";
  let lib_dir = $full_name | path join "lib";
  mkdir $lib_dir;
  mv ...$lib_files $lib_dir;

  {
    name: $"($ORG)/($full_name)",
    version: $version,
    os: [ (if $os == "windows" { "win32" } else { $os }) ],
    cpu: [ $arch ],
  } | save -f ($full_name | path join "package.json");

  $full_name
}

def publish [ version: string, index_js_path: string ] {
  let subpackages = $TARGETS | each {
    let subpackage_name = create-package $NAME $version $in.os $in.arch;
    cd $subpackage_name;
    ^bun publish --access public --tag latest;
    cd ..;
    $subpackage_name
  };

  mkdir $NAME;

  let full_name = $"($ORG)/($NAME)";
  {
    name: $full_name,
    version: $version,
    optionalDependencies: (
      $subpackages | each { [ $"($ORG)/($in)" $version ] } | into record
    ),
  } | save -f ($NAME | path join "package.json");
  cp $index_js_path ($NAME | path join "index.js");

  cd $NAME;
  ^bun publish --access public --tag latest;
}

def main [ workflow_run_url: string, version_suffix?: string ] {
  let run_id = $workflow_run_url | path basename;
  let version = open "version.txt" | str trim;
  let index_js_path = "./index.js" | path expand;

  let build_dir = $"($run_id)($version_suffix)";
  mkdir $build_dir;
  cd $build_dir;
  ^gh run download $run_id;

  if $version_suffix == null {
    publish $version $index_js_path;
  } else {
    publish $"($version)-($version_suffix)" $index_js_path;
  }
}
