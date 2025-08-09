#!/usr/bin/env bash
set -euo pipefail

# Safely source files even when nounset is enabled
safe_source() {
  # Usage: safe_source <path>
  # shellcheck disable=SC1090
  set +u
  . "$1"
  set -u
}


SCRIPT_NAME=$(basename "$0")

# --- Safety: do not run as root in your repo. ---
if [[ "${EUID}" -eq 0 ]]; then
  echo "Do not run this script with sudo. It will use sudo only when needed."
  exit 1
fi

# --- Resolve paths relative to the script location ---
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOME_DIR="${HOME}"
LOG_DIR="${HOME_DIR}/install_logs"
BUILD_LOG="${LOG_DIR}/install.log"

# --- Project-specific paths ---
ARM_VERSION="OpenNI-Linux-Arm-2.3.0.63"
OPENNISDK_SOURCE="${PROJECT_DIR}/sdks/${ARM_VERSION}"
OPENNISDK_DIR="${HOME_DIR}/openni"
OPENNISDK_DEST="${OPENNISDK_DIR}/${ARM_VERSION}"
GNU_LIB_DIR="/lib/arm-linux-gnueabihf"
SIMPLE_READ_EXAMPLE="${OPENNISDK_DEST}/Samples/SimpleRead"
OPENNI2_REDIST_DIR="${OPENNISDK_DEST}/Redist"

NAVIO2_GIT="https://github.com/emlid/Navio2.git"
NAVIO2_DIR="${HOME_DIR}/Navio2"
NAVIO2_PYTHON_DIR="${NAVIO2_DIR}/Python"
NAVIO2_WHEEL="${NAVIO2_PYTHON_DIR}/dist/navio2-1.0.0-py3-none-any.whl"

mkdir -p "${LOG_DIR}"
exec > >(tee "${BUILD_LOG}") 2>&1

log() {
  local message="$*"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local calling_function=${FUNCNAME[1]:-"main"}
  local line_number=${BASH_LINENO[0]:-0}
  echo -e "\n[${timestamp}] [${SCRIPT_NAME}:${calling_function}:${line_number}] ${message}\n"
}

log "[ 1/12] updating system packages..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -q dist-upgrade

log "[ 2/12] installing system packages..."
sudo apt-get install -y -q \
  build-essential freeglut3 freeglut3-dev \
  python3-opencv python3-venv python3-smbus python3-spidev python3-numpy python3-pip \
  curl npm nodejs gcc g++ make python3 usbutils
sudo apt-get install --reinstall -y -q libudev1

log "[ 3/12] preparing OpenNI SDK destination..."
rm -rf "${OPENNISDK_DIR}"
mkdir -p "${OPENNISDK_DIR}"

log "[ 4/12] copying OpenNI SDK from repo to home..."
if [[ ! -d "${OPENNISDK_SOURCE}" ]]; then
  echo "ERROR: Expected SDK source at ${OPENNISDK_SOURCE} not found."
  exit 1
fi
cp -r "${OPENNISDK_SOURCE}" "${OPENNISDK_DIR}"

log "[ 5/12] installing OpenNI SDK..."
cd "${OPENNISDK_DEST}"
chmod +x install.sh
sudo ./install.sh

log "[ 6/12] sourcing OpenNI dev environment..."
# shellcheck disable=SC1091
safe_source OpenNIDevEnvironment
read -p "→ OpenNI SDK installed. Replug your Orbbec device, then press ENTER. " _

log "[ 7/12] verifying Orbbec device..."
if lsusb | grep -q '2bc5:0407'; then
  echo "Orbbec Astra Mini S detected."
elif lsusb | grep -q '2bc5'; then
  echo "[ERROR] Different Orbbec device detected (e.g., Astra Pro)."
  exit 1
else
  echo "[ERROR] No Orbbec device found."
  exit 1
fi

log "[ 8/12] building OpenNI SimpleRead sample..."
cd "${SIMPLE_READ_EXAMPLE}"
make

log "[ 9/12] building Navio2 Python wheel (if missing)..."
if [[ ! -f "${NAVIO2_WHEEL}" ]]; then
  rm -rf "${NAVIO2_DIR}"
  git clone "${NAVIO2_GIT}" "${NAVIO2_DIR}"
  cd "${NAVIO2_PYTHON_DIR}"
  python3 -m venv env

  # --- protect activate/deactivate from 'set -u' ---
  # shellcheck disable=SC1091
  set +u
safe_source env/bin/activate
  set -u

  python3 -m pip install --upgrade pip wheel
  python3 setup.py bdist_wheel

  set +u
  deactivate
  set -u
else
  log "Navio2 wheel already exists: ${NAVIO2_WHEEL}"
fi

log "[10/12] creating/using project virtual environment..."
cd "${PROJECT_DIR}"
if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
fi

# --- protect activate/deactivate from 'set -u' ---
# shellcheck disable=SC1091
set +u
safe_source .venv/bin/activate
set -u

python3 -m pip install --upgrade pip
python3 -m pip install --force-reinstall --no-deps --no-index "${NAVIO2_WHEEL}"
python3 -m pip install -r requirements.txt

# Sanity check: this venv's python must import 'navio' (module name != dist name)
python3 - <<'PY'
import sys
try:
    import navio
    print("[verify] OK: ", sys.executable, "->", getattr(navio, "__file__", "built-in module"))
except Exception as e:
    print("[verify] FAIL importing 'navio' from", sys.executable, ":", e)
    raise SystemExit(1)
PY

set +u
deactivate
set -u

log "[11/12] exporting OPENNI2_REDIST if missing..."
if ! grep -Eq '^export OPENNI2_REDIST=' "${HOME_DIR}/.bashrc"; then
  echo "export OPENNI2_REDIST='${OPENNI2_REDIST_DIR}'" >> "${HOME_DIR}/.bashrc"
  echo "→ Added OPENNI2_REDIST to ~/.bashrc"
fi
export OPENNI2_REDIST="${OPENNI2_REDIST_DIR}"

log "[12/12] installing OpenNI redistributables into system lib..."
sudo cp -r "${OPENNI2_REDIST_DIR}/"* "/lib/"

log "[verify] checking builds..."
file "${SIMPLE_READ_EXAMPLE}/Bin/Arm-Release/SimpleRead" || true
file "${NAVIO2_WHEEL}" || true

log "✅ Install complete. Logs saved to: ${BUILD_LOG}"