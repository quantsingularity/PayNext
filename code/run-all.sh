#!/usr/bin/env bash
# run-all.sh — build and start all PayNext services locally.
# Run from the project root (code/).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$ROOT/backend"
ML="$ROOT/ml-services"

usage() {
    cat <<'USAGE'
Usage: ./run-all.sh [options]

Options:
  (no option)   Train only ML models that are missing, then build and start.
  --force-ml    Retrain all ML models even if their artifacts already exist.
  --skip-ml     Skip ML training entirely (use existing model artifacts).
  -h, --help    Show this help and exit.
USAGE
}

SKIP_ML=false
FORCE_ML=false
for arg in "$@"; do
    case "$arg" in
        --skip-ml) SKIP_ML=true ;;
        --force-ml) FORCE_ML=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg (use --help)" >&2; exit 1 ;;
    esac
done

echo "=== PayNext — Starting all services ==="

# 1. Train ML models. train_all.py skips models that already exist unless --force.
if [[ "$SKIP_ML" == true ]]; then
    echo "[1/3] Skipping ML training (--skip-ml)."
else
    echo "[1/3] Training ML models (only those not already trained)..."
    # Quiet TensorFlow info logs and the deprecation / feature-name warnings that
    # otherwise flood the console during training. Real errors are still shown.
    export TF_CPP_MIN_LOG_LEVEL="${TF_CPP_MIN_LOG_LEVEL:-2}"
    export PYTHONWARNINGS="${PYTHONWARNINGS:-ignore::FutureWarning,ignore::UserWarning}"
    cd "$ML"
    if [[ "$FORCE_ML" == true ]]; then
        python train_all.py --force || echo "Warning: some ML models failed to train"
    else
        python train_all.py || echo "Warning: some ML models failed to train"
    fi
fi

# 2. Build Java services
echo "[2/3] Building Java services..."
cd "$BACKEND"
mvn clean package -DskipTests -q

# 3. Launch everything via Docker Compose
echo "[3/3] Starting services via Docker Compose..."
cd "$ROOT"
docker-compose up --build -d

echo ""
echo "Services starting. Check health with: docker-compose ps"
