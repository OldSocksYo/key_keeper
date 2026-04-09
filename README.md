# KeyKeeper 用户使用说明

KeyKeeper 是一款本地离线密码管理应用，可用于保存账号密码和 2FA 动态验证码（TOTP）。

## 能做什么

- 保存常见账号信息（平台、用户名、密码）
- 保存并使用 TOTP 动态码（如 GitHub 双重验证）
- 支持两种解锁方式：
  - 生物识别
  - 主密码
- 支持账号导入导出（加密/明文）

## 首次使用（建议按顺序）

### 1. 进入应用并解锁

- 如果你选择了生物识别：按系统提示验证
- 如果你选择了主密码：首次需要先设置主密码

### 2. 设置个人密钥

在 `我的 -> 设置个人密钥` 中设置。  
个人密钥用于应用内数据加密，建议设置后再录入账号。

### 3. 添加账号

进入 `账号` 页，点击右上角 `+`，填写：

- 账户类型（例如 GitHub、Google）
- 用户名
- 登录密码（可选）
- TOTP 密钥（可选）

保存后会出现在账号列表中。

## 日常使用

### 查看/编辑账号

在 `账号` 页点击任意账号进入详情，可编辑密码和 TOTP 密钥。

### 查看 TOTP 动态码

在账号详情页中可看到实时验证码和倒计时（每 30 秒刷新）。

### 删除账号

在 `账号` 页将列表项左滑，点击删除并确认。

### 搜索账号

在 `账号` 页点击右上角搜索图标，按类型或用户名筛选。

## 解锁方式切换

进入 `我的 -> 解锁方式`，可以在以下两种方式中切换：

- 生物识别
- 主密码

切换后通常在下次进入解锁页生效。

## 导入导出说明

在 `我的` 页可以使用：

- 加密导出
- 加密导入
- 明文导出
- 明文导入

当前 CSV 格式为：

`typeText,username,password,totpSecret`

## 本地签名配置说明（Android）

用于本地打包 release APK，请按以下步骤配置；**不要把密钥文件和真实密码提交到仓库**。

### 1. 生成签名文件（仅本地）

在项目根目录执行：

```bash
keytool -genkeypair -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

按提示设置：

- 密钥库口令（storePassword）
- 密钥口令（keyPassword）
- 别名（alias，建议使用 `upload`）

### 2. 按模板创建真实配置

复制 `android/key.properties.example` 为 `android/key.properties`，并填写你本机的真实值：

```properties
storePassword=你的密钥库口令
keyPassword=你的密钥口令
keyAlias=upload
storeFile=upload-keystore.jks
```

说明：`storeFile` 可写相对路径；若 keystore 在 `android/` 目录下，直接写文件名即可。

### 3. 安全要求（务必遵守）

- 不要提交 `android/key.properties`
- 不要提交任何 `.jks` / `.keystore` 文件
- `key.properties.example` 仅作模板，可提交

### 4. 打包命令

在项目根目录执行：

```bash
flutter clean
flutter pub get
flutter build apk --release
```

输出文件：

`build/app/outputs/flutter-apk/app-release.apk`

### 快速清单（首次克隆后 3 分钟）

1. 复制模板：`android/key.properties.example` -> `android/key.properties`
2. 生成签名：执行 `keytool` 命令生成 `android/upload-keystore.jks`
3. 填写配置：在 `android/key.properties` 填入 `storePassword/keyPassword/keyAlias/storeFile`
4. 自检安全：确认 `android/key.properties` 与 `.jks` 文件未加入 Git 暂存区
5. 开始打包：执行 `flutter build apk --release`

## 常见问题

### 设备不支持生物识别怎么办？

到 `我的 -> 解锁方式` 切换为 `主密码`，然后使用主密码解锁。

### 忘记主密码怎么办？

当前版本没有找回主密码功能，请务必妥善保管。

### 数据会上传到云端吗？

不会。当前版本数据仅保存在本机。
