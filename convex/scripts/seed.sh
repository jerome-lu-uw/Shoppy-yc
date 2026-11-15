#!/bin/bash
# Synchronizes Convex with SeedCatalog, removing products that are no longer present.
set -euo pipefail
export PATH=/opt/homebrew/bin:$PATH
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/Sources/dump"
cat > "$TMP/Package.swift" <<EOF
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "dump",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "$ROOT/ShoppyCore")],
    targets: [.executableTarget(name: "dump", dependencies: [.product(name: "ShoppyCore", package: "ShoppyCore")])]
)
EOF
cat > "$TMP/Sources/dump/main.swift" <<'EOF'
import Foundation
import ShoppyCore
let encoder = JSONEncoder()
FileHandle.standardOutput.write(try encoder.encode(SeedCatalog.products))
EOF
(cd "$TMP" && swift run -q dump) > "$TMP/products.json"
node -e '
const fs = require("fs");
const products = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).map(({ id, ...rest }) => ({ productId: id, ...rest }));
fs.writeFileSync(process.argv[1], JSON.stringify({ products }));
' "$TMP/products.json"
cd "$ROOT" && npx convex run catalog:seed "$(cat "$TMP/products.json")" "$@"
