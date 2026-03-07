#!/data/data/com.termux/files/usr/bin/bash
# ==========================================================
# OpenClaw Termux DeepSeek 中文一键安装脚本（官方 Onboard 方式）
# 封装作者：黑客驰 / hackerchi.top
# 说明：本脚本调用 openclaw-termux + OpenClaw 官方 onboard --non-interactive
#       目标：在 Termux 中一条命令完成安装，并尽量把 DeepSeek 自动配置好。
# ==========================================================

set -euo pipefail
umask 077

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

NPM_REGISTRY_CN="https://registry.npmmirror.com"
NPM_REGISTRY_OFFICIAL="https://registry.npmjs.org"
DOCS_DIR="${HOME}/OpenClaw-中文资料"
HELPER_DIR="${HOME}/openclaw-helper"
TMP_DIR="${HOME}/.openclaw_cn_installer_tmp"
ENV_FILE_HOST="${TMP_DIR}/openclaw.env"
DEEPSEEK_API_KEY=""
MODEL_ID="deepseek-chat"
GATEWAY_TOKEN=""

info() { echo -e "${CYAN}[信息]${NC} $*"; }
success() { echo -e "${GREEN}[完成]${NC} $*"; }
warn() { echo -e "${YELLOW}[提醒]${NC} $*"; }
error() { echo -e "${RED}[错误]${NC} $*"; }
die() { error "$*"; exit 1; }

cleanup() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

print_banner() {
  clear || true
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║      OpenClaw Termux DeepSeek 中文一键安装脚本           ║${NC}"
  echo -e "${BLUE}║    官方 onboard --non-interactive 自动配置方案          ║${NC}"
  echo -e "${BLUE}║            封装：黑客驰 · hackerchi.top                  ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo
}

check_termux() {
  if [ ! -d "/data/data/com.termux" ] && [ -z "${TERMUX_VERSION:-}" ]; then
    warn "当前看起来不像 Termux 环境。脚本仍会继续，但成功率无法保证。"
  fi
}

check_android_hint() {
  if command -v getprop >/dev/null 2>&1; then
    local sdk
    sdk="$(getprop ro.build.version.sdk 2>/dev/null || true)"
    if [ -n "$sdk" ] && [ "$sdk" -lt 29 ]; then
      warn "检测到 Android SDK=${sdk}。上游 openclaw-termux 更推荐 Android 10 / API 29 及以上。"
    fi
  fi
}

random_hex_64() {
  tr -dc 'A-Fa-f0-9' < /dev/urandom | head -c 64
}

ask_inputs() {
  echo "本脚本默认配置 DeepSeek。"
  echo "你只需要决定两件事："
  echo "  1) 是否现在输入 DeepSeek API Key"
  echo "  2) 默认模型是 deepseek-chat 还是 deepseek-reasoner"
  echo
  read -r -s -p "请输入 DeepSeek API Key（可直接回车跳过，稍后再配）：" DEEPSEEK_API_KEY
  echo
  echo
  echo "请选择默认模型："
  echo "  1) deepseek-chat      （推荐，通用更稳）"
  echo "  2) deepseek-reasoner  （推理更强）"
  echo
  local choice
  read -r -p "请输入编号 [默认 1]：" choice
  choice="${choice:-1}"
  case "$choice" in
    1) MODEL_ID="deepseek-chat" ;;
    2) MODEL_ID="deepseek-reasoner" ;;
    *) warn "无效选择，已改用默认模型 deepseek-chat。"; MODEL_ID="deepseek-chat" ;;
  esac
  GATEWAY_TOKEN="$(random_hex_64)"
}

install_termux_packages() {
  info "更新 Termux 并安装依赖……"
  pkg update -y
  pkg upgrade -y
  pkg install -y nodejs-lts git proot-distro curl
  success "Termux 依赖安装完成。"
}

install_openclaw_termux() {
  info "安装 openclaw-termux……"
  npm config set registry "$NPM_REGISTRY_CN" >/dev/null 2>&1 || true
  if npm install -g openclaw-termux; then
    success "openclaw-termux 安装成功（国内 npm 镜像）。"
  else
    warn "国内 npm 镜像安装失败，切换官方 npm 源重试。"
    npm config set registry "$NPM_REGISTRY_OFFICIAL"
    npm cache clean --force >/dev/null 2>&1 || true
    npm install -g openclaw-termux
    success "openclaw-termux 安装成功（官方 npm 源）。"
  fi
  command -v openclawx >/dev/null 2>&1 || die "未找到 openclawx，安装似乎没有成功。"
}

