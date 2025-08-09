#!/usr/bin/env bash
set -euo pipefail

#############################################
# Logging & safety
#############################################
LOG_DIR="${HOME}/.cache/drone-rpi3"
BUILD_LOG="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${BUILD_LOG}") 2>&1

log() {
  # prints: [YYYY-mm-dd HH:MM:SS] [install.sh:func:LINE] message
  local ts func line
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  func="${FUNCNAME[1]:-main}"
  line="${BASH_LINENO[0]:-0}"
  printf '[%s] [%s:%s:%s] %s\n' "$ts" "$(basename "$0")" "$func" "$line" "$*"
}

trap 'rc=$?; log "ERROR exit code $rc at line ${BASH_LINENO[0]}"; exit $rc' ERR

if [[ ${EUID} -eq 0 ]]; then
  log "Refusing to run as root. Re-run as a normal user (sudo will be used when needed)."
  exit 1
fi

#############################################
# Resolve paths / project layout
#############################################
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
# Support running from install/ or repo root
if [[ -f "${SCRIPT_DIR}/../requirements.txt" ]]; then
  PROJECT_DIR="$(realpath "${SCRIPT_DIR}/..")"
else
  PROJECT_DIR="$(realpath "${SCRIPT_DIR}")"
fi
HOME_DIR="${HOME}"

log "Project dir: ${PROJECT_DIR}"
cd "${PROJECT_DIR}"

# ARM / OS checks (Pi 3 + Emlid 32-bit)
ARCH="$(uname -m || true)"
KERNEL="$(uname -r || true)"
if [[ "${ARCH}" != "armv7l" && "${ARCH}" != "armhf" ]]; then
  log "Warning: expected armv7 (Pi 3 32-bit). Detected ${ARCH} (kernel ${KERNEL}). Continuing anyway."
fi

#############################################
# Apt packages
#############################################
log "[1/12] updating apt index..."
sudo apt-get update -y

log "[2/12] installing system packages (no opencv-python via pip)..."
sudo apt-get install -y \
  python3 python3-venv python3-pip python3-dev \
  python3-opencv \
  build-essential git pkg-config \
  libusb-1.0-0 libudev1 udev \
  unzip curl ca-certificates

# Helpful tools for diagnostics
sudo apt-get install -y usbutils || true

#############################################
# Python venv (inherits system site-packages)
#############################################
log "[3/12] creating/using virtual environment with system site-packages..."
cd "${PROJECT_DIR}"
if [[ -d ".venv" ]]; then
  log "Existing .venv found; leaving it in place."
else
  python3 -m venv --system-site-packages .venv
  log "Created .venv with --system-site-packages."
fi

# Safe activate with nounset
set +u
# shellcheck disable=SC1091
source ".venv/bin/activate"
set -u
python -V
pip -V

#############################################
# Python deps (from requirements.txt)
#############################################
REQ="${PROJECT_DIR}/requirements.txt"
if [[ -f "${REQ}" ]]; then
  log "[4/12] installing Python requirements..."
  # DO NOT add opencv-python here; we rely on python3-opencv from apt.
  pip install --upgrade pip wheel
  pip install -r "${REQ}"
else
  log "No requirements.txt found; skipping."
fi

#############################################
# Clone & build Navio2 Python wheel (if missing)
#############################################
NAVIO2_GIT="https://github.com/emlid/Navio2.git"
NAVIO2_DIR="${HOME_DIR}/Navio2"
NAVIO2_PYTHON_DIR="${NAVIO2_DIR}/Python"
NAVIO2_WHEEL="${NAVIO2_PYTHON_DIR}/dist/navio2-1.0.0-py3-none-any.whl"

log "[5/12] preparing Navio2 sources..."
if [[ ! -d "${NAVIO2_DIR}/.git" ]]; then
  git clone --depth=1 "${NAVIO2_GIT}" "${NAVIO2_DIR}"
else
  (cd "${NAVIO2_DIR}" && git fetch --depth=1 && git reset --hard origin/master) || true
fi

log "[6/12] building Navio2 Python wheel (if missing)..."
if [[ ! -f "${NAVIO2_WHEEL}" ]]; then
  cd "${NAVIO2_PYTHON_DIR}"
  python -m pip install --upgrade build
  python -m build --wheel
