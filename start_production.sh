#!/usr/bin/env bash
# AnimaWorks Production Startup Script
# 本番起動スクリプト
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Constants / 定数
# ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANIMAWORKS_DIR="/Users/kensmba/scripts/260107_orchestrator/animaworks"
VENV_DIR="${ANIMAWORKS_DIR}/.venv"
HOST="0.0.0.0"
PORT="18500"

# ─────────────────────────────────────────────────────────────
# Step 0: Change to animaworks directory
# ディレクトリ移動
# ─────────────────────────────────────────────────────────────
cd "${ANIMAWORKS_DIR}"

# ─────────────────────────────────────────────────────────────
# Step 1: Check virtual environment exists
# 仮想環境の存在確認
# ─────────────────────────────────────────────────────────────
if [ ! -d "${VENV_DIR}" ]; then
    echo ""
    echo "[ERROR] 仮想環境が見つかりません / Virtual environment not found"
    echo "  Path: ${VENV_DIR}"
    echo ""
    echo "  解決方法 / Fix:"
    echo "    cd ${ANIMAWORKS_DIR}"
    echo "    python3.12 -m venv .venv"
    echo "    source .venv/bin/activate"
    echo "    pip install -e ."
    echo ""
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Step 2: Activate virtual environment
# 仮想環境のアクティベート
# ─────────────────────────────────────────────────────────────
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

# ─────────────────────────────────────────────────────────────
# Step 3: Verify Python version (3.12 or 3.13 only)
# Pythonバージョン確認（3.12 or 3.13 のみ許可）
# ─────────────────────────────────────────────────────────────
PYTHON_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
PYTHON_MAJOR="$(python3 -c 'import sys; print(sys.version_info.major)')"
PYTHON_MINOR="$(python3 -c 'import sys; print(sys.version_info.minor)')"

if [ "${PYTHON_MAJOR}" -ne 3 ]; then
    echo ""
    echo "[ERROR] Python 3 が必要です / Python 3 is required"
    echo "  Current: Python ${PYTHON_VERSION}"
    echo ""
    exit 1
fi

if [ "${PYTHON_MINOR}" -lt 12 ] || [ "${PYTHON_MINOR}" -gt 13 ]; then
    echo ""
    echo "[ERROR] Python バージョン非対応 / Unsupported Python version"
    echo "  Current: Python ${PYTHON_VERSION}"
    echo "  Required: Python 3.12 or 3.13"
    echo ""
    if [ "${PYTHON_MINOR}" -ge 14 ]; then
        echo "  ⚠ Python 3.14+ は既知の互換性問題があります"
        echo "  ⚠ Python 3.14+ has known compatibility issues"
        echo ""
    fi
    echo "  解決方法 / Fix:"
    echo "    pyenv install 3.12.x && pyenv local 3.12.x"
    echo "    python3.12 -m venv .venv"
    echo ""
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Step 4: Verify claude_agent_sdk can be imported
# claude_agent_sdk インポート確認
# ─────────────────────────────────────────────────────────────
if ! SDK_VERSION="$(python3 -c "import claude_agent_sdk; print(f'claude_agent_sdk OK: {claude_agent_sdk.__version__}')" 2>&1)"; then
    echo ""
    echo "[ERROR] claude_agent_sdk のインポートに失敗しました / Failed to import claude_agent_sdk"
    echo "  Error: ${SDK_VERSION}"
    echo ""
    echo "  解決方法 / Fix:"
    echo "    pip install claude-agent-sdk"
    echo "    または / or: pip install -e ."
    echo ""
    exit 1
fi
echo "[OK] ${SDK_VERSION}"

# ─────────────────────────────────────────────────────────────
# Step 5: Verify bundled claude CLI exists
# バンドル済み claude CLI の存在確認
# ─────────────────────────────────────────────────────────────
if ! CLI_CHECK="$(python3 -c "
from pathlib import Path
import claude_agent_sdk
p = Path(claude_agent_sdk.__file__).parent / '_bundled' / 'claude'
assert p.exists(), f'Bundled CLI not found at {p}'
print(f'Bundled CLI OK: {p}')
" 2>&1)"; then
    echo ""
    echo "[ERROR] バンドル済み claude CLI が見つかりません / Bundled claude CLI not found"
    echo "  Error: ${CLI_CHECK}"
    echo ""
    echo "  解決方法 / Fix:"
    echo "    pip install --upgrade claude-agent-sdk"
    echo ""
    exit 1
fi
echo "[OK] ${CLI_CHECK}"

# ─────────────────────────────────────────────────────────────
# Step 6: Set timezone
# タイムゾーン設定
# ─────────────────────────────────────────────────────────────
export TZ="Asia/Tokyo"

# ─────────────────────────────────────────────────────────────
# Step 7: Print startup banner
# 起動バナーの表示
# ─────────────────────────────────────────────────────────────
PYTHON_PATH="$(command -v python3)"
PYTHON_FULL_VERSION="$(python3 --version 2>&1)"
ANIMAWORKS_SDK_VERSION="$(python3 -c "import claude_agent_sdk; print(claude_agent_sdk.__version__)")"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           AnimaWorks Production Server                      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Python Path    : ${PYTHON_PATH}"
echo "║  Python Version : ${PYTHON_FULL_VERSION}"
echo "║  SDK Version    : claude_agent_sdk ${ANIMAWORKS_SDK_VERSION}"
echo "║  Mode           : Max plan (no API billing / 従量課金なし)"
echo "║  Timestamp      : ${TIMESTAMP}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Host : ${HOST}   Port : ${PORT}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────
# Step 8: Start AnimaWorks
# AnimaWorks 起動
# ─────────────────────────────────────────────────────────────
echo "[INFO] AnimaWorks を起動しています / Starting AnimaWorks..."
echo ""

exec python3 main.py start --host "${HOST}" --port "${PORT}" "$@"
