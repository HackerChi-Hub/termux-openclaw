#!/data/data/com.termux/files/usr/bin/bash
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
TERMUX_TMP="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
DEEPSEEK_API_KEY=""
MODEL_ID="deepseek-chat"

info() { echo -e "${CYAN}[信息]${NC} $*"; }
success() { echo -e "${GREEN}[完成]${NC} $*"; }
warn() { echo -e "${YELLOW}[提醒]${NC} $*"; }
die() { echo -e "${RED}[错误]${NC} $*"; exit 1; }
cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT

print_banner() {
  clear || true
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║      OpenClaw Termux DeepSeek 中文一键安装脚本           ║${NC}"
  echo -e "${BLUE}║     兼容旧 CLI · 免 token 本机模式 · 内置 Error13 修复   ║${NC}"
  echo -e "${BLUE}║            封装：黑客驰 · hackerchi.top                  ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo
}

ask_inputs() {
  echo "安装完成后默认在手机本机访问：http://127.0.0.1:18789/"
  echo "为避免首次认证卡住，脚本默认把本机 loopback 认证设为 none。"
  echo "如果后面需要电脑/平板接入，可再用辅助脚本开启 token。"
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
  mkdir -p "$TMP_DIR"
  local host_script="$TMP_DIR/ubuntu_cmd_$$.sh"
  cat > "$host_script" <<EOS
set -euo pipefail
FIX_ENV="\$HOME/.openclaw/android_network_fix.sh"
if [ -f "\$FIX_ENV" ]; then
  . "\$FIX_ENV"
fi
$cmd
EOS
  chmod 700 "$host_script"
  proot-distro login ubuntu --shared-tmp -- /bin/bash "$host_script"
  rm -f "$host_script"
}

install_android_network_fix() {
  info "写入 Android / PRoot 网络接口兼容修复（规避 uv_interface_addresses Error 13）……"
  proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
set -euo pipefail
mkdir -p ~/.openclaw
cat > ~/.openclaw/uv_interface_addresses_fix.js <<"EOF_JS"
const os = require("os");
os.networkInterfaces = () => ({
  lo: [{
    address: "127.0.0.1",
    netmask: "255.0.0.0",
    family: "IPv4",
    internal: true,
    cidr: "127.0.0.1/8",
    mac: "00:00:00:00:00:00"
  }]
});
EOF_JS
cat > ~/.openclaw/android_network_fix.sh <<"EOF_SH"
export NODE_OPTIONS="--require=$HOME/.openclaw/uv_interface_addresses_fix.js${NODE_OPTIONS:+ $NODE_OPTIONS}"
EOF_SH
chmod 600 ~/.openclaw/android_network_fix.sh ~/.openclaw/uv_interface_addresses_fix.js
'
  success "已写入 Android 网络接口兼容修复。"
}

prepare_env_file() {
  mkdir -p "$TMP_DIR" "$DOCS_DIR" "$HELPER_DIR"
  cat > "$ENV_FILE_HOST" <<EOF_ENV
# OpenClaw 本地环境变量（由黑客驰 / hackerchi.top 脚本生成）
CUSTOM_API_KEY=${DEEPSEEK_API_KEY}
EOF_ENV
  chmod 600 "$ENV_FILE_HOST"
}

copy_env_into_ubuntu() {
  info "写入 Ubuntu 内部的 ~/.openclaw/.env ……"
  ubuntu_run "mkdir -p ~/.openclaw ~/.openclaw/workspace"
  cp "$ENV_FILE_HOST" "$TERMUX_TMP/openclaw.env"
  proot-distro login ubuntu --shared-tmp -- /bin/bash -lc 'mkdir -p ~/.openclaw ~/.openclaw/workspace && cp /tmp/openclaw.env ~/.openclaw/.env && chmod 600 ~/.openclaw/.env'
  rm -f "$TERMUX_TMP/openclaw.env"
  success "环境变量文件已写入 Ubuntu：~/.openclaw/.env"
}

configure_ubuntu_npm() {
  info "在 Ubuntu 内部也优先设置 npmmirror……"
  ubuntu_run "if command -v npm >/dev/null 2>&1; then npm config set registry '$NPM_REGISTRY_CN' >/dev/null 2>&1 || true; fi"
  success "Ubuntu 内部 npm 镜像已设置。"
}