else
  log "Navio2 wheel already exists: ${NAVIO2_WHEEL}"
fi

log "[7/12] installing Navio2 wheel into venv..."
pip install --force-reinstall "${NAVIO2_WHEEL}"

#############################################
# OpenNI SDK wiring (from repo sdks folder if present)
#############################################
ARM_VERSION="Arm-Release"
OPENNISDK_SOURCE="${PROJECT_DIR}/sdks/${ARM_VERSION}"
OPENNISDK_DIR="${HOME_DIR}/openni"
OPENNISDK_DEST="${OPENNISDK_DIR}/${ARM_VERSION}"
OPENNI2_REDIST_DIR="${OPENNISDK_DEST}/Redist"
SIMPLE_READ_EXAMPLE="${OPENNISDK_DEST}/Samples/SimpleRead"

if [[ -d "${OPENNISDK_SOURCE}" ]]; then
  log "[8/12] installing OpenNI SDK files..."
  mkdir -p "${OPENNISDK_DIR}"
  rsync -a --delete "${OPENNISDK_SOURCE}/" "${OPENNISDK_DEST}/"
  # Export and persist OPENNI2_REDIST
  if ! grep -Eq '^export OPENNI2_REDIST=' "${HOME_DIR}/.bashrc"; then
    echo "export OPENNI2_REDIST='${OPENNI2_REDIST_DIR}'" >> "${HOME_DIR}/.bashrc"
    log "Added OPENNI2_REDIST to ~/.bashrc"
  fi
  export OPENNI2_REDIST="${OPENNI2_REDIST_DIR}"

  # Deploy redistributables into /lib so the loader can find them
  log "[9/12] copying OpenNI redistributables into /lib..."
  sudo cp -r "${OPENNI2_REDIST_DIR}/"* "/lib/" || true
else
  log "OpenNI SDK folder not found at ${OPENNISDK_SOURCE}; skipping copy."
  # Still attempt to set OPENNI2_REDIST if a previous install exists
  if [[ -d "${OPENNI2_REDIST_DIR}" ]]; then
    export OPENNI2_REDIST="${OPENNI2_REDIST_DIR}"
  fi
fi

#############################################
# Hardware check (optional prompt)
#############################################
log "[10/12] optional: plug in the Orbbec Astra Mini S via USB, then press ENTER (or Ctrl+C to skip)."
read -r -p "" _ || true
lsusb | grep -i -E 'orbbec|astra' || log "Note: Orbbec device not detected via lsusb; continuing."

#############################################
# Verifications (cv2, openni, wheels, binaries)
#############################################
log "[11/12] verifying Python imports (cv2, openni)..."
python - <<'PY'
import sys
ok = True
print("[verify] Python:", sys.version)
try:
    import cv2
    print("[verify] OK cv2:", cv2.__version__, "from", cv2.__file__)
except Exception as e:
    ok = False
    print("[verify] FAIL: cv2 import:", e)
try:
    import openni
    from openni import openni2
    print("[verify] OK openni package; initializing...")
    try:
        openni2.initialize()
        print("[verify] OK openni2.initialize()")
        openni2.unload()
    except Exception as e:
        print("[verify] WARN: openni2.initialize() failed:", e)
except Exception as e:
    ok = False
    print("[verify] FAIL: openni import:", e)
if not ok:
    raise SystemExit(1)
PY

# Basic OpenNI sample presence
if [[ -d "${SIMPLE_READ_EXAMPLE}" ]]; then
  file "${SIMPLE_READ_EXAMPLE}/Bin/${ARM_VERSION}/SimpleRead" || true
fi
file "${NAVIO2_WHEEL}" || true

#############################################
# Finish
#############################################
set +u
deactivate || true
set -u

log "[12/12] install complete ✅"
log "Logs saved to: ${BUILD_LOG}"

echo
echo "Next steps:"
echo "  cd ${PROJECT_DIR}"
echo "  source .venv/bin/activate"
echo "  python3 -m test-body-detector"
echo "  python3 -m test-motors"
