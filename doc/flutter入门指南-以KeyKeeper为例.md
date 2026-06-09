# 以 KeyKeeper 为例：Flutter 零基础入门详解

> 本文面向从未写过 Flutter 的开发者，以本仓库 **KeyKeeper**（本地密码管理器）为主线，讲解 Flutter 项目结构、核心概念与开发流程。

---

## 目录

- [一、Flutter 是什么？](#一flutter-是什么)
- [二、项目目录结构](#二项目目录结构)
- [三、依赖管理：pubspec.yaml](#三依赖管理pubspecyaml)
- [四、程序入口：main.dart](#四程序入口maindart)
- [五、核心概念：Widget](#五核心概念widget)
- [六、项目分层架构](#六项目分层架构)
- [七、数据模型与 Hive](#七数据模型与-hive)
- [八、安全设计：三层加密](#八安全设计三层加密)
- [九、页面与导航](#九页面与导航)
- [十、状态管理](#十状态管理)
- [十一、完整数据流：添加账号](#十一完整数据流添加账号)
- [十二、平台目录](#十二平台目录)
- [十三、常用开发命令](#十三常用开发命令)
- [十四、测试](#十四测试)
- [十五、如何添加新功能](#十五如何添加新功能)
- [十六、文件速查表](#十六文件速查表)
- [十七、与 Web 开发的对比](#十七与-web-开发的对比)
- [十八、学习路线建议](#十八学习路线建议)

---

## 一、Flutter 是什么？

可以把它理解成：

- **语言**：Dart（文件后缀 `.dart`）
- **框架**：用「组件（Widget）」拼出界面，一套代码可编译到 Android、iOS、Windows、Web 等
- **运行方式**：开发时支持热重载（改 UI 后快速预览）；发布时编译成各平台原生包

和 Web 前端有点像：页面由组件树组成；但 Flutter 自己画 UI，不依赖系统原生控件（外观更统一）。

---

## 二、项目目录结构

```
key_keeper/
├── lib/                    ← 核心：90% 的开发时间在这里
│   ├── main.dart           ← 程序入口
│   ├── common/             ← 常量、配置
│   ├── models/             ← 数据模型（存什么）
│   ├── services/           ← 业务逻辑（怎么处理）
│   ├── pages/              ← 整页 UI（用户看到的页面）
│   ├── widgets/            ← 可复用小组件
│   └── utils/              ← 工具函数
├── test/                   ← 测试
├── assets/                 ← 图片等资源
├── doc/                    ← 项目文档（本文所在目录）
├── android/                ← Android 原生壳（权限、图标、Activity）
├── ios/                    ← iOS 原生壳
├── windows/ linux/ macos/ web/  ← 其他平台壳
├── pubspec.yaml            ← 依赖清单（类似 package.json）
└── pubspec.lock            ← 锁定依赖版本
```

### 哪些目录需要关心？

| 目录 | 是否常改 | 说明 |
|------|----------|------|
| `lib/` | ✅ 几乎每天 | 业务代码、UI |
| `pubspec.yaml` | 偶尔 | 加依赖、加资源时 |
| `android/`、`ios/` | 偶尔 | 权限、签名、原生能力 |
| `build/` | ❌ 不要管 | 编译产物，不提交 Git |

---

## 三、依赖管理：pubspec.yaml

`pubspec.yaml` 是项目的「购物清单」：

```yaml
dependencies:
  flutter:
    sdk: flutter
  hive: ^2.2.3           # 本地数据库
  local_auth: ^2.1.6     # 指纹/Face ID
  go_router: ^12.1.0     # 路由
  ...

dev_dependencies:
  flutter_test: ...      # 仅开发/测试用
  hive_generator: ...    # 代码生成
```

### 关键概念

| 概念 | 说明 |
|------|------|
| `dependencies` | 正式运行 App 需要的包 |
| `dev_dependencies` | 开发、测试、代码生成用，不打进正式包 |
| `^2.2.3` | 允许兼容的小版本升级，具体版本由 `pubspec.lock` 锁定 |
| `flutter pub get` | 按清单下载依赖到本机缓存 |

### 依赖存放在哪里？

依赖**不会**放在项目文件夹里，而是下载到本机全局缓存：

```
C:\Users\<用户名>\AppData\Local\Pub\Cache\hosted\pub.dev\
```

项目里只保留 `pubspec.yaml`（声明）和 `pubspec.lock`（锁定版本），会提交到 Git。

换一台电脑克隆项目后，需要重新执行 `flutter pub get`。

### KeyKeeper 主要依赖

| 包 | 用途 |
|----|------|
| `hive` / `hive_flutter` | 本地加密数据库，存账号 |
| `flutter_secure_storage` | 系统安全区存密钥 |
| `local_auth` | 生物识别解锁 |
| `encrypt` / `crypto` | AES 加密、PBKDF2 |
| `otp` | TOTP 动态验证码 |
| `go_router` | 页面路由 `/unlock`、`/home` |
| `flutter_slidable` | 列表左滑删除 |
| `csv` / `file_picker` / `share_plus` | 导入导出 |

---

## 四、程序入口：main.dart

所有 Flutter App 都从 `main()` 启动：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // 异步初始化前必须调用
  await Hive.initFlutter();                   // 初始化数据库
  Hive.registerAdapter(AccountEntryAdapter());

  // 创建全局 Service
  appCryptoService = CryptoService();
  appKeyService = KeyService(secureStorage, appCryptoService);
  final hiveKey = await appKeyService.ensureHiveKey();
  final box = await Hive.openBox<AccountEntry>(...);  // 打开加密数据库

  appAccountService = AccountService(box, ...);
  appTotpService = TotpService();
  appCsvService = CsvService(...);

  runApp(const MyApp());  // 启动 UI
}
```

### 启动流程

```
main()
  → 初始化 Flutter 引擎
  → 初始化 Hive 数据库
  → 创建各种 Service
  → 打开加密 Box
  → runApp() 启动界面
  → 显示解锁页 /unlock
```

要点：

- `async/await`：数据库、读密钥都是异步，必须 `await`
- `WidgetsFlutterBinding.ensureInitialized()`：在 `runApp` 前做异步初始化时必加
- `runApp()`：把根组件挂到屏幕上，之后由 Flutter 负责刷新 UI

---

## 五、核心概念：Widget

**一切皆 Widget。** 按钮、文字、整页、布局都是 Widget。

### StatelessWidget — 无内部可变状态

```dart
class MyTitle extends StatelessWidget {
  const MyTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Hello');
  }
}
```

### StatefulWidget — 有可变状态

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => setState(() => count++),  // 改状态 → 触发重绘
      child: Text('$count'),
    );
  }
}
```

`setState()` 告诉 Flutter：「数据变了，请重新执行 `build()` 刷新界面」。

KeyKeeper 里几乎所有页面都是 `StatefulWidget`：`UnlockPage`、`HomePage`、`AccountListPage` 等。

### 常见 UI 组件

| Widget | 作用 |
|--------|------|
| `Scaffold` | 页面骨架：AppBar、body、底部导航 |
| `AppBar` | 顶部标题栏 |
| `ListView` | 可滚动列表 |
| `TextField` | 输入框 |
| `ElevatedButton` / `TextButton` | 按钮 |
| `SnackBar` | 底部短暂提示 |
| `AlertDialog` | 弹窗 |
| `NavigationBar` | 底部 Tab（账号 / 我的） |

---

## 六、项目分层架构

```
┌─────────────────────────────────────────┐
│  UI 层（pages / widgets）               │
│  unlock_page / home_page / mine_page   │
└─────────────────┬───────────────────────┘
                  │ 调用
┌─────────────────▼───────────────────────┐
│  业务层（services）                      │
│  AccountService / KeyService / ...      │
└─────────────────┬───────────────────────┘
                  │ 读写
┌─────────────────▼───────────────────────┐
│  数据层（models + 存储）                 │
│  AccountEntry + Hive + Secure Storage   │
└─────────────────────────────────────────┘
```

### 各层职责

| 层 | 目录 | 职责 | 举例 |
|----|------|------|------|
| **Model** | `lib/models/` | 数据结构 | `AccountEntry`：类型、用户名、密码、TOTP |
| **Service** | `lib/services/` | 业务逻辑，不画 UI | `addAccount()`、`encrypt()` |
| **Page** | `lib/pages/` | 整页界面 + 用户交互 | 解锁、列表、设置 |
| **Widget** | `lib/widgets/` | 可复用 UI 块 | 删除确认框、TOTP 显示 |
| **Common** | `lib/common/` | 常量 | 数据库名、解锁方式枚举 |

**原则：Page 尽量薄，复杂逻辑放 Service。** 这样以后换 UI 或写测试都更容易。

### lib/ 文件一览

```
lib/
├── main.dart                      # 入口、全局 Service、路由、生命周期锁屏
├── common/constants.dart          # 常量、类型预设、图标映射
├── models/
│   └── account_entry.dart         # Hive 账号模型 (typeId: 1)
├── services/
│   ├── crypto_service.dart        # AES 字段加密
│   ├── key_service.dart           # Secure Storage 密钥管理
│   ├── account_service.dart       # Hive CRUD + 重加密
│   ├── totp_service.dart          # TOTP 生成
│   ├── totp_ticker.dart           # 全局 TOTP 倒计时
│   └── csv_service.dart           # 导入导出
├── pages/
│   ├── unlock_page.dart           # 生物识别 / 主密码解锁
│   ├── home_page.dart             # 主页（底部 Tab）
│   ├── account_list_page.dart     # 账号列表
│   ├── account_detail_page.dart   # 账号详情 / 新增 / 编辑
│   └── mine_page.dart             # 我的（设置、导入导出）
├── widgets/
│   ├── account_icon.dart          # 账号类型图标
│   ├── confirm_delete_dialog.dart # 删除确认弹窗
│   ├── private_key_dialog.dart    # 个人密钥设置/查看
│   ├── sensitive_action_gate.dart # 敏感操作二次验证
│   └── totp_display.dart          # TOTP 列表/详情展示
└── utils/
    ├── pbkdf2.dart                # 主密码派生
    └── secure_compare.dart        # 恒定时间字符串比较
```

---

## 七、数据模型与 Hive

```dart
@HiveType(typeId: 1)
class AccountEntry extends HiveObject {
  @HiveField(0) String typeText;         // 如 GitHub
  @HiveField(1) String username;
  @HiveField(2) String? passwordSecret;  // 加密后的密码
  @HiveField(3) String? totpSecret;      // 加密后的 TOTP 密钥
  @HiveField(4) int updateTime;
}
```

- `@HiveType` / `@HiveField`：告诉 Hive 怎么序列化到磁盘
- `account_entry.g.dart`：由 `build_runner` **自动生成**，不要手改
- 改模型后要执行：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Hive 在本项目中是 **整库 AES 加密** 的本地数据库，类似一个加密过的 NoSQL 文件。

---

## 八、安全设计：三层加密

KeyKeeper 有三套不同的「钥匙」，务必分开理解：

```
┌──────────────────────────────────────────────────────┐
│  第一层：解锁 App                                     │
│  生物识别 / 主密码（PBKDF2 哈希存 Secure Storage）    │
└────────────────────────┬─────────────────────────────┘
                         │ 通过后才能使用 App
┌────────────────────────▼─────────────────────────────┐
│  第二层：整库加密                                     │
│  Hive AES 密钥（32 字节，存 Secure Storage）          │
└────────────────────────┬─────────────────────────────┘
                         │ 打开加密数据库文件
┌────────────────────────▼─────────────────────────────┐
│  第三层：字段加密                                     │
│  个人密钥 → AES-256-GCM 加密 password / totp 字段    │
└──────────────────────────────────────────────────────┘
```

| 凭据 | 存在哪 | 用来干什么 |
|------|--------|------------|
| **主密码** | Secure Storage（PBKDF2 哈希） | 仅解锁 App |
| **Hive 密钥** | Secure Storage | 加密整个数据库文件 |
| **个人密钥** | Secure Storage（再加密存放） | 加密每条账号的密码、TOTP |

对应代码：

- `KeyService`：管主密码、个人密钥、Hive 密钥
- `CryptoService`：AES-256-GCM 加解密字段（兼容旧 CBC 格式并自动迁移）
- `AccountService`：读写账号时调用加解密

### 其他安全特性

- 后台恢复时叠加解锁页（保留编辑状态）
- 进入后台时显示模糊遮罩（防任务切换预览泄露）
- Android `FLAG_SECURE`（禁止截屏/录屏）
- 查看个人密钥、明文导出前需二次身份验证

---

## 九、页面与导航

### 主路由（go_router）

```dart
routes: [
  GoRoute(path: '/unlock', builder: ... UnlockPage),
  GoRoute(path: '/home',   builder: ... HomePage),
]
```

- 冷启动：先到 `/unlock` 解锁
- 解锁成功：`context.go('/home')` 进主页

### 叠加路由（Navigator.push）

详情页、编辑页使用：

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => AccountDetailPage(...),
));
```

**为什么混用两种路由？**

从后台恢复时要 **叠加** 解锁页，而不是清掉编辑页。`main.dart` 里用 `Navigator.push` 保留编辑状态，这是有意设计。

### 主页结构（HomePage）

```
HomePage
├── AppBar（搜索、添加按钮）
├── IndexedStack
│   ├── Tab 0: AccountListPage（账号列表）
│   └── Tab 1: MinePage（我的 / 设置）
└── NavigationBar（底部切换）
```

`IndexedStack`：两个 Tab 都保留在内存里，切换不销毁，列表不用每次重载。

---

## 十、状态管理

大型项目常用 Provider / Riverpod / Bloc；KeyKeeper 目前用 **轻量方案**：

| 手段 | 用在哪 | 作用 |
|------|--------|------|
| `setState()` | 各页面内部 | 刷新当前页 UI |
| `ValueNotifier` | `HomePage` 搜索词、列表刷新 | 跨组件通知 |
| `AccountService.dataRevision` | 导入/删除后 | 通知列表重拉数据 |
| 全局 Service | `main.dart` 里 `appXxxService` | 共享业务对象 |

例如列表刷新：

```dart
// 导入完成后
widget.listBump?.value++;  // 通知列表页
// 或 AccountService 内部 dataRevision++
```

以后项目变大，可以考虑迁到 **Riverpod**，但当前规模够用。

---

## 十一、完整数据流：添加账号

以用户点击 `+` 新增账号为例：

```
用户点击 +
  → HomePage 检查个人密钥是否已设置
  → Navigator.push 打开 AccountDetailPage
  → 用户填写并保存
  → AccountDetailPage 调用 accountService.addAccount()
      → getUserKey() 获取个人密钥
      → cryptoService.encrypt() 加密密码/TOTP
      → Hive box.add() 写入数据库
      → dataRevision++ 通知变更
  → Navigator.pop(true) 返回
  → HomePage listBump++ 刷新列表
```

你在 `account_detail_page.dart` 里主要写 UI 和校验；真正存盘在 `account_service.dart`。

---

## 十二、平台目录

Flutter 是跨平台的，但某些能力必须配原生：

| 需求 | 改哪里 |
|------|--------|
| Android 指纹权限 | `android/app/src/main/AndroidManifest.xml` |
| 禁止截屏 | `android/.../MainActivity.kt` 里 `FLAG_SECURE` |
| 禁止系统备份 | `AndroidManifest.xml` 的 `allowBackup="false"` |
| iOS Face ID 说明 | `ios/Runner/Info.plist` 的 `NSFaceIDUsageDescription` |
| 应用图标 | `assets/images/app_icon.png` + `flutter_launcher_icons` |
| 包名 / 签名 | `android/app/build.gradle.kts`、`key.properties` |

日常改 UI、业务逻辑 **只动 `lib/`** 即可；只有权限、签名、特殊原生行为才动 `android/`、`ios/`。

---

## 十三、常用开发命令

```bash
# 1. 克隆/打开项目后，先拉依赖
flutter pub get

# 2. 看有哪些设备（手机模拟器、Windows 桌面等）
flutter devices

# 3. 运行（开发模式，支持热重载）
flutter run

# 4. 指定设备
flutter run -d windows
flutter run -d <设备ID>

# 5. 静态检查
flutter analyze

# 6. 跑测试
flutter test

# 7. 改 Hive 模型后生成代码
flutter pub run build_runner build --delete-conflicting-outputs

# 8. 打 Android release 包
flutter build apk --release
```

### 热重载 vs 完全重启

| 情况 | 怎么做 |
|------|--------|
| 改了 Dart UI | 热重载（终端按 `r`）通常够用 |
| 改了 `pubspec.yaml`、原生代码、资源 | 必须 **停止后重新 `flutter run`** |
| 加了带原生代码的插件（如 `share_plus`） | 同上，热重载不够 |

---

## 十四、测试

```
test/
├── services/
│   ├── crypto_service_test.dart   # 加解密是否正确
│   └── totp_service_test.dart     # TOTP 格式校验
├── utils/
│   └── pbkdf2_test.dart           # 密码派生
└── widget_test.dart               # 小组件能否正常显示
```

运行全部测试：

```bash
flutter test
```

| 测试类型 | 说明 |
|----------|------|
| 单元测试 | 直接调 Service，不启动完整 App |
| Widget 测试 | 模拟点击、查找文字，验证 UI 组件 |

---

## 十五、如何添加新功能

假设要加「复制密码到剪贴板」：

1. **想清楚数据从哪来**  
   密码在 `AccountService.getAccount()` 解密后的 `passwordSecret`

2. **逻辑放 Service 还是 Page？**  
   复制是 UI 行为 → 放 `account_detail_page.dart`  
   若涉及安全策略 → 可先调 `sensitive_action_gate.dart` 做二次验证

3. **改 Page UI**  
   在详情页加 `IconButton`，调用 `Clipboard.setData(...)`

4. **需要新依赖吗？**  
   剪贴板用 `package:flutter/services.dart` 自带，不用加包

5. **验证**  
   ```bash
   flutter analyze
   flutter test
   ```

6. **涉及持久化？**  
   - 改 `models/` → 跑 `build_runner`
   - 改 `account_service.dart` 的存取逻辑

---

## 十六、文件速查表

| 想了解… | 打开这个文件 |
|---------|--------------|
| App 怎么启动 | `lib/main.dart` |
| 怎么解锁 | `lib/pages/unlock_page.dart` |
| 账号列表 | `lib/pages/account_list_page.dart` |
| 新增/编辑账号 | `lib/pages/account_detail_page.dart` |
| 设置、导入导出 | `lib/pages/mine_page.dart` |
| 账号增删改查 | `lib/services/account_service.dart` |
| 加密算法 | `lib/services/crypto_service.dart` |
| 密钥与主密码 | `lib/services/key_service.dart` |
| 数据结构 | `lib/models/account_entry.dart` |
| 常量 | `lib/common/constants.dart` |
| 依赖列表 | `pubspec.yaml` |
| 用户使用说明 | `README.md` |

---

## 十七、与 Web 开发的对比

| 概念 | Web | Flutter (本项目) |
|------|-----|----------------|
| 包管理 | npm + package.json | pub + pubspec.yaml |
| 组件 | React/Vue 组件 | Widget |
| 路由 | Vue Router | go_router + Navigator |
| 本地存储 | localStorage | Hive + Secure Storage |
| API 请求 | fetch/axios | 本项目无网络，纯离线 |
| 状态管理 | Redux/Pinia | setState + ValueNotifier |

---

## 十八、学习路线建议

| 阶段 | 目标 |
|------|------|
| 第 1 周 | 跑通 `flutter run`，改 `unlock_page.dart` 里一行文字，体验热重载 |
| 第 2 周 | 读 `home_page` → `account_list_page`，理解 `ListView`、`StatefulWidget` |
| 第 3 周 | 读 `account_service`，理解 async 和分层 |
| 第 4 周 | 试着加一个小功能（如复制用户名到剪贴板） |
| 之后 | 学 Hive 代码生成、测试、Android 打包发布 |

---

## 延伸阅读

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言教程](https://dart.dev/guides)
- [Hive 文档](https://docs.hivedb.dev/)
- 项目内 `README.md`：面向最终用户的使用说明
- 项目内 `CLAUDE.md`：面向 AI 辅助开发的架构说明
