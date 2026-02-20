#!/usr/bin/env bash
set -euo pipefail

if ! command -v psql >/dev/null 2>&1; then
  exit 0
fi

if ! command -v sudo >/dev/null 2>&1 || ! sudo -n -u postgres psql -tAc "SELECT 1" >/dev/null 2>&1; then
  echo "Skipping PostgreSQL setup: sudo access to postgres user is not available."
  exit 0
fi

if command -v service >/dev/null 2>&1; then
  sudo -n service postgresql start >/dev/null 2>&1 || true
fi

if ! pg_isready -q; then
  exit 0
fi

if ! sudo -n -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='vscode'" | grep -q 1; then
  sudo -n -u postgres createuser --superuser vscode
fi

for db in re_phrase_development re_phrase_test; do
  if ! sudo -n -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1; then
    sudo -n -u postgres createdb -O vscode "${db}"
  fi
done

hba_file="$(sudo -n -u postgres psql -tAc "SHOW hba_file" | xargs)"
if [ -n "${hba_file}" ] && [ -f "${hba_file}" ]; then
  marker="# codex-passwordless-postgres"
  if ! sudo -n grep -q "${marker}" "${hba_file}"; then
    tmp_hba="$(mktemp)"
    cat >"${tmp_hba}" <<'EOF'
# codex-passwordless-postgres
local all all trust
host all all 127.0.0.1/32 trust
host all all ::1/128 trust

EOF
    sudo -n cat "${hba_file}" >> "${tmp_hba}"
    sudo -n cp "${tmp_hba}" "${hba_file}"
    rm -f "${tmp_hba}"
    sudo -n service postgresql restart >/dev/null 2>&1 || true
  fi
fi
