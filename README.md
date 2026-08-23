# sing-box UI (Flutter Desktop Client)

A modern, high-performance, cross-platform desktop GUI client for **sing-box** built with Flutter Desktop (supporting Windows, macOS, and Linux).

---

## 🌟 Key Features

- **⚡ Core Lifecycle Management**: Seamless start/stop/restart and real-time health monitoring of the `sing-box` binary.
- **📊 Real-time Dashboard**:
  - Live animated upload/download traffic chart using `fl_chart`.
  - Session statistics: Uptime, Total Download/Upload bytes, Current transfer rates.
  - Quick mode toggle: **Rule**, **Global**, **Direct**.
- **🌐 Proxies & Strategy Groups**:
  - Strategy groups view (Proxy, Auto URL-Test, Fallback, etc.).
  - Batch concurrent latency testing (URL delay check).
  - Node filtering and search with protocol badges (Shadowsocks, VMess, VLESS, Trojan, Hysteria 2, TUIC, WireGuard).
- **📂 Subscriptions & Profile Engine**:
  - Remote subscription auto-download & parsing (sing-box JSON, Clash YAML, and Base64 URI formats).
  - Config synthesizer: automatically merges inbounds, remote rule-sets (SRS geoip/geosite), DNS, and experimental Clash API endpoints.
  - Built-in full-text configuration editor.
- **🔍 Active Connections Inspector**:
  - Real-time connection list with matched routing rules, destination host/IP, chains, and traffic metrics.
  - Single connection termination and one-click "Close All".
- **📝 Live Color-coded Logs**:
  - Process stdout/stderr and WebSocket stream logging with level filtering (Trace/Debug/Info/Warn/Error), search, and copy-all.
- **🖥️ Desktop Integration**:
  - Custom frameless title bar with minimize, maximize, and close controls.
  - System tray icon with quick connect/disconnect menu and close-to-tray support.
  - System proxy (HTTP/SOCKS5) and TUN mode configuration support.

---

## 🏗️ Architecture

```text
lib/
├── app/                  # Theme definition and constants
├── core/
│   ├── api/              # Clash REST API & WebSocket client
│   ├── engine/           # Subscription parser & sing-box config synthesizer
│   ├── models/           # Data models (Node, Group, Traffic, Log, Profile, Settings)
│   ├── process/          # sing-box process supervisor & config validator
│   ├── providers/        # Riverpod state notifiers & reactive streams
│   ├── services/         # Storage and System Proxy management
│   └── utils/            # Byte and duration formatters
├── features/
│   ├── connections/      # Active connections monitor
│   ├── dashboard/        # Main dashboard & live traffic chart
│   ├── logs/             # Live console logs viewer
│   ├── profiles/         # Subscriptions & config profiles management
│   ├── proxies/          # Strategy groups & proxy nodes view
│   ├── settings/         # Core, port, DNS, and app preferences
│   └── shell/            # Desktop shell layout (NavigationRail + TitleBar)
├── shared/               # Reusable UI widgets
└── main.dart             # Application entrypoint & tray setup
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.13+)
- [sing-box](https://github.com/SagerNet/sing-box) (1.10+)

#### Linux Build Requirements
```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev
```

### Build & Run

```bash
# Get dependencies
flutter pub get

# Run tests
flutter test

# Run application
flutter run -d linux # or windows / macos

# Build release bundle
flutter build linux --release
# or
flutter build windows --release
# or
flutter build macos --release
```
