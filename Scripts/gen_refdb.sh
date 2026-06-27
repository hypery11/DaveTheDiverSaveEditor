#!/usr/bin/env bash
#
# gen_refdb.sh — regenerate the bundled reference database from the upstream
# DaveSaveEd `embedded_sql.h` zlib blob.
#
#   1. inflate embedded_sql_compressed[]  ->  reference.sql            (checked in)
#   2. sqlite3 reference.sqlite < reference.sql                        (shipped resource)
#   3. verify row counts (563 Items / 305 Ingredients)
#
# Usage:
#   Scripts/gen_refdb.sh [path/to/embedded_sql.h]
#   UPSTREAM_HEADER=/path/to/embedded_sql.h Scripts/gen_refdb.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HEADER="${1:-${UPSTREAM_HEADER:-${ROOT}/../DaveSaveEd/embedded_sql.h}}"
SQL_OUT="${ROOT}/reference.sql"
DB_OUT="${ROOT}/Sources/DaveSaveCore/Resources/reference.sqlite"

if [[ ! -f "${HEADER}" ]]; then
    echo "error: upstream header not found: ${HEADER}" >&2
    echo "       pass the path as arg 1 or set UPSTREAM_HEADER=" >&2
    exit 1
fi

echo "inflating ${HEADER} -> ${SQL_OUT}"
python3 "${SCRIPT_DIR}/inflate_embedded_sql.py" "${HEADER}" > "${SQL_OUT}"

echo "building ${DB_OUT}"
mkdir -p "$(dirname "${DB_OUT}")"
rm -f "${DB_OUT}"                       # sqlite3 errors if it imports into an existing schema
sqlite3 "${DB_OUT}" < "${SQL_OUT}"

items=$(sqlite3 "${DB_OUT}" 'SELECT COUNT(*) FROM Items;')
ingredients=$(sqlite3 "${DB_OUT}" 'SELECT COUNT(*) FROM Ingredients;')
echo "Items=${items} Ingredients=${ingredients}"

if [[ "${items}" != "563" || "${ingredients}" != "305" ]]; then
    echo "error: unexpected row counts (want 563 Items / 305 Ingredients)" >&2
    exit 1
fi
echo "ok: reference database regenerated."
