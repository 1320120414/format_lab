<div align="center">

# 格式坊 · FormatLab

**本地离线的图片 / 音频 / 视频格式转换工具**

所有转换都在你自己的设备上完成，文件不上传、不联网、不留副本。

![platform](https://img.shields.io/badge/platform-Android%2010%2B%20%7C%20Windows-2ea44f)
![flutter](https://img.shields.io/badge/Flutter-3.13%2B-02569B?logo=flutter&logoColor=white)
![license](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## 这是什么

格式坊是一个用 Flutter 写的格式转换工具，支持 Android 与 Windows 桌面端。图片走原生编码器（Android 上直接调用系统 HEIC 解码），音视频走 FFmpeg，动图转 GIF 则用纯 Dart 在后台 isolate 里逐帧重编码。

设计上只有一条硬性约束：**不联网**。没有账号、没有上传、没有埋点，转换结果直接落到系统相册（移动端）或媒体库目录（桌面端）。

---

## 功能

### 图片

| 能力 | 说明 |
| --- | --- |
| 格式互转 | HEIC / JPG / PNG / WEBP / BMP / GIF |
| 批量转换 | 一次可选多张，统一应用同一套参数 |
| 自定义尺寸 | 可分别限定宽高，默认锁定原图比例；只填一边会自动推算另一边 |
| 画质调节 | JPG / WEBP 支持质量参数（0–100） |
| 动图转 GIF | GIF / 动态 WebP / APNG 均可重新编码为 GIF |
| 实况照片 | 识别 Motion Photo 尾部追加的 MP4，可抽帧转 GIF |
| 自动归档 | 结果按设置写入 `Pictures/<目录>` |

> Android 10 起系统原生支持 HEIC 解码，这也是本项目最低版本定为 Android 10 的原因。

### 音频

- **格式互转**：MP3 / M4A / WAV / AAC / OGG
- **码率可调**：除 WAV 外均支持指定码率
- **音轨提取**：可直接从视频文件中抽出音频

### 视频

| 模式 | 说明 |
| --- | --- |
| 压缩 | 三档预设——高质量（CRF 20）、均衡（CRF 24）、小体积（CRF 29） |
| 分辨率 | 原分辨率 / 1080p / 720p / 480p（按长边等比缩放） |
| 转封装 | MP4 / MKV / MOV 之间切换，`-c copy` 不重编码、不损画质 |
| 提取音频 | 从视频中导出音轨为独立音频文件 |

### 其他

- **任务队列**：串行执行，避免多任务抢 CPU 与内存；实时进度、失败原因、完成后可直接跳转预览
- **历史记录**：转换记录持久化，重启后仍在
- **分享**：移动端调用系统分享面板，桌面端在资源管理器中定位文件
- **外观**：跟随系统 / 浅色 / 深色；可开关「液态玻璃」毛玻璃效果（关掉退化为纯色卡片，低端机更流畅）
- **输出目录**：可自定义子目录名，自动过滤非法字符

---

## 截图

> 待补充。运行应用后把截图放到 `docs/screenshots/` 并在此引用即可。

---

## 技术栈

| 层 | 选型 |
| --- | --- |
| 框架 | Flutter（Dart SDK ^3.13.5） |
| 状态管理 | Riverpod |
| 音视频引擎 | Android：`ffmpeg_kit_flutter_new`；桌面：内置 `ffmpeg.exe` 子进程 |
| 动图编解码 | `image` 包，在后台 isolate 中执行 |
| 图片编码 | 原生平台通道（Android 走系统编解码，含 HEIC） |
| 视频预览 | `video_player` / `video_player_win` |
| 音频播放 | `just_audio` + `audio_session` |
| 文件选择 | `file_picker` |
| UI 质感 | `liquid_glass_widgets`（真实背景采样、模糊与高光） |

### 项目结构

```
lib/
├── application/        # 全局状态：任务队列、设置控制器
├── core/               # 主题、通用组件、玻璃控件封装、工具函数
├── domain/             # 领域模型：格式枚举、TaskSpec 密封类、ConvertTask
├── features/           # 页面：home / image / audio / video / tasks / settings / preview / shell
└── infrastructure/     # 引擎与存储：ffmpeg、image、animation、motion_photo、settings、paths
```

几个值得一提的设计：

- **`TaskSpec` 用密封类**分流图片 / 音频 / 视频 / 提取音频 / 转封装，队列按类型路由到不同引擎，新增任务类型时编译器会强制你补全分支。
- **FFmpeg 命令由纯函数拼装**（`planFor`），不依赖运行时状态，因此可以脱离设备写单元测试。
- **实况照片不解析 XMP**：新旧规范里 `MicroVideoOffset` 的写法不一致，改为从文件尾部倒着找最后一个 `ftyp` 盒子，两种规范都能覆盖。
- **动图编码在 isolate 中执行**，大尺寸 GIF 也不会卡住界面。

---

## 开始使用

### 直接安装（Android）

前往 [Releases](https://github.com/1320120414/format_lab/releases) 下载最新的 `format-lab-*.apk` 安装。

要求 **Android 10（API 29）及以上**。

> Release APK 目前使用 debug 签名，仅供测试安装。若要上架或长期分发，请自行配置正式签名。

### 从源码运行

前置：Flutter SDK 3.13+，Android 需 Android SDK 29+；Windows 需 Visual Studio 2022（含 C++ 桌面开发）。

```bash
git clone https://github.com/1320120414/format_lab.git
cd format_lab
flutter pub get
```

**Android**

```bash
flutter run -d android
# 打包
flutter build apk --release
```

**Windows**

```bash
flutter run -d windows
# 打包
flutter build windows --release
```

Windows 端需要 `ffmpeg.exe`（**不随仓库分发**，单文件约 100 MB，超过 GitHub 的单文件上限）。放到 `windows/bin/ffmpeg.exe` 即可，构建时会自动复制到可执行文件旁边。

程序运行时的查找顺序：

1. 环境变量 `FORMATLAB_FFMPEG` 指定的完整路径
2. 应用目录下的 `ffmpeg.exe`
3. 应用目录下的 `bin/ffmpeg.exe`
4. 系统 `PATH` 中的 `ffmpeg`

FFmpeg 可从 [ffmpeg.org/download.html](https://ffmpeg.org/download.html) 获取 Windows 静态构建。若 `windows/bin/ffmpeg.exe` 不存在，构建不会失败，只是 Windows 端的音视频转换会提示找不到引擎。

### 运行测试

```bash
flutter test
```

现有测试覆盖 FFmpeg 参数拼装、GIF 编码、实况照片识别与基础组件。

---

## 已知限制

- **Release APK 为 debug 签名**，不适合正式分发。
- **iOS 未启用**（`pubspec.yaml` 中 `ios: false`），当前只面向 Android 与 Windows。
- **Android 仅保留 arm64-v8a**：FFmpeg 的 `.so` 预编译在 AAR 里，无法通过 `abiFilters` 裁剪，只能在打包阶段排除其他 ABI，因此不支持 32 位设备。
- **实况照片转 GIF 依赖文件尾部结构**，极少数经过二次编辑的工具处理过的文件可能识别失败。
- 视频压缩的 FOV / 分辨率参数由预设固定，暂不支持逐项微调。

---

## 隐私

- 无网络请求，无账号体系，无统计埋点。
- 所有文件读取与写出均在本机完成，转换产物写入你指定的目录。
- 应用不申请网络权限之外的敏感权限；Android 10+ 通过 MediaStore 写入相册，无需存储权限。

---

## 贡献

欢迎提 Issue 与 PR。提交前请确保：

```bash
flutter analyze
flutter test
```

均通过。

---

## 许可证

[MIT](LICENSE)

---

<div align="center">
<sub>格式坊 · 把格式转换留在本地</sub>
</div>