bootstrap_local_gateway_config() {
  info "先写入一个可启动的本地 Gateway 基础配置……"
  ubuntu_run '
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
mkdir -p ~/.openclaw ~/.openclaw/workspace
set +u
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
set -u
"$OPENCLAW_BIN" onboard --non-interactive \
  --mode local \
  --auth-choice skip \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --skip-skills \
  --accept-risk || true
"$OPENCLAW_BIN" config validate || true
'
  success "基础配置已写入，后续即使暂时不配 DeepSeek，也不会再卡在 Missing config。"
}

configure_deepseek_now() {
  if [ -z "$DEEPSEEK_API_KEY" ]; then
    warn "你刚才跳过了 DeepSeek API Key。脚本已写好本地 Gateway 基础配置，稍后可再运行"配置DeepSeek.sh"。"
    return 0
  fi

  info "调用 OpenClaw 官方 onboard --non-interactive 自动写入 DeepSeek 配置……"
  ubuntu_run "
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z \"\$OPENCLAW_BIN\" ] && [ -x \"\$HOME/.openclaw/bin/openclaw\" ]; then
  OPENCLAW_BIN=\"\$HOME/.openclaw/bin/openclaw\"
fi
[ -n \"\$OPENCLAW_BIN\" ] || { echo \"未找到 openclaw 主程序。\"; exit 1; }
set +u
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
set -u
\"\$OPENCLAW_BIN\" onboard --non-interactive \
  --mode local \
  --auth-choice custom-api-key \
  --custom-provider-id deepseek \
  --custom-base-url https://api.deepseek.com/v1 \
  --custom-model-id ${MODEL_ID} \
  --custom-compatibility openai \
  --secret-input-mode ref \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --skip-skills \
  --accept-risk || true
\"\$OPENCLAW_BIN\" config set agents.defaults.model.primary 'deepseek/${MODEL_ID}'  || true
\"\$OPENCLAW_BIN\" config validate || true
"
  success "DeepSeek 已按官方 non-interactive onboarding 方式写入配置。"
}

set_local_no_auth_mode() {
  info "为保证手机本机开箱即用，正在把 loopback 认证改为 none……"
  ubuntu_run '
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
"$OPENCLAW_BIN" config set gateway.auth.mode none  || true
"$OPENCLAW_BIN" config validate || true
'
  success "本机 loopback 已设置为免 token 模式。"
}

create_reconfigure_helper() {
  cat > "${HELPER_DIR}/配置DeepSeek.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
TERMUX_TMP="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
read -r -s -p "请输入 DeepSeek API Key：" DS_KEY
 echo
read -r -p "请输入默认模型 [默认 deepseek-chat，可改为 deepseek-reasoner]：" DS_MODEL
DS_MODEL="${DS_MODEL:-deepseek-chat}"
cat > "$TERMUX_TMP/openclaw_ds_reconfig.sh" <<EOF_INNER
set -euo pipefail
FIX_ENV="\$HOME/.openclaw/android_network_fix.sh"
if [ -f "\$FIX_ENV" ]; then
  . "\$FIX_ENV"
fi
mkdir -p ~/.openclaw ~/.openclaw/workspace
touch ~/.openclaw/.env
chmod 600 ~/.openclaw/.env
python3 - <<'PY'
from pathlib import Path
p = Path.home()/'.openclaw'/'.env'
lines = p.read_text().splitlines() if p.exists() else []
vals = {}
for line in lines:
    if '=' in line and not line.startswith('#'):
        k,v = line.split('=',1)
        vals[k]=v
vals['CUSTOM_API_KEY'] = '''${DS_KEY}'''
p.write_text('\n'.join(f"{k}={v}" for k,v in vals.items()) + '\n')
PY
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z "\$OPENCLAW_BIN" ] && [ -x "\$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="\$HOME/.openclaw/bin/openclaw"
fi
[ -n "\$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
set +u
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
set -u
"\$OPENCLAW_BIN" onboard --non-interactive \
  --mode local \
  --auth-choice custom-api-key \
  --custom-provider-id deepseek \
  --custom-base-url https://api.deepseek.com/v1 \
  --custom-model-id "${DS_MODEL}" \
  --custom-compatibility openai \
  --secret-input-mode ref \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --skip-skills \
  --accept-risk || true
"\$OPENCLAW_BIN" config set agents.defaults.model.primary "deepseek/${DS_MODEL}"  || true
"\$OPENCLAW_BIN" config set gateway.auth.mode none  || true
"\$OPENCLAW_BIN" config validate || true
EOF_INNER
proot-distro login ubuntu --shared-tmp -- /bin/bash /tmp/openclaw_ds_reconfig.sh
rm -f "$TERMUX_TMP/openclaw_ds_reconfig.sh"
echo "DeepSeek 配置完成。重新启动：openclawx start"
EOF_HELPER
  chmod +x "${HELPER_DIR}/配置DeepSeek.sh"
}

create_enable_token_helper() {
  cat > "${HELPER_DIR}/开启Token认证.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
TERMUX_TMP="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
read -r -p "请输入你想自定义的 token：" INPUT_TOKEN
[ -n "$INPUT_TOKEN" ] || { echo "token 不能为空。"; exit 1; }
cat > "$TERMUX_TMP/openclaw_enable_token.sh" <<EOF_INNER
set -euo pipefail
FIX_ENV="\$HOME/.openclaw/android_network_fix.sh"
if [ -f "\$FIX_ENV" ]; then
  . "\$FIX_ENV"
fi
mkdir -p ~/.openclaw
touch ~/.openclaw/.env
chmod 600 ~/.openclaw/.env
python3 - <<'PY'
from pathlib import Path
p = Path.home()/'.openclaw'/'.env'
lines = p.read_text().splitlines() if p.exists() else []
vals = {}
for line in lines:
    if '=' in line and not line.startswith('#'):
        k,v = line.split('=',1)
        vals[k]=v
vals['OPENCLAW_GATEWAY_TOKEN'] = '''${INPUT_TOKEN}'''
p.write_text('\n'.join(f"{k}={v}" for k,v in vals.items()) + '\n')
PY
OPENCLAW_BIN=\$(command -v openclaw || true)
if [ -z "\$OPENCLAW_BIN" ] && [ -x "\$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="\$HOME/.openclaw/bin/openclaw"
fi
[ -n "\$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
"\$OPENCLAW_BIN" config set gateway.auth.mode token  || true
"\$OPENCLAW_BIN" config set gateway.auth.token '${INPUT_TOKEN}'  || true
"\$OPENCLAW_BIN" config validate || true
EOF_INNER
proot-distro login ubuntu --shared-tmp -- /bin/bash /tmp/openclaw_enable_token.sh
rm -f "$TERMUX_TMP/openclaw_enable_token.sh"
echo "已开启 token 认证。请在网页设置里填写 token：${INPUT_TOKEN}"
EOF_HELPER
  chmod +x "${HELPER_DIR}/开启Token认证.sh"
}

create_disable_token_helper() {
  cat > "${HELPER_DIR}/关闭Token认证.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
TERMUX_TMP="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
cat > "$TERMUX_TMP/openclaw_disable_token.sh" <<'EOF_INNER'
set -euo pipefail
FIX_ENV="$HOME/.openclaw/android_network_fix.sh"
if [ -f "$FIX_ENV" ]; then
  . "$FIX_ENV"
fi
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
"$OPENCLAW_BIN" config set gateway.auth.mode none  || true
"$OPENCLAW_BIN" config validate || true
EOF_INNER
proot-distro login ubuntu --shared-tmp -- /bin/bash /tmp/openclaw_disable_token.sh
rm -f "$TERMUX_TMP/openclaw_disable_token.sh"
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
FIX_ENV="$HOME/.openclaw/android_network_fix.sh"
if [ -f "$FIX_ENV" ]; then
  . "$FIX_ENV"
fi
OPENCLAW_BIN=$(command -v openclaw || true)
if [ -z "$OPENCLAW_BIN" ] && [ -x "$HOME/.openclaw/bin/openclaw" ]; then
  OPENCLAW_BIN="$HOME/.openclaw/bin/openclaw"
fi
[ -n "$OPENCLAW_BIN" ] || { echo "未找到 openclaw 主程序。"; exit 1; }
set +u
set -a
[ -f ~/.openclaw/.env ] && . ~/.openclaw/.env
set +a
set -u
"$OPENCLAW_BIN" dashboard
'
EOF_HELPER
  chmod +x "${HELPER_DIR}/打开仪表板.sh"
}

create_repair_helper() {
  cat > "${HELPER_DIR}/修复Error13网络接口.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
set -euo pipefail
mkdir -p ~/.openclaw
cat > ~/.openclaw/uv_interface_addresses_fix.js <<"EOF_JS"
const os = require("os");
os.networkInterfaces = () => ({
  lo: [{
    address: "127.0.0.1",
    netmask: "255.0.0.0",
    family: "IPv4",
    internal: true,
    cidr: "127.0.0.1/8",
    mac: "00:00:00:00:00:00"
  }]
});
EOF_JS
cat > ~/.openclaw/android_network_fix.sh <<"EOF_SH"
export NODE_OPTIONS="--require=$HOME/.openclaw/uv_interface_addresses_fix.js${NODE_OPTIONS:+ $NODE_OPTIONS}"
EOF_SH
chmod 600 ~/.openclaw/android_network_fix.sh ~/.openclaw/uv_interface_addresses_fix.js
'
echo "Error 13 网络接口兼容修复已重新写入。"
EOF_HELPER
  chmod +x "${HELPER_DIR}/修复Error13网络接口.sh"
}

create_misc_helpers() {
  cat > "${HELPER_DIR}/启动OpenClaw.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
openclawx start
EOF_HELPER
  cat > "${HELPER_DIR}/进入Ubuntu.sh" <<'EOF_HELPER'
#!/data/data/com.termux/files/usr/bin/bash
openclawx shell
EOF_HELPER
  chmod +x "${HELPER_DIR}/启动OpenClaw.sh" "${HELPER_DIR}/进入Ubuntu.sh"
}

write_docs() {
  cat > "${DOCS_DIR}/01-安装完成后先看我.txt" <<EOF_README
OpenClaw Termux DeepSeek 中文说明
封装：黑客驰 / hackerchi.top

一、最常用命令
1. 启动 OpenClaw：bash ~/openclaw-helper/启动OpenClaw.sh
2. 打开仪表板：bash ~/openclaw-helper/打开仪表板.sh
3. 配置 DeepSeek：bash ~/openclaw-helper/配置DeepSeek.sh
4. 开启 token：bash ~/openclaw-helper/开启Token认证.sh
5. 关闭 token：bash ~/openclaw-helper/关闭Token认证.sh
6. 修复 Error13：bash ~/openclaw-helper/修复Error13网络接口.sh
7. 进入 Ubuntu：bash ~/openclaw-helper/进入Ubuntu.sh

二、本机地址
http://127.0.0.1:18789/

三、默认模型
${MODEL_ID}

四、当前认证模式
none

五、说明
1. 如果你安装时跳过了 DeepSeek API Key，后面仍可运行：bash ~/openclaw-helper/配置DeepSeek.sh
2. 脚本已内置 Android/PRoot 的 Error 13 网络接口兼容修复
3. 如果手机后台容易被杀，请把 Termux 的电池优化设为"不受限制"
4. 本中文脚本版权：黑客驰 / hackerchi.top
EOF_README
}

maybe_start_gateway() {
  echo
  read -r -p "是否现在直接启动 OpenClaw？[Y/n]：" choice
  choice="${choice:-Y}"
  case "$choice" in
    n|N) success "已跳过自动启动。稍后可运行：openclawx start" ;;
    *) openclawx start ;;
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
  ask_inputs
  install_termux_packages
  configure_npm_registry
  install_openclaw_termux
  run_openclawx_setup
  install_android_network_fix
  prepare_env_file
  copy_env_into_ubuntu
  configure_ubuntu_npm
  bootstrap_local_gateway_config
  configure_deepseek_now
  set_local_no_auth_mode
  create_reconfigure_helper
  create_enable_token_helper
  create_disable_token_helper
  create_dashboard_helper
  create_repair_helper
  create_misc_helpers
  write_docs
  final_summary
  maybe_start_gateway
}

main "$@"
