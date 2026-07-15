#!/usr/bin/env bash

## possibly needs:
# sudo apt update
#sudo apt install -y \
#  git curl build-essential libssl-dev zlib1g-dev \
#  libbz2-dev libreadline-dev libsqlite3-dev \
#  libffi-dev liblzma-dev xz-utils tk-dev

set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PYENV_ROOT="${PYENV_ROOT:-${HOME}/.pyenv}"
export PYENV_ROOT
export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${HOME}/.local/bin:${PATH}"

for required_command in curl git; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "${required_command} is required to install pyenv and uv." >&2
    exit 1
  fi
done

if ! command -v pyenv >/dev/null 2>&1; then
  echo "Installing pyenv..."
  curl -fsSL https://pyenv.run | bash
fi

eval "$(pyenv init -)"

if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="${HOME}/.local/bin" sh
fi

cd "${PROJECT_ROOT}"

if [[ ! -f .python-version ]]; then
  echo "No .python-version file found in ${PROJECT_ROOT}." >&2
  exit 1
fi

PYTHON_VERSION="$(tr -d '[:space:]' < .python-version)"

if ! pyenv versions --bare | awk -v requested="${PYTHON_VERSION}" '
  $0 == requested || index($0, requested ".") == 1 { found = 1 }
  END { exit !found }
'; then
  echo "Installing Python ${PYTHON_VERSION}..."
  pyenv install "${PYTHON_VERSION}"
fi

echo "Syncing project dependencies..."
uv sync
