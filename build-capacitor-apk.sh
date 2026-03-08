#!/bin/bash

# ============================================
# Immortal Web3 2FA - Capacitor APK Build
# ============================================
# Скрипт для сборки Android APK через Capacitor
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPACITOR_DIR="$SCRIPT_DIR/capacitor"

echo "============================================"
echo "  ⚡ Immortal Web3 2FA - APK Build"
echo "============================================"
echo ""

# Проверка Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js не найден!"
    echo "   Установите: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
    exit 1
fi

echo "✓ Node.js: $(node --version)"

# Проверка npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm не найден!"
    exit 1
fi

echo "✓ npm: $(npm --version)"

# Проверка Android SDK
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "❌ ANDROID_HOME не установлен!"
    exit 1
fi

echo "✓ Android SDK: ${ANDROID_HOME:-$ANDROID_SDK_ROOT}"

# Переход в директорию Capacitor
cd "$CAPACITOR_DIR"

# Копирование index.html в www
echo ""
echo "📁 Копирование index.html..."
mkdir -p www
cp ../index.html www/index.html

# Установка зависимостей
echo ""
echo "📦 Установка зависимостей..."
npm install

# Синхронизация с Android
echo ""
echo "🔄 Синхронизация с Android..."
npx cap sync android

# Сборка APK
echo ""
echo "🔨 Сборка debug APK..."
cd android
./gradlew assembleDebug

# Поиск собранного APK
APK_PATH=$(find ./app/build/outputs/apk/debug -name "*.apk" | head -n1)

if [ -n "$APK_PATH" ]; then
    echo ""
    echo "============================================"
    echo "  ✅ Сборка успешна!"
    echo "============================================"
    echo ""
    echo "  APK файл: $APK_PATH"
    echo ""
    echo "  Для установки:"
    echo "  adb install -r $APK_PATH"
    echo ""
    echo "  Или скопируйте файл на устройство"
    echo ""
else
    echo ""
    echo "❌ APK файл не найден!"
    exit 1
fi
