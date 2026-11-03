#!/usr/bin/env bash
# Gera builds Linux/Windows e ZIPs para distribuio.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/Downloads/Godot_v4.6.2-stable_linux.x86_64}"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
VERSION="${VERSION:-1.0}"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot no encontrado em: $GODOT"
	echo "Defina a varivel GODOT com o caminho do executvel."
	exit 1
fi

mkdir -p "$BUILD_DIR/linux" "$BUILD_DIR/windows" "$DIST_DIR"

echo ">> Exportando Linux..."
"$GODOT" --headless --path "$ROOT" --export-release "Linux" "$BUILD_DIR/linux/HYPOXIA.x86_64"

echo ">> Exportando Windows..."
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$BUILD_DIR/windows/HYPOXIA.exe"

cp "$ROOT/assets/fonts/OFL.txt" "$BUILD_DIR/linux/OFL-PressStart2P.txt"
cp "$ROOT/assets/fonts/OFL.txt" "$BUILD_DIR/windows/OFL-PressStart2P.txt"

cp "$ROOT/build/linux/LEIA-ME.txt" "$BUILD_DIR/linux/LEIA-ME.txt" 2>/dev/null || cat > "$BUILD_DIR/linux/LEIA-ME.txt" <<'EOF'
HYPOXIA — Ctrl+Alt+Math (Linux)
Execute: chmod +x HYPOXIA.x86_64 && ./HYPOXIA.x86_64
EOF

cp "$ROOT/build/windows/LEIA-ME.txt" "$BUILD_DIR/windows/LEIA-ME.txt" 2>/dev/null || cat > "$BUILD_DIR/windows/LEIA-ME.txt" <<'EOF'
HYPOXIA — Ctrl+Alt+Math (Windows)
Execute: HYPOXIA.exe
EOF

LINUX_ZIP="$DIST_DIR/HYPOXIA-linux-x86_64-v${VERSION}.zip"
WIN_ZIP="$DIST_DIR/HYPOXIA-windows-x86_64-v${VERSION}.zip"

echo ">> Criando ZIP Linux..."
rm -f "$LINUX_ZIP"
(
	cd "$BUILD_DIR/linux"
	zip -r "$LINUX_ZIP" . -x "*.zip"
)

echo ">> Criando ZIP Windows..."
rm -f "$WIN_ZIP"
(
	cd "$BUILD_DIR/windows"
	zip -r "$WIN_ZIP" . -x "*.zip"
)

echo ""
echo "Pronto!"
echo "  Linux:   $LINUX_ZIP"
echo "  Windows: $WIN_ZIP"
ls -lh "$DIST_DIR"/*.zip