run_openclawx_setup() {
  info "执行 openclawx setup。这个阶段会安装 Ubuntu、Node.js 和 OpenClaw。"
  openclawx setup
  success "openclawx setup 已完成。"
}

ubuntu_run() {
  local cmd="$1"
  proot-distro login ubuntu --shared-tmp -- /bin/bash -lc "$cmd"
}

prepare_env_file() {
  mkdir -p "$TMP_DIR" "$DOCS_DIR" "$HELPER_DIR"
  cat > "$ENV_FILE_HOST" <<EOF_ENV
# OpenClaw 本地环境变量（由黑客驰 / hackerchi.top 脚本生成）
CUSTOM_API_KEY=${DEEPSEEK_API_KEY}
GATEWAY_TOKEN=${GATEWAY_TOKEN}
EOF_ENV
  chmod 600 "$ENV_FILE_HOST"
}

copy_env_into_ubuntu() {
  info "写入 Ubuntu 内部的 ~/.openclaw/.env ……"
  ubuntu_run "mkdir -p ~/.openclaw ~/.openclaw/workspace"
  ubuntu_run "cp '$ENV_FILE_HOST' ~/.openclaw/.env && chmod 600 ~/.openclaw/.env"
  success "环境变量文件已写入 Ubuntu：~/.openclaw/.env"
}

