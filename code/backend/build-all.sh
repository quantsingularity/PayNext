#!/usr/bin/env bash
# build-all.sh — Build all Java microservices from the backend/ directory
# Usage: cd backend/ && ./build-all.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building all PayNext Java microservices ==="
echo "Working directory: $SCRIPT_DIR"

mvn clean package -DskipTests -B --no-transfer-progress

echo ""
echo "=== Build complete ==="
echo "Artifacts:"
find . -name "*.jar" -path "*/target/*.jar" ! -name "*sources*" ! -name "*javadoc*" -print0 \
  | while IFS= read -r -d '' jar; do
  echo "  $jar"
done
