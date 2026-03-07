#!/data/data/com.termux/files/usr/bin/bash
# ==========================================================
# OpenClaw Termux DeepSeek 中文一键安装脚本（修正版）
# 主推脚本：openclaw_termux_cn_installer.sh
# 封装作者：黑客驰 / hackerchi.top
# 说明：
#   1) 使用 openclaw-termux + OpenClaw 官方 onboard --non-interactive
#   2) 无论是否填写 DeepSeek API Key，都会先写入“可启动”的本地 Gateway 基础配置
#   3) 若提供 DeepSeek API Key，则自动接入 DeepSeek 自定义 provider 并切为默认模型
#   4) 默认把本机 loopback 认证设为 none，优先保证手机本机先跑通
#   5) 提供一键开启 token 认证的辅助脚本，适合后续电脑/平板接入
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
LOCAL_AUTH_MODE="none"
GATEWAY_TOKEN="hc-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"

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
  echo -e "${BLUE}║        官方 onboard --non-interactive 自动方案          ║${NC}"
  echo -e "${BLUE}║      先写可启动配置，再按需接入 DeepSeek / 免 token      ║${NC}"
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

ask_inputs() {
  echo "本脚本主打：安装完后直接在手机本机打开 http://127.0.0.1:18789/ 使用。"
  echo "为减少首次网页认证卡住，脚本默认把本机 loopback 认证改为 none。"
  echo "如果你后面要电脑/平板远程接入，可再运行辅助脚本一键开启 token 认证。"
  echo
  read -r -s -p "请输入 DeepSeek API Key（可直接回车跳过，稍后再配）：" DEEPSEEK_API_KEY || true
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
}

install_termux_packages() {
  info "更新 Termux 并安装依赖……"
  pkg update -y
  pkg upgrade -y
  pkg install -y nodejs-lts git proot-distro curl coreutils
  success "Termux 依赖安装完成。"
}

configure_npm_registry() {
  info "设置 npm 镜像……"
  npm config set registry "$NPM_REGISTRY_CN" >/dev/null 2>&1 || true
  npm config get registry >/dev/null 2>&1 || true
  success "npm 已优先使用 npmmirror。"
}

install_openclaw_termux() {
  info "安装 openclaw-termux……"
  if npm install -g openclaw-termux; then
    success "openclaw-termux 安装成功（npmmirror）。"
  else
    warn "npmmirror 安装失败，切换官方 npm 源重试。"
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
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
CUSTOM_API_KEY=${DEEPSEEK_API_KEY}
EOF_ENV
  chmod 600 "$ENV_FILE_HOST"
}

copy_env_into_ubuntu() {
  info "写入 Ubuntu 内部的 ~/.openclaw/.env ……"
  ubuntu_run "mkdir -p ~/.openclaw ~/.openclaw/workspace"
  ubuntu_run "cp '$ENV_FILE_HOST' ~/.openclaw/.env && chmod 600 ~/.openclaw/.env"
  success "环境变量文件已写入 Ubuntu：~/.openclaw/.env"
}

configure_ubuntu_npm() {
  info "在 Ubuntu 内部也优先设置 npmmirror……"
  ubuntu_run "if command -v npm >/dev/null 2>&1; then npm config set registry '$NPM_REGISTRY_CN' >/dev/null 2>&1 || true; fi"
  success "Ubuntu 内部 npm 镜像已设置。"
}

