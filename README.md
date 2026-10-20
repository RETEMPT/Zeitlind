# Zeitlind

一个以 Android 为主的漫画阅读器。管理本地书库，连接漫画源，按自己的节奏阅读。

[下载 Android 安装包](https://github.com/RETEMPT/Zeitlind/releases/latest) · [全部版本](https://github.com/RETEMPT/Zeitlind/releases)

<img src="screenshots/home.png" width="300" alt="Zeitlind 首页" />

## 功能

- 本地漫画导入、收藏、历史与继续阅读。
- JavaScript 漫画源、聚合搜索、章节下载与离线阅读。
- 源目录搜索与筛选，支持 Komga、Kavita 等自建书库适配。
- 源链接自检、GitHub 链接转换、已知镜像重试和更新失败回滚。
- 标准、日漫、条漫阅读预设及细项设置。
- 深浅模式，主色、色相、饱和度和背景染色调节。
- 可选 WebDAV 同步与备份导入导出。

## 安装

在 [Releases](https://github.com/RETEMPT/Zeitlind/releases) 下载 APK：

| 安装包 | 适用设备 |
| --- | --- |
| `arm64-v8a` | 大多数近年的安卓手机，优先选择 |
| 不带架构后缀的通用包 | 不确定设备架构时使用 |
| `armeabi-v7a` | 32 位 ARM 设备 |
| `x86_64` | 对应架构的模拟器或设备 |

下载页面附带 `SHA256SUMS` 和公开签名证书。后续版本使用同一签名以支持覆盖更新。

## 漫画源

首页 → 漫画源 → 漫画源目录，选择需要的源并安装；也可填写链接或导入 `.js` 文件。

默认目录可切换 CDN 与 GitHub 直连。安装后可运行“漫画源自检”。自检检查脚本链接与源标识；登录、搜索和具体章节阅读仍取决于站点状态。只安装信任的源。

应用不捆绑漫画内容或远程源脚本。自建书库需要填写自己的服务器地址和账号。

## 数据迁移

Zeitlind 使用独立应用标识 `dev.zeitlind.reader`，可以与原版同时安装。设置中支持导入旧 `.venera` 备份；新备份使用 `.zeitlind`，WebDAV 只轮换 Zeitlind 备份。

## 从源码构建

使用 Flutter **3.41.4**、Android SDK、JDK 17 和 Rust。调试构建不需要发布密钥：

```sh
flutter pub get
flutter test
flutter build apk --debug
```

正式发布需配置自己的 `android/key.properties` 与签名密钥。构建脚本、依赖版本和测试随源码提供；开发笔记与内部验证报告保存在本地。

## 许可

GNU GPL v3，见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。Zeitlind 是独立修改版，原有版权和第三方许可声明保留。
