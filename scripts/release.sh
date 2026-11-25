#!/usr/bin/env bash
# release.sh — Crea un ZIP con los archivos versionados y publica la release.
# Uso: scripts/release.sh [v1.0.0]

set -euo pipefail

VERSION="${1:-v1.0.0}"
GH_REPO="BENDER35/sc-ias-gratis"
GL_PROJECT="89453204"
GL_REPO="BENDER_5000/sc-ias-gratis"
ZIP="sc-ias-gratis-${VERSION}.zip"

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: necesitas 'gh' autenticado para la release en GitHub" >&2
  exit 1
fi
if ! command -v glab >/dev/null 2>&1 || ! glab auth status >/dev/null 2>&1; then
  echo "ERROR: necesitas 'glab' autenticado para la release en GitLab" >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: hay cambios sin commitear; limpia el árbol antes de publicar" >&2
  exit 1
fi

mapfile -t ARCHIVOS < <(git ls-files)
if ((${#ARCHIVOS[@]} == 0)); then
  echo "ERROR: no hay archivos versionados" >&2
  exit 1
fi

rm -f "$ZIP"
zip -q "$ZIP" "${ARCHIVOS[@]}"
echo "Creado $ZIP ($(du -h "$ZIP" | cut -f1), ${#ARCHIVOS[@]} archivos)"

NOTAS="Herramientas CLI con plan gratuito: opencode, Claude Code, Gemini CLI,
OpenAI Codex CLI, GitHub Copilot CLI, Qwen Code, Ollama y Aider.
Incluye menú interactivo, espejo automático GitHub ⇄ GitLab y verificación.
ZIP generado a partir de los archivos versionados en ${VERSION}."

if gh release view "$VERSION" --repo "$GH_REPO" >/dev/null 2>&1; then
  echo "La release ${VERSION} ya existe en GitHub; actualizando asset..."
  gh release upload "$VERSION" "$ZIP" --repo "$GH_REPO" --clobber
else
  gh release create "$VERSION" "$ZIP" --repo "$GH_REPO" \
    --title "sc-ias-gratis ${VERSION}" --notes "$NOTAS" --target main
fi

if glab release view "$VERSION" --repo "$GL_REPO" >/dev/null 2>&1; then
  echo "La release ${VERSION} ya existe en GitLab; actualizando asset..."
  glab release upload "$VERSION" "$ZIP#ZIP del proyecto" --repo "$GL_REPO" || true
else
  glab release create "$VERSION" "${ZIP}#ZIP del proyecto" --repo "$GL_REPO" \
    --name "sc-ias-gratis ${VERSION}" --notes "$NOTAS" --ref main
fi

echo ""
echo "Release publicada:"
echo "  GitHub: https://github.com/${GH_REPO}/releases/tag/${VERSION}"
echo "  GitLab: https://gitlab.com/BENDER_5000/sc-ias-gratis/-/releases/${VERSION}"