bootstrap_local_gateway_config() {
  info "先写入一个可启动的本地 Gateway 基础配置……"
  ubuntu_run "set -euo pipefail
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z \"\$OPENCLAW_BIN\" ] && [ -x \"\$HOME/.openclaw/bin/openclaw\" ]; then
  OPENCLAW_BIN=\"\$HOME/.openclaw/bin/openclaw\"
fi
[ -n \"\$OPENCLAW_BIN\" ] || { echo '未找到 openclaw 主程序。'; exit 1; }
mkdir -p ~/.openclaw ~/.openclaw/workspace
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
\"\$OPENCLAW_BIN\" onboard --non-interactive \
  --mode local \
  --auth-choice skip \
  --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --skip-skills \
  --accept-risk
\"\$OPENCLAW_BIN\" config validate"
  success "基础配置已写入，后续即使暂时不配 DeepSeek，也不会再卡在 Missing config。"
}

configure_deepseek_now() {
  if [ -z "$DEEPSEEK_API_KEY" ]; then
    warn "你刚才跳过了 DeepSeek API Key。脚本已写好本地 Gateway 基础配置，稍后可再运行“配置DeepSeek.sh”。"
    return 0
  fi

  info "调用 OpenClaw 官方 onboard --non-interactive 自动写入 DeepSeek 配置……"
  ubuntu_run "set -euo pipefail
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z \"\$OPENCLAW_BIN\" ] && [ -x \"\$HOME/.openclaw/bin/openclaw\" ]; then
  OPENCLAW_BIN=\"\$HOME/.openclaw/bin/openclaw\"
fi
[ -n \"\$OPENCLAW_BIN\" ] || { echo '未找到 openclaw 主程序。'; exit 1; }
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
\"\$OPENCLAW_BIN\" onboard --non-interactive \
  --mode local \
  --auth-choice custom-api-key \
  --custom-provider-id deepseek \
  --custom-base-url https://api.deepseek.com/v1 \
  --custom-model-id ${MODEL_ID} \
  --custom-compatibility openai \
  --secret-input-mode ref \
  --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --skip-skills \
  --accept-risk
\"\$OPENCLAW_BIN\" config set agents.defaults.model.primary 'deepseek/${MODEL_ID}'
\"\$OPENCLAW_BIN\" config validate"
  success "DeepSeek 已按官方 non-interactive onboarding 方式写入配置。"
}

set_local_no_auth_mode() {
  info "为保证手机本机开箱即用，正在把 loopback 认证改为 none……"
  ubuntu_run "set -euo pipefail
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z \"\$OPENCLAW_BIN\" ] && [ -x \"\$HOME/.openclaw/bin/openclaw\" ]; then
  OPENCLAW_BIN=\"\$HOME/.openclaw/bin/openclaw\"
fi
[ -n \"\$OPENCLAW_BIN\" ] || { echo '未找到 openclaw 主程序。'; exit 1; }
\"\$OPENCLAW_BIN\" config set gateway.auth.mode none
\"\$OPENCLAW_BIN\" config validate"
  success "本机 loopback 已设置为免 token 模式。"
}

create_reconfigure_helper() {
  cat > "${HELPER_DIR}/配置DeepSeek.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
read -r -s -p "请输入 DeepSeek API Key：" DS_KEY
echo
read -r -p "请输入默认模型 [默认 deepseek-chat，可改为 deepseek-reasoner]：" DS_MODEL
DS_MODEL="${DS_MODEL:-deepseek-chat}"
export DS_KEY DS_MODEL
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
set -euo pipefail
ENV_FILE="$HOME/.openclaw/.env"
mkdir -p ~/.openclaw ~/.openclaw/workspace
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"
python3 - <<\"PY\"
from pathlib import Path
import os
p = Path(os.path.expanduser("~/.openclaw/.env"))
lines = p.read_text().splitlines() if p.exists() else []
vals = {}
for line in lines:
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        vals[k] = v
vals["CUSTOM_API_KEY"] = os.environ["DS_KEY"]
p.write_text("\\n".join(f"{k}={v}" for k, v in vals.items()) + "\\n")
PY
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
"$OPENCLAW_BIN" onboard --non-interactive \
  --mode local \
  --auth-choice custom-api-key \
  --custom-provider-id deepseek \
  --custom-base-url https://api.deepseek.com/v1 \
  --custom-model-id "$DS_MODEL" \
  --custom-compatibility openai \
  --secret-input-mode ref \
  --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --skip-skills \
  --accept-risk
"$OPENCLAW_BIN" config set agents.defaults.model.primary "deepseek/$DS_MODEL"
"$OPENCLAW_BIN" config set gateway.auth.mode none
"$OPENCLAW_BIN" config validate
'
echo
echo "DeepSeek 配置完成。"
echo "现在可以运行：openclawx start"
EOF_HELPER
  chmod +x "${HELPER_DIR}/配置DeepSeek.sh"
}

create_enable_token_helper() {
  cat > "${HELPER_DIR}/开启Token认证.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
read -r -p "请输入你要设置的网关 token（留空则自动生成一串随机 token）：" INPUT_TOKEN
if [ -z "${INPUT_TOKEN:-}" ]; then
  INPUT_TOKEN="hc-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi
export INPUT_TOKEN OPENCLAW_GATEWAY_TOKEN="$INPUT_TOKEN"
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
set -euo pipefail
ENV_FILE="$HOME/.openclaw/.env"
mkdir -p ~/.openclaw
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"
python3 - <<\"PY\"
from pathlib import Path
import os
p = Path(os.path.expanduser("~/.openclaw/.env"))
lines = p.read_text().splitlines() if p.exists() else []
vals = {}
for line in lines:
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        vals[k] = v
vals["OPENCLAW_GATEWAY_TOKEN"] = os.environ["INPUT_TOKEN"]
p.write_text("\\n".join(f"{k}={v}" for k, v in vals.items()) + "\\n")
PY
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
"$OPENCLAW_BIN" config set gateway.auth.mode token
"$OPENCLAW_BIN" config set gateway.auth.token "${OPENCLAW_GATEWAY_TOKEN}"
"$OPENCLAW_BIN" config validate
'
echo
echo "已开启 token 认证。"
echo "请在网页设置里填写 token：${INPUT_TOKEN}"
echo "如果网页曾经填错过 token，请清掉 127.0.0.1:18789 的站点数据后再连。"
EOF_HELPER
  chmod +x "${HELPER_DIR}/开启Token认证.sh"
}

create_disable_token_helper() {
  cat > "${HELPER_DIR}/关闭Token认证.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
set -euo pipefail
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
"$OPENCLAW_BIN" config set gateway.auth.mode none
"$OPENCLAW_BIN" config validate
'
echo "已切回本机免 token 模式。"
EOF_HELPER
  chmod +x "${HELPER_DIR}/关闭Token认证.sh"
}

create_dashboard_helper() {
  cat > "${HELPER_DIR}/打开仪表板.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
set -euo pipefail
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
"$OPENCLAW_BIN" dashboard
'
EOF_HELPER
  chmod +x "${HELPER_DIR}/打开仪表板.sh"
}

create_repair_helper() {
  cat > "${HELPER_DIR}/修复本地初始化.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
set -euo pipefail
ENV_FILE="$HOME/.openclaw/.env"
mkdir -p ~/.openclaw ~/.openclaw/workspace
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"
if ! grep -q "^OPENCLAW_GATEWAY_TOKEN=" "$ENV_FILE"; then
  echo "OPENCLAW_GATEWAY_TOKEN=hc-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d \" \n\")" >> "$ENV_FILE"
fi
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
"$OPENCLAW_BIN" onboard --non-interactive \
  --mode local \
  --auth-choice skip \
  --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --skip-skills \
  --accept-risk
"$OPENCLAW_BIN" config set gateway.auth.mode none
"$OPENCLAW_BIN" config validate
'
echo "本地初始化已修复。现在可以运行：openclawx start"
EOF_HELPER
  chmod +x "${HELPER_DIR}/修复本地初始化.sh"
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
  create_enable_token_helper
  create_disable_token_helper
  create_dashboard_helper
  create_repair_helper

  cat > "${DOCS_DIR}/01-安装完成后先看我.txt" <<EOF_README
OpenClaw Termux DeepSeek 中文说明
封装：黑客驰 / hackerchi.top

一、你现在最常用的命令
1. 启动 OpenClaw：bash ~/openclaw-helper/启动OpenClaw.sh
2. 进入 Ubuntu：bash ~/openclaw-helper/进入Ubuntu.sh
3. 打开仪表板：bash ~/openclaw-helper/打开仪表板.sh
4. 重新配置 DeepSeek：bash ~/openclaw-helper/配置DeepSeek.sh
5. 开启 token 认证：bash ~/openclaw-helper/开启Token认证.sh
6. 关闭 token 认证：bash ~/openclaw-helper/关闭Token认证.sh
7. 修复本地初始化：bash ~/openclaw-helper/修复本地初始化.sh

二、本机访问地址
http://127.0.0.1:18789/

三、当前默认模型
${MODEL_ID}

四、当前认证模式
${LOCAL_AUTH_MODE}
说明：为了避免首次网页认证卡住，脚本默认把本机 loopback 设置为免 token。
如果你后面需要电脑/平板接入，请手动运行：bash ~/openclaw-helper/开启Token认证.sh

五、说明
1. 如果你安装时跳过了 DeepSeek API Key，后面仍可运行：bash ~/openclaw-helper/配置DeepSeek.sh
2. 即使跳过 API Key，脚本也会先写好本地 Gateway 基础配置，不会再卡在 Missing config
3. 如果手机后台容易被杀，请把 Termux 的电池优化设为“不受限制”
4. 如果网页仍然异常，优先运行：bash ~/openclaw-helper/修复本地初始化.sh
5. 如果浏览器之前填错过 token，请清掉 127.0.0.1:18789 的站点数据或改用无痕模式
6. 本中文脚本版权：黑客驰 / hackerchi.top
EOF_README
}

maybe_start_gateway() {
  echo
  read -r -p "是否现在直接启动 OpenClaw？[Y/n]：" choice
  choice="${choice:-Y}"
  case "$choice" in
    n|N)
      success "已跳过自动启动。稍后可运行：openclawx start"
      ;;
    *)
      openclawx start
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
  echo "本机认证：免 token（仅适合本机使用）"
  if [ -n "$DEEPSEEK_API_KEY" ]; then
    echo "DeepSeek：已自动配置完成"
  else
    echo "DeepSeek：你刚才跳过了 API Key，尚未自动配置"
    echo "稍后运行：bash ~/openclaw-helper/配置DeepSeek.sh"
  fi
  echo "帮助目录：${HELPER_DIR}"
  echo "说明目录：${DOCS_DIR}"
  echo "如需电脑/平板接入：bash ~/openclaw-helper/开启Token认证.sh"
  echo "封装版权：黑客驰 / hackerchi.top"
}

main() {
  print_banner
  check_termux
  check_android_hint
  ask_inputs
  install_termux_packages
  configure_npm_registry
  install_openclaw_termux
  run_openclawx_setup
  prepare_env_file
  copy_env_into_ubuntu
  configure_ubuntu_npm
  bootstrap_local_gateway_config
  configure_deepseek_now
  set_local_no_auth_mode
  create_helper_files
  final_summary
  maybe_start_gateway
}

main "$@"