configure_deepseek_now() {
  if [ -z "$DEEPSEEK_API_KEY" ]; then
    warn "你刚才跳过了 DeepSeek API Key。脚本将只完成环境安装，不会现在配置 DeepSeek。"
    return 0
  fi

  info "调用 OpenClaw 官方 onboard --non-interactive 自动写入 DeepSeek 配置……"
  ubuntu_run "set -euo pipefail
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z \"\$OPENCLAW_BIN\" ] && [ -x \"\$HOME/.openclaw/bin/openclaw\" ]; then
  OPENCLAW_BIN=\"\$HOME/.openclaw/bin/openclaw\"
fi
[ -n \"\$OPENCLAW_BIN\" ] || { echo '未找到 openclaw 主程序。'; exit 1; }
mkdir -p ~/.openclaw ~/.openclaw/workspace
set -a
. ~/.openclaw/.env
set +a
\"\$OPENCLAW_BIN\" onboard --non-interactive \\
  --mode local \\
  --auth-choice custom-api-key \\
  --custom-provider-id deepseek \\
  --custom-base-url https://api.deepseek.com/v1 \\
  --custom-model-id ${MODEL_ID} \\
  --custom-compatibility openai \\
  --secret-input-mode ref \\
  --gateway-bind loopback \\
  --gateway-port 18789 \\
  --gateway-auth token \\
  --gateway-token-ref-env GATEWAY_TOKEN \\
  --skip-channels \\
  --skip-skills
\"\$OPENCLAW_BIN\" config validate"
  success "DeepSeek 已按官方 non-interactive onboarding 方式写入配置。"
}

create_reconfigure_helper() {
  cat > "${HELPER_DIR}/配置DeepSeek.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
read -r -s -p "请输入 DeepSeek API Key：" DS_KEY
echo
read -r -p "请输入默认模型 [默认 deepseek-chat，可改为 deepseek-reasoner]：" DS_MODEL
DS_MODEL="${DS_MODEL:-deepseek-chat}"
GATEWAY_TOKEN="$(tr -dc 'A-Fa-f0-9' < /dev/urandom | head -c 64)"
mkdir -p "$HOME/.openclaw_cn_installer_tmp"
cat > "$HOME/.openclaw_cn_installer_tmp/openclaw.env" <<EOF_ENV
CUSTOM_API_KEY=${DS_KEY}
GATEWAY_TOKEN=${GATEWAY_TOKEN}
EOF_ENV
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc "mkdir -p ~/.openclaw ~/.openclaw/workspace"
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc "cp '$HOME/.openclaw_cn_installer_tmp/openclaw.env' ~/.openclaw/.env && chmod 600 ~/.openclaw/.env"
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc "set -euo pipefail
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z \"\$OPENCLAW_BIN\" ] && [ -x \"\$HOME/.openclaw/bin/openclaw\" ]; then
  OPENCLAW_BIN=\"\$HOME/.openclaw/bin/openclaw\"
fi
[ -n \"\$OPENCLAW_BIN\" ] || { echo '未找到 openclaw 主程序。'; exit 1; }
set -a
. ~/.openclaw/.env
set +a
\"\$OPENCLAW_BIN\" onboard --non-interactive \\
  --mode local \\
  --auth-choice custom-api-key \\
  --custom-provider-id deepseek \\
  --custom-base-url https://api.deepseek.com/v1 \\
  --custom-model-id ${DS_MODEL} \\
  --custom-compatibility openai \\
  --secret-input-mode ref \\
  --gateway-bind loopback \\
  --gateway-port 18789 \\
  --gateway-auth token \\
  --gateway-token-ref-env GATEWAY_TOKEN \\
  --skip-channels \\
  --skip-skills
\"\$OPENCLAW_BIN\" config validate"
rm -f "$HOME/.openclaw_cn_installer_tmp/openclaw.env"
echo
echo "DeepSeek 配置完成。"
echo "现在可以运行：openclawx start"
EOF_HELPER
  chmod +x "${HELPER_DIR}/配置DeepSeek.sh"
}

create_helper_files() {
  cat > "${HELPER_DIR}/启动OpenClaw.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
openclawx start
EOF_HELPER

  cat > "${HELPER_DIR}/进入Ubuntu.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
openclawx shell
EOF_HELPER

  cat > "${HELPER_DIR}/前台启动查看日志.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
openclawx start
EOF_HELPER

  chmod +x "${HELPER_DIR}/启动OpenClaw.sh" "${HELPER_DIR}/进入Ubuntu.sh" "${HELPER_DIR}/前台启动查看日志.sh"
  create_reconfigure_helper

  cat > "${DOCS_DIR}/01-安装完成后先看我.txt" <<EOF_README
OpenClaw Termux DeepSeek 中文说明
封装：黑客驰 / hackerchi.top

一、你现在最常用的命令
1. 启动 OpenClaw：bash ~/openclaw-helper/启动OpenClaw.sh
2. 重新配置 DeepSeek：bash ~/openclaw-helper/配置DeepSeek.sh
3. 进入 Ubuntu：bash ~/openclaw-helper/进入Ubuntu.sh

二、本机访问地址
http://127.0.0.1:18789/

三、当前默认模型
${MODEL_ID}

四、说明
1. 如果你安装时跳过了 DeepSeek API Key，请运行：bash ~/openclaw-helper/配置DeepSeek.sh
2. 如果手机后台容易被杀，请把 Termux 的电池优化设为“不受限制”
3. 本中文脚本版权：黑客驰 / hackerchi.top
EOF_README
}

maybe_start_gateway() {
  echo
  read -r -p "是否现在直接启动 OpenClaw？[y/N]：" choice
  choice="${choice:-N}"
  case "$choice" in
    y|Y)
      openclawx start
      ;;
    *)
      success "已跳过自动启动。稍后可运行：openclawx start"
      ;;
  esac
}

final_summary() {
  echo
  echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}安装流程已完成${NC}"
  echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
  echo "默认模型：${MODEL_ID}"
  echo "本机地址：http://127.0.0.1:18789/"
  if [ -n "$DEEPSEEK_API_KEY" ]; then
    echo "DeepSeek：已自动配置完成"
  else
    echo "DeepSeek：你刚才跳过了 API Key，尚未自动配置"
    echo "稍后运行：bash ~/openclaw-helper/配置DeepSeek.sh"
  fi
  echo "帮助目录：${HELPER_DIR}"
  echo "说明目录：${DOCS_DIR}"
  echo "封装版权：黑客驰 / hackerchi.top"
}

main() {
  print_banner
  check_termux
  check_android_hint
  ask_inputs
  install_termux_packages
  install_openclaw_termux
  run_openclawx_setup
  prepare_env_file
  copy_env_into_ubuntu
  configure_deepseek_now
  create_helper_files
  final_summary
  maybe_start_gateway
}

main "$@"
