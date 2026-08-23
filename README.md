<div align="center">

# 🌌 Singular (奇点)

**Next-Generation Desktop GUI Client for sing-box**

*为现代网络代理打造的极致美学、超低开销、全协议桌面控制台*

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![sing-box](https://img.shields.io/badge/sing--box-1.10+-7C3AED?style=for-the-badge&logo=electron&logoColor=white)](https://github.com/SagerNet/sing-box)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/leetomlee123/sb-ui/releases)
[![License](https://img.shields.io/badge/License-MIT-emerald?style=for-the-badge)](LICENSE)

</div>

---

## 🌟 核心特性 (Key Features)

### 🌌 1. 黑曜石极客美学与零开销架构 (Obsidian UI & Zero-Overhead)
- **极简无边框设计**：沉浸式黑曜石深色/浅色自适应主题，晶格 Bento Grid 布局。
- **0% 待机 CPU 开销**：优化图表动画渲染与后台 Tab 冻结，待机时 CPU 占用近乎 0%。
- **90 秒实时流量波形图**：高灵敏度实时折线图，悬浮探针精确展示 2 位小数及即时速率（支持在设置中按需开闭）。

### 🛠️ 2. 全协议可视化表单构建器 (Multi-Protocol Manual Form)
无需手动编写 JSON，内置多协议专属图形化表单生成器：
- ⚡ **VLESS**：支持 Vision 流控（`xtls-rprx-vision`）、**Reality 伪装**（SNI / PublicKey / ShortID / uTLS 指纹）与标准 TLS。
- 🚀 **Hysteria 2 (Hy2)**：支持 Salamander 混淆密码与上下行独立带宽速率限制（Up/Down Mbps）。
- 🔒 **Shadowsocks (SS)**：完整支持 AEAD-2022（`2022-blake3-aes-128-gcm` 等）、AES-GCM、ChaCha20 及 Plugin 选项。
- ☁️ **VMess / Trojan / TUIC / SOCKS5 / HTTP**：全协议专属字段动态校验与一键生成。

### 📊 3. 内核级精准流量计量 (Authoritative Traffic Accounting)
- **内核绝对计数**：直接同步 sing-box 核心原生 `downloadTotal` 与 `uploadTotal` 字节计数器。
- **双轨同步**：瞬时速率用于波形折线图，绝对字节用于总消耗统计，彻底避免漏算与偏差。

### 🌐 4. 现代 Rule-Set (SRS) 规则集分流
- **全面拥抱 SRS 架构**：采用 sing-box 官方二进制规则集（`.srs`），彻底淘汰传统臃肿的 `.db` / `.dat`。
- **CDN 高速更新**：内置国内 IP 与域名规则集更新器，支持全球 CDN 一键热更。

### 🛡️ 5. 桌面级深度集成与托盘管理 (Desktop & System Integration)
- **首次关闭弹窗确认**：首次点击 `X` 弹出托盘驻留 / 直接退出选项，支持“记住我的选择”。
- **系统托盘驻留**：托盘菜单一键启停核心、快速切换代理。
- **开机自启动 & 静默启动**：支持登录时后台静默启动至托盘。

### 🔄 6. 应用内无缝自更新 (Seamless Self-Update)
- 启动时后台静默检查 GitHub 最新 Release。
- Windows 平台支持应用内一键下载、后台安全无损热替换与自动重启。

---

## 📸 界面预览 (Screenshots)

| 仪表盘与实时波形 (Dashboard) | 节点选择与延迟测速 (Proxies) |
| :---: | :---: |
| *极速启停电源、分流策略切换、实时速率波形图* | *策略组、节点筛选、并发延迟测速* |

| 配置订阅与表单创建 (Profiles) | 活动连接与分流分析 (Connections) |
| :---: | :---: |
| *URL / 文本导入、多协议可视化表单填写* | *实时网络会话追踪、单连接关闭、域名分布分析* |

---

## 🏗️ 项目架构 (Architecture)

```text
lib/
├── app/                  # 全局主题定义 (AppTheme) 与样式常量
├── core/
│   ├── api/              # Clash REST API 与 WebSocket 实时流客户端
│   ├── engine/           # 订阅解析器 (ProfileParser) 与 sing-box 配置合成器 (ConfigGenerator)
│   ├── i18n/             # 中英双语国际化支持 (Translations)
│   ├── models/           # 数据模型 (Profile, Node, Traffic, Connection, Settings, AppUpdate)
│   ├── process/          # sing-box 进程管理与生命周期监控 (ProcessSupervisor)
│   ├── providers/        # Riverpod 响应式状态管理 (Core, Traffic, Proxies, Settings, etc.)
│   ├── services/         # 存储、自启动、系统代理、规则集更新、应用自更新服务
│   └── utils/            # 字节格式化与辅助工具
├── features/
│   ├── connections/      # 实时活动连接与流量分析面板
│   ├── dashboard/        # 仪表盘、电源中枢与实时波形监控
│   ├── logs/             # 彩色实时内核运行日志查看器
│   ├── profiles/         # 订阅管理、规则集管理与多协议手动表单
│   ├── proxies/          # 策略组管理、节点选择与并发延迟测速
│   └── settings/         # 核心端口、DNS、TUN 模式及界面显示偏好
├── shared/               # 双重晶格卡片 (DoubleBezelCard)、顶栏、状态徽标、确认弹窗
└── main.dart             # 应用主入口、窗口初始化与系统托盘注册
```

---

## 🚀 快速开始 (Getting Started)

### 环境依赖 (Prerequisites)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.13 或更高版本)
- [sing-box](https://github.com/SagerNet/sing-box) (1.10 或更高版本)

#### Linux 构建依赖 (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev
```

### 本地编译与运行 (Build & Run)

```bash
# 1. 克隆代码仓库
git clone https://github.com/leetomlee123/sb-ui.git
cd sb-ui

# 2. 获取依赖包
flutter pub get

# 3. 运行单元测试
flutter test

# 4. 开发调试模式运行
flutter run -d windows # 或 linux / macos

# 5. 构建生产发布包
flutter build windows --release
# 或
flutter build linux --release
# 或
flutter build macos --release
```

---

## 📄 开源许可证 (License)

本项目采用 [MIT License](LICENSE) 开源协议。
欢迎提交 Issue 与 Pull Request 共同完善！
