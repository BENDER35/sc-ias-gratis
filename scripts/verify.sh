#!/usr/bin/env bash
# verify.sh — Comprueba el proyecto y la sincronización entre plataformas.
# Uso: scripts/verify.sh [--local]

set -uo pipefail

GH_REPO="BENDER35/sc-ias-gratis"
GL_PROJECT="89453204"
GL_REPO="BENDER_5000/sc-ias-gratis"
BRANCH="main"
VERSION="v1.0.0"
SOLO_LOCAL=0
OK=0
FAIL=0

[[ "${1:-}" == "--local" ]] && SOLO_LOCAL=1

pass() { printf '  %sPASS%s %s\n' $'\033[32m' $'\033[0m' "$1"; OK=$((OK + 1)); }
fail() { printf '  %sFAIL%s %s\n' $'\033[31m' $'\033[0m' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  %sSKIP%s %s\n' $'\033[33m' $'\033[0m' "$1"; }
check() { if "$@"; then pass "$*"; else fail "$*"; fi; }

archivo_existe() { [[ -f "$1" ]]; }
scripts_validos() {
  local f
  for f in install_ias.sh scripts/*.sh; do
    bash -n "$f" || return 1
  done
}
yaml_valido() {
  python3 - <<'PY'
import sys
try:
    import yaml
except ImportError:
    sys.exit(0)
for f in ('.github/workflows/mirror.yml', '.gitlab-ci.yml'):
    with open(f) as fh:
        yaml.safe_load(fh)
PY
}
both_remotes() {
  git remote get-url origin >/dev/null 2>&1 &&
  git remote get-url gitlab >/dev/null 2>&1
}

printf '%sVerificación local%s\n' $'\033[1m' $'\033[0m'
check archivo_existe install_ias.sh
check archivo_existe scripts/mirror.sh
check archivo_existe scripts/verify.sh
check archivo_existe scripts/release.sh
check archivo_existe .github/workflows/mirror.yml
check archivo_existe .gitlab-ci.yml
check scripts_validos
check yaml_valido
if both_remotes; then pass "remotos git 'origin' y 'gitlab' configurados"; else fail "faltan remotos git"; fi

if ((SOLO_LOCAL)); then
  printf '\nResumen: %d OK, %d fallos (solo local)\n' "$OK" "$FAIL"
  ((FAIL == 0))
  exit $?
fi

printf '\n%sVerificación remota%s\n' $'\033[1m' $'\033[0m'
if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  fail "gh autenticado"
else
  pass "gh autenticado"
fi
if ! command -v glab >/dev/null 2>&1 || ! glab auth status >/dev/null 2>&1; then
  fail "glab autenticado"
else
  pass "glab autenticado"
fi

SHA_GH="$(gh api "repos/${GH_REPO}/commits/${BRANCH}" --jq .sha 2>/dev/null || true)"
SHA_GL="$(glab api "/projects/${GL_PROJECT}/repository/commits/${BRANCH}" 2>/dev/null |
  python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))' 2>/dev/null || true)"

if [[ -n "$SHA_GH" ]]; then pass "GitHub ${BRANCH} legible (${SHA_GH:0:12})"; else fail "GitHub ${BRANCH} legible"; fi
if [[ -n "$SHA_GL" ]]; then pass "GitLab ${BRANCH} legible (${SHA_GL:0:12})"; else fail "GitLab ${BRANCH} legible"; fi
if [[ -n "$SHA_GH" && "$SHA_GH" == "$SHA_GL" ]]; then
  pass "SHA idéntico en GitHub y GitLab"
else
  fail "SHA idéntico en GitHub y GitLab"
fi

if gh secret list --repo "$GH_REPO" 2>/dev/null | grep -qi '^GITLAB_TOKEN'; then
  pass "secreto GITLAB_TOKEN presente en GitHub"
else
  fail "secreto GITLAB_TOKEN presente en GitHub"
fi
if glab api "/projects/${GL_PROJECT}/variables" 2>/dev/null |
   python3 -c 'import sys,json; print(any(v.get("key")=="GH_TOKEN" for v in json.load(sys.stdin)))' 2>/dev/null | grep -q True; then
  pass "variable GH_TOKEN presente en GitLab"
else
  fail "variable GH_TOKEN presente en GitLab"
fi

if gh api "repos/${GH_REPO}/releases/tags/${VERSION}" --jq '.assets[].name' 2>/dev/null |
   grep -q "sc-ias-gratis-${VERSION}.zip"; then
  pass "release ${VERSION} con ZIP en GitHub"
else
  fail "release ${VERSION} con ZIP en GitHub"
fi
if glab api "/projects/${GL_PROJECT}/releases/${VERSION}" 2>/dev/null |
   python3 -c 'import sys,json; print(any("zip" in (a.get("name","")+a.get("url","")).lower() for a in json.load(sys.stdin).get("assets",{"links":[]}).get("links",[])))' 2>/dev/null | grep -q True; then
  pass "release ${VERSION} con ZIP en GitLab"
else
  skip "release ${VERSION} con ZIP en GitLab (no verificable o sin asset)"
fi

printf '\nResumen: %d OK, %d fallos\n' "$OK" "$FAIL"
((FAIL == 0))
exit $?
