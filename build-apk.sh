#!/bin/bash

# Скрипт для сборки APK Web3 2FA Authenticator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$SCRIPT_DIR/android"

echo "============================================"
echo "  Web3 2FA Authenticator - Сборка APK"
echo "============================================"
echo ""

# Проверка наличия Java
if ! command -v java &> /dev/null; then
    echo "❌ Java не найдена! Установите JDK 17+"
    exit 1
fi

echo "✓ Java найдена: $(java -version 2>&1 | head -n1)"

# Проверка наличия Android SDK
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "❌ ANDROID_HOME или ANDROID_SDK_ROOT не установлен!"
    echo "   Установите Android SDK или задайте переменную окружения"
    exit 1
fi

echo "✓ Android SDK: ${ANDROID_HOME:-$ANDROID_SDK_ROOT}"

# Переход в директорию Android проекта
cd "$ANDROID_DIR"

# Проверка наличия gradlew
if [ ! -f "./gradlew" ]; then
    echo "⚡ Gradle wrapper не найден, создаем..."
    
    # Создаем gradlew скрипт
    cat > gradlew << 'GRADLEW_SCRIPT'
#!/bin/bash
DEFAULT_JVM_OPTS='"-Dorg.gradle.appname=gradlew"'
APP_NAME="Gradle"
APP_BASE_NAME=$(basename "$0")
DIRNAME=$(dirname "$0")
APP_HOME=$(cd "$DIRNAME" && pwd)
CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar
GRADLE_WRAPPER_JAR=$APP_HOME/gradle/wrapper/gradle-wrapper.jar

if [ ! -f "$GRADLE_WRAPPER_JAR" ]; then
    echo "Gradle wrapper jar not found. Please ensure the gradle wrapper is set up correctly."
    exit 1
fi

exec java $DEFAULT_JVM_OPTS -classpath "$CLASSPATH" org.gradle.wrapper.GradleWrapperMain "$@"
GRADLEW_SCRIPT
    
    chmod +x gradlew
fi

# Скачиваем gradle-wrapper.jar если его нет
if [ ! -f "./gradle/wrapper/gradle-wrapper.jar" ]; then
    echo "⚡ Скачивание gradle-wrapper.jar..."
    curl -L -o ./gradle/wrapper/gradle-wrapper.jar \
        https://raw.githubusercontent.com/gradle/gradle/master/gradle/wrapper/gradle-wrapper.jar
fi

echo ""
echo "🔨 Сборка debug APK..."
echo ""

# Сборка debug APK
./gradlew assembleDebug --stacktrace

# Находим собранный APK
APK_PATH=$(find ./app/build/outputs/apk/debug -name "*.apk" | head -n1)

if [ -n "$APK_PATH" ]; then
    echo ""
    echo "============================================"
    echo "  ✓ Сборка успешна!"
    echo "============================================"
    echo ""
    echo "  APK файл: $APK_PATH"
    echo ""
    echo "  Для установки на устройство:"
    echo "  adb install -r $APK_PATH"
    echo ""
else
    echo "❌ APK файл не найден!"
    exit 1
fi
