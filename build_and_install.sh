#!/bin/bash

# 俄罗斯方块游戏编译安装脚本
# 支持 Android、iOS、Web、macOS、Linux、Windows 平台

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "俄罗斯方块游戏编译安装脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -a, --android    编译并安装 Android APK"
    echo "  -i, --ios        编译并安装 iOS 应用"
    echo "  -w, --web        编译 Web 应用"
    echo "  -m, --macos      编译并安装 macOS 应用"
    echo "  -l, --linux      编译并安装 Linux 应用"
    echo "  -W, --windows    编译并安装 Windows 应用"
    echo "  -c, --clean      清理项目"
    echo "  -d, --deps       获取依赖"
    echo "  -r, --run        运行应用（默认平台）"
    echo "  -h, --help       显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -a            编译并安装 Android APK"
    echo "  $0 -i            编译并安装 iOS 应用"
    echo "  $0 -c -d -a      清理、获取依赖、编译 Android"
    echo "  $0 -r            运行应用（默认平台）"
}

# 检查 Flutter 是否安装
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter 未安装或不在 PATH 中"
        print_info "请安装 Flutter: https://flutter.dev/docs/get-started/install"
        exit 1
    fi
    
    print_info "Flutter 版本: $(flutter --version | head -n 1)"
}

# 清理项目
clean_project() {
    print_info "清理项目..."
    flutter clean
    print_success "项目清理完成"
}

# 获取依赖
get_dependencies() {
    print_info "获取依赖..."
    flutter pub get
    print_success "依赖获取完成"
}

# 编译 Android APK
build_android() {
    print_info "编译 Android APK..."
    flutter build apk --release
    
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_PATH" ]; then
        print_success "Android APK 编译完成: $APK_PATH"
        print_info "APK 大小: $(du -h "$APK_PATH" | cut -f1)"
        
        # 检查是否有连接的 Android 设备并自动安装
        if flutter devices | grep -q "android"; then
            flutter install
            print_success "应用已安装到 Android 设备"
        else
            print_warning "未检测到连接的 Android 设备，跳过安装"
        fi
    else
        print_error "Android APK 编译失败"
        exit 1
    fi
}

# 编译 iOS 应用
build_ios() {
    print_info "编译 iOS 应用..."
    
    # 检查是否在 macOS 上
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "iOS 编译只能在 macOS 上进行"
        exit 1
    fi
    
    # 检查 Xcode 是否安装
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode 未安装"
        print_info "请从 App Store 安装 Xcode"
        exit 1
    fi
    
    flutter build ios --release
    
    print_success "iOS 应用编译完成"
    print_info "请使用 Xcode 打开 ios/Runner.xcworkspace 来安装到设备"
}

# 编译 Web 应用
build_web() {
    print_info "编译 Web 应用..."
    flutter build web --release
    
    WEB_PATH="build/web"
    if [ -d "$WEB_PATH" ]; then
        print_success "Web 应用编译完成: $WEB_PATH"
        print_info "可以通过 Web 服务器提供服务"
    else
        print_error "Web 应用编译失败"
        exit 1
    fi
}

# 编译 macOS 应用
build_macos() {
    print_info "编译 macOS 应用..."
    
    # 检查是否在 macOS 上
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "macOS 编译只能在 macOS 上进行"
        exit 1
    fi
    
    flutter build macos --release
    
        APP_PATH="build/macos/Build/Products/Release/Tetris.app"
        if [ -d "$APP_PATH" ]; then
            print_success "macOS 应用编译完成: $APP_PATH"
            print_info "应用大小: $(du -sh "$APP_PATH" | cut -f1)"
            open "$APP_PATH"
        else
        print_error "macOS 应用编译失败"
        exit 1
    fi
}

# 编译 Linux 应用
build_linux() {
    print_info "编译 Linux 应用..."
    
    # 检查是否在 Linux 上
    if [[ "$(uname)" != "Linux" ]]; then
        print_error "Linux 编译只能在 Linux 上进行"
        exit 1
    fi
    
    flutter build linux --release
    
        APP_PATH="build/linux/x64/release/bundle"
        if [ -d "$APP_PATH" ]; then
            print_success "Linux 应用编译完成: $APP_PATH"
            print_info "应用大小: $(du -sh "$APP_PATH" | cut -f1)"
            cd "$APP_PATH"
            ./tetris
        else
        print_error "Linux 应用编译失败"
        exit 1
    fi
}

# 编译 Windows 应用
build_windows() {
    print_info "编译 Windows 应用..."
    
    # 检查是否在 Windows 上
    if [[ "$(uname)" == *"MINGW"* ]] || [[ "$(uname)" == *"MSYS"* ]]; then
        print_error "Windows 编译请使用 PowerShell 或 CMD"
        exit 1
    fi
    
    flutter build windows --release
    
    APP_PATH="build/windows/x64/runner/Release"
    if [ -d "$APP_PATH" ]; then
        print_success "Windows 应用编译完成: $APP_PATH"
        print_info "应用大小: $(du -sh "$APP_PATH" | cut -f1)"
    else
        print_error "Windows 应用编译失败"
        exit 1
    fi
}

# 运行应用
run_app() {
    print_info "运行应用..."
    flutter run
}

# 主函数
main() {
    # 检查 Flutter
    check_flutter
    
    # 解析命令行参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    CLEAN=false
    DEPS=false
    PLATFORM=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--android)
                PLATFORM="android"
                shift
                ;;
            -i|--ios)
                PLATFORM="ios"
                shift
                ;;
            -w|--web)
                PLATFORM="web"
                shift
                ;;
            -m|--macos)
                PLATFORM="macos"
                shift
                ;;
            -l|--linux)
                PLATFORM="linux"
                shift
                ;;
            -W|--windows)
                PLATFORM="windows"
                shift
                ;;
            -c|--clean)
                CLEAN=true
                shift
                ;;
            -d|--deps)
                DEPS=true
                shift
                ;;
            -r|--run)
                PLATFORM="run"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 清理项目
    if [ "$CLEAN" = true ]; then
        clean_project
    fi
    
    # 获取依赖
    if [ "$DEPS" = true ]; then
        get_dependencies
    fi
    
    # 编译指定平台
    case $PLATFORM in
        android)
            build_android
            ;;
        ios)
            build_ios
            ;;
        web)
            build_web
            ;;
        macos)
            build_macos
            ;;
        linux)
            build_linux
            ;;
        windows)
            build_windows
            ;;
        run)
            run_app
            ;;
        "")
            print_error "请指定平台"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"