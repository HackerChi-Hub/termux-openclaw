# OpenClaw Termux DeepSeek 中文一键安装脚本

主推脚本：`openclaw_termux_cn_installer.sh`  
封装作者：**黑客驰 / hackerchi.top**
这是一个面向 **Termux** 的 OpenClaw 中文安装脚本，目标是尽量做到：

- 一条命令安装 `openclaw-termux`
- 自动执行 `openclawx setup`
- 自动调用 **OpenClaw 官方** `openclaw onboard --non-interactive`
- 自动按 **DeepSeek OpenAI 兼容接口** 写入 custom provider 配置
- 默认本机免 token 直连，尽量避免首次网页认证卡住
- 内置 Android / PRoot 的 **Error 13** 网络接口兼容修复
- 额外提供“一键开启 token 认证”辅助脚本，方便后续电脑/平板接入

> 说明：这条路线是 **Termux 社区方案**，不是 OpenClaw 官方 Android 主线。

---

## 环境要求

- Android 10 / API 29 及以上更稳
- 建议使用 **F-Droid 版 Termux**
- 预留约 500MB 或以上可用空间
- 建议把 Termux 的电池优化设为“不受限制”

---

## 安装方法

### 方式一：克隆仓库后运行

```bash
pkg update -y && pkg install -y git
git clone https://gitee.com/hyphentech/openclaw-Termux.git
cd openclaw-Termux
chmod +x openclaw_termux_cn_installer.sh
bash openclaw_termux_cn_installer.sh
```

### 方式二：如果脚本在下载目录

```bash
termux-setup-storage
bash ~/storage/downloads/openclaw_termux_cn_installer.sh
```

---

## 安装后怎么用

### 启动 OpenClaw

```bash
openclawx start
```

### 交互式配置向导

```bash
openclawx onboarding
```

选择 **Loopback (127.0.0.1)**，然后按提示输入 API Key 和选择模型。

### 本机网页地址

```text
http://127.0.0.1:18789/
```

### 最常用辅助脚本

```bash
bash ~/openclaw-helper/启动OpenClaw.sh
bash ~/openclaw-helper/打开仪表板.sh
bash ~/openclaw-helper/配置DeepSeek.sh
bash ~/openclaw-helper/开启Token认证.sh
bash ~/openclaw-helper/关闭Token认证.sh
bash ~/openclaw-helper/修复Error13网络接口.sh
bash ~/openclaw-helper/进入Ubuntu.sh
```

---

## 这份脚本现在会做什么

脚本会自动完成：

1. 安装 Termux 依赖
2. 安装 `openclaw-termux`
3. 执行 `openclawx setup`
4. 写入 Android / PRoot 的 Error 13 网络接口兼容修复
5. 在 Ubuntu/proot 内写入 `~/.openclaw/.env`
6. 先执行一次基础 onboarding，确保 Gateway 至少可以启动
7. 如果你已提供 DeepSeek API Key，再执行一次 DeepSeek 定向 onboarding
8. 显式把默认模型切到 `deepseek/deepseek-chat` 或 `deepseek/deepseek-reasoner`
9. 默认把本机 loopback 认证设为 `none`
10. 生成后续辅助脚本，便于补配、开 token、打开仪表板和修复网络接口

---

## 这次修了什么

### 1）不再依赖 `CMD_B64` 环境变量传递

旧版脚本在某些 `proot-distro login ubuntu` 场景下，会出现：

```text
/bin/bash: line 7: CMD_B64: unbound variable
```

最新版已经改成 **临时脚本文件** 方式把命令传进 Ubuntu，不再依赖 `CMD_B64` 环境变量传递。

### 2）不再使用你当前 CLI 不支持的 `--gateway-token-ref-env`

当前脚本兼容你手机里的 OpenClaw CLI，不再依赖这个参数。

### 3）内置 Error 13 兼容修复

如果遇到：

```text
uv_interface_addresses returned Unknown system error 13
```

可以直接运行：

```bash
bash ~/openclaw-helper/修复Error13网络接口.sh
```

---

## 为什么默认本机免 token

OpenClaw 默认连 `127.0.0.1` 也可能要求 token。很多人在手机本机第一次打开网页时，最常见的问题不是网关没起来，而是：

- `gateway token missing`
- `unauthorized`
- `too many failed authentication attempts`
- 浏览器缓存了旧 token 反复重连

所以这份脚本默认更偏向“本机先跑通”的路线：

- **手机本机使用**：默认免 token，装完更容易直接打开页面
- **后续电脑/平板接入**：再运行 `开启Token认证.sh` 开启 token 模式

如果你后面要跨设备访问，建议再打开 token 认证。

---

## DeepSeek 配置说明

脚本支持：

- `deepseek-chat`
- `deepseek-reasoner`

安装时如果跳过了 API Key，后面可以运行：

```bash
bash ~/openclaw-helper/配置DeepSeek.sh
```

也可以用 OpenClaw 自带的交互式向导重新配置：

```bash
# Termux 外层
openclawx onboarding

# 或进入 Ubuntu 后
openclawx shell
openclaw onboard
```

如果只想改某一部分（如 web 搜索 API Key），可以用：

```bash
openclawx shell
openclaw configure --section web
```

---

## 常用命令

### Termux 外层

```bash
openclawx setup
openclawx start
openclawx onboarding
openclawx shell
openclawx status
openclawx doctor
```

### Ubuntu 内部

```bash
openclaw onboard
openclaw configure
openclaw config validate
openclaw dashboard
openclaw logs --follow
openclaw gateway status
openclaw gateway --verbose
openclaw status
```

---

## 常见问题

### 1）`openclaw` 找不到命令

在 Termux 外层应使用 `openclawx`。  
`openclaw` 主程序在 Ubuntu/proot 里。

> 注意区分：Termux 里用 `openclawx onboarding`，Ubuntu 里用 `openclaw onboard`（少一个 ing）。

### 2）跳过 DeepSeek API Key 后还能启动吗

能。  
这版脚本会先写入基础本地 Gateway 配置，不会再因为没填 API Key 就卡在 `Missing config`。

### 3）网页打不开或一直离线

先检查安装状态和诊断：

```bash
openclawx status
openclawx doctor
```

确认网关已启动：

```bash
openclawx start
```

如果仍然不行，先运行：

```bash
bash ~/openclaw-helper/修复Error13网络接口.sh
bash ~/openclaw-helper/打开仪表板.sh
```

### 4）浏览器一直 `unauthorized`

如果你之前填错过 token，请：

- 清掉 `127.0.0.1:18789` 的站点数据
- 或者换无痕模式打开
- 再重新连接

### 5）需要电脑/平板也能接入

运行：

```bash
bash ~/openclaw-helper/开启Token认证.sh
```

然后把脚本输出的 token 填到网页设置里。

---

## 版权

本中文封装脚本与中文说明版权归：

**黑客驰 / hackerchi.top**

上游项目 `openclaw-termux` 与 OpenClaw 官方项目的许可证和版权，仍以各自上游仓库为准。
