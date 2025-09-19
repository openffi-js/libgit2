#!/usr/bin/env nu

let ORG = "@openffi";
let NAME = "libgit2";
let TARGETS = [
  [os arch];
  ["linux" "x64"]
  ["linux" "arm64"]
  ["darwin" "x64"]
  ["darwin" "arm64"]
  ["win32" "x64"]
];

def create-package-dir [ name: string, package_json: record, files: table ] {
  mkdir $name;
  $package_json | save -f ($name | path join "package.json");
  $files | each { |f|
    let src = $f.src | path expand;
    let dst = ($name | path join $f.dst);
    mkdir ($dst | path dirname);
    cp $src $dst;
  };
}

def prepare-packages [ version: string, artifacts_dir: string, index_js_path: string ] {
  let subpackages = $TARGETS | each {
    let os = $in.os;
    let arch = $in.arch;

    let subpackage_name = $"($NAME)-($os)-($arch)";
    create-package-dir $subpackage_name {
      name: $"($ORG)/($subpackage_name)",
      version: $version,
      os: [ $os ],
      cpu: [ $arch ],
    } (glob $"($artifacts_dir)/libgit2-($os)-($arch)/*" | each { { src: $in, dst: $"lib/($in | path basename)" } });

    $subpackage_name
  };

  let all_package_name = $"($NAME)-all";
  create-package-dir $all_package_name {
    name: $"($ORG)/($all_package_name)",
    version: $version,
  } (
    $TARGETS | each {
      let os = $in.os;
      let arch = $in.arch;
      glob $"($artifacts_dir)/libgit2-($os)-($arch)/*" | each { { src: $in, dst: $"lib/($os)-($arch)/($in | path basename)" } }
    } | flatten
  );

  create-package-dir $NAME {
    name: $"($ORG)/($NAME)",
    version: $version,
    optionalDependencies: (
      $subpackages | each { [ $"($ORG)/($in)" $version ] } | into record
    ),
  } [{ src: $index_js_path, dst: "index.js"}];

  [
    ...$subpackages
    $all_package_name
    $NAME
  ]
}


def publish-package [ package_dir: string ] {
  cd $package_dir;
  ^npm publish --access public --tag latest
}

def main [ workflow_run_url: string, npm_version?: string ] {
  let run_id = $workflow_run_url | path basename;
  let version = open "./version.txt" | str trim;
  let index_js_path = "./index.js" | path expand;

  let build_dir = "./build" | path expand | path join (date now | format date "%F-%H-%M-%S");
  let artifacts_dir = $build_dir | path join "artifacts";
  mkdir $artifacts_dir;
  ^gh run download $run_id --dir $artifacts_dir;

  let version_str = if $npm_version == null {
    $version
  } else {
    $"($version)-($npm_version)"
  };

  cd $build_dir;
  let prepared_packages = prepare-packages $version_str $artifacts_dir $index_js_path;
  $prepared_packages | each { publish-package $in };
}
