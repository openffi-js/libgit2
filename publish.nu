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

def prepare-packages [ version: string, artifacts_dir: string, resources_path: string ] {
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
    }
    | flatten
    | append [
      { src: ($resources_path | path join "index-all.js"), dst: "index.js" }
      { src: ($resources_path | path join "index.d.ts"), dst: "index.d.ts" }
    ]
  );

  create-package-dir $NAME {
    name: $"($ORG)/($NAME)",
    version: $version,
    optionalDependencies: (
      $subpackages | each { [ $"($ORG)/($in)" $version ] } | into record
    ),
  } [
    { src: ($resources_path | path join "index.js"), dst: "index.js"}
    { src: ($resources_path | path join "index.d.ts"), dst: "index.d.ts"}
  ];

  [
    ...$subpackages
    $all_package_name
    $NAME
  ]
}


def publish-package [ package_dir: string ] {
  cd $package_dir;
  ^bun publish --access public --tag latest
}

def main [] {
  let version = open "./library-version.txt" | str trim;
  let npm_version = open "./npm-version.txt" | str trim;
  let resources_path = "./resources" | path expand;

  let build_dir = "./build" | path expand | path join (date now | format date "%F-%H-%M-%S");
  let artifacts_dir = $build_dir | path join "artifacts";
  mkdir $artifacts_dir;

  let run_id = ^gh run list -R openffi-js/libgit2 -w 'Build' -L 1 --json databaseId | from json | get 0.databaseId;
  ^gh run download $run_id --dir $artifacts_dir;

  let version_str = if $npm_version == null {
    $version
  } else {
    $"($version)-($npm_version)"
  };

  cd $build_dir;
  let prepared_packages = prepare-packages $version_str $artifacts_dir $resources_path;
  $prepared_packages | each { publish-package $in };
}
