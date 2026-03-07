# OpenClaw Termux DeepSeek 中文一键安装脚本

主推脚本：`openclaw_termux_cn_installer.sh`  
封装作者：**黑客驰 / hackerchi.top**

这是一个面向 **Termux** 的 OpenClaw 中文安装脚本，目标是尽量做到：

- 一条命令安装 `openclaw-termux`
- 自动执行 `openclawx setup`
- 自动调用 **OpenClaw 官方** `openclaw onboard --non-interactive`
- 自动按 **DeepSeek OpenAI 兼容接口** 写入 custom provider 配置
- 默认本机免 token 直连，尽量避免首次网页认证卡住
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
termux-setup-storage && pkg update -y && pkg install -y git && git clone https://gitee.com/hyphentech/openclaw-Termux.git && cd openclaw-Termux && chmod +x openclaw_termux_cn_installer.sh && bash openclaw_termux_cn_installer.sh
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
bash ~/openclaw-helper/进入Ubuntu.sh
```

---

## 这份脚本做了什么

脚本会自动完成：

1. 安装 Termux 依赖
2. 安装 `openclaw-termux`
3. 执行 `openclawx setup`
4. 在 Ubuntu/proot 内写入 `~/.openclaw/.env`
5. 调用 `openclaw onboard --non-interactive`
6. 自动接入 DeepSeek（如已输入 API Key）
7. 显式把默认模型切到 `deepseek/deepseek-chat` 或 `deepseek/deepseek-reasoner`
8. 默认把本机 loopback 认证设为 `none`，避免首次网页 token 认证卡住
9. 生成后续辅助脚本，便于补配、开 token、打开仪表板

---

## 为什么默认本机免 token

OpenClaw 现在默认连 `127.0.0.1` 也启用 token 认证。很多人在手机本机第一次打开网页时，最常见的问题不是网关没起来，而是：

- `gateway token missing`
- `unauthorized`
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

---

## 常用命令

### Termux 外层

```bash
openclawx setup
openclawx status
openclawx start
openclawx shell
```

### Ubuntu 内部

```bash
openclaw onboard
openclaw config validate
openclaw dashboard
openclaw doctor --generate-gateway-token
openclaw logs --follow
openclaw gateway status
openclaw status
```

---

## 常见问题

### 1）`openclaw` 找不到命令

在 Termux 外层应使用 `openclawx`。  
`openclaw` 主程序在 Ubuntu/proot 里。

### 2）`openclawx onboarding` 不工作

现在官方命令是：

```bash
openclawx shell
openclaw onboard
```

### 3）网页打不开或一直离线

先确认网关已启动：

```bash
openclawx start
```

再尝试：

```bash
bash ~/openclaw-helper/打开仪表板.sh
```

### 4）需要电脑/平板也能接入

运行：

```bash
bash ~/openclaw-helper/开启Token认证.sh
```

然后把脚本输出的 token 填到网页设置里。

### 5）浏览器一直 `unauthorized`

如果你之前填错过 token，请：

- 清掉 `127.0.0.1:18789` 的站点数据
- 或者换无痕模式打开
- 再重新连接

---

## 已知限制

这份脚本已经比旧版更接近“装完即能用”，但仍有现实边界：

- `openclawx setup` 过程中仍受你当时网络影响
- 浏览器站点缓存不是脚本能强制清理的
- 如果以后你切回 token 模式，网页仍可能需要手工重连一次

所以更准确地说，它是：

**“尽量自动完成安装和 DeepSeek 接入，并最大限度减少首次使用摩擦。”**

---

## 版权

本中文封装脚本与中文说明版权归：

**黑客驰 / hackerchi.top**

上游项目 `openclaw-termux` 与 OpenClaw 官方项目的许可证和版权，仍以各自上游仓库为准。
