# WaterMark 设计框架

## 一、整体概览

- Flutter 跨平台桌面/移动应用，当前以 macOS 使用场景为主
- 核心能力：读取图片 EXIF 元数据，自动/手动配置水印样式并导出成新图片
- 架构思路：以页面为导向的 UI 层 + 状态与配置层 + 渲染合成层 + 工具与持久化层

## 二、启动与路由结构

- `lib/main.dart`：应用入口，调用 `runApp(const WaterMarkApp())`
- `lib/app.dart`：
  - 封装 `MaterialApp`，配置主题、颜色方案等
  - `home: EntryScreen()`，统一从入口页开始
- 路由采用 `Navigator.push(MaterialPageRoute)` 直连页面：
  - `EntryScreen  →  TypeSelectScreen  →  EditorScreen`

## 三、页面（UI）层

### 1. EntryScreen（图片入口）

- 负责图片选取与拖放：
  - 使用 `desktop_drop` 支持拖拽文件
  - 使用 `file_picker` 进行对话框多选
- 支持格式：`JPEG/PNG/HEIC/TIFF` 等
- 当存在有效文件时，进入 `TypeSelectScreen(files: files)`

### 2. TypeSelectScreen（水印类型选择）

- 职责：选择当前处理的水印类型，并加载用户偏好
- 主要逻辑：
  - 通过 `AppPrefs.load()` 读取上次保存的水印配置
  - 当前实现类型：
    - `WatermarkType.exif`：EXIF 信息水印
    - 预留“占位类型”卡片，方便未来扩展
- 选中 EXIF 类型后跳转：
  - `EditorScreen(files: files, type: WatermarkType.exif, initialPrefs: prefs)`

### 3. EditorScreen（水印编辑与导出）

- 采用 `StatefulWidget` 管理当前图片与水印配置状态
- 关键状态：
  - 当前图片索引 `index` 与 `files`
  - 原图字节 `imageBytes` 与解码后的 `uiImage`
  - 当前图片 EXIF 映射 `exifMap`
  - 水印配置：
    - `bgHeightPercent`：底部背景区域高度占原图高度的比例
    - `fontFamily` / `fontSize` / `fontColor` / `alignment`：文字样式
    - `opacity`：白色背景透明度
    - `exifKeys`：参与展示的 EXIF 字段列表
    - `author`：作者署名
    - `logoImage` / `logoPath` / `logoHeightFactor` / `logoWidthFactor`：品牌 Logo 或自定义 Logo 配置
- 初始化流程：
  - 使用 `initialPrefs` 初始化所有配置
  - 根据图片 EXIF 中的 `Make` 自动识别品牌（SONY/CANON/NIKON）并加载内置 Logo
  - 按图片宽度动态计算字体大小范围，并限制在合理区间内
- 预览区域：
  - 左侧使用 `CustomPaint` + `PreviewPainter` 实时预览水印叠加效果
  - 右侧配置面板通过滑块、下拉框、输入框等控制所有参数
- 导出逻辑：
  - 支持导出 PNG 或 JPEG
  - PNG：直接从合成后的 `ui.Image` 导出 PNG 字节并保存
  - JPEG：
    - 从合成结果导出 RGBA，使用 `image` 包编码为 JPEG
    - 若原图包含 EXIF，则尝试使用 `injectJpgExif` 将原始 EXIF 注入新 JPEG
  - 导出路径由 `file_selector` 的 `getSaveLocation` 决定
- 用户体验：
  - 底部 `BottomAppBar` 控制上一张/下一张图片，以及保存当前水印设置到本地偏好

## 四、状态与配置层

### 1. AppPrefs（偏好设置服务）

- 文件：`lib/services/prefs.dart`
- 底层依赖：`shared_preferences`
- 负责持久化以下配置：
  - 背景高度比例、字体家族、字体大小、字体颜色
  - 文本对齐方式、背景透明度
  - EXIF 字段列表、作者名称
  - Logo 路径、Logo 高度比例
- 设计要点：
  - 使用常量 key 管理 `SharedPreferences` 字段名，避免硬编码
  - 使用 `Color.toARGB32()` 与 `Color(int)` 在 int 与 Color 之间转换
  - `TextAlign` 通过枚举 `name` 序列化
  - 提供默认值，保证首次打开也有合理配置

### 2. 页面内部状态

- EditorScreen 将偏好加载为初始状态，然后允许用户针对当前会话微调
- 所有滑块、颜色选择、下拉框均通过 `setState` 即时更新预览

## 五、渲染合成层

### 1. PreviewPainter（预览绘制）

- 文件：`lib/painters/preview_painter.dart`
- 作用：在编辑界面中按当前配置绘制缩放后的预览图
- 主要流程：
  - 计算图片在视图中的缩放因子，保证完整显示
  - 在底部绘制白色半透明背景条，使用 `bgHeightPercent` 控制高度
  - 左侧预留 Logo 区域，按 `logoHeightFactor` / `logoWidthFactor` 缩放 Logo 并居中放置
  - 右侧展示两行文本：
    - 顶部：相机型号、镜头型号
    - 底部：焦距、曝光时间、ISO、光圈
  - 若配置了 `author`，在白色区域居中绘制署名
- 文本绘制：
  - 使用 `ui.ParagraphBuilder` + `ui.Paragraph` 进行排版
  - 字体大小基于配置的 `fontSize` 并结合缩放因子调整

### 2. \_compose（导出合成）

- 定义在 `EditorScreen._compose` 中
- 与 PreviewPainter 类似，但在原始分辨率上绘制：
  - 使用 `ui.PictureRecorder` 在内存中绘制完整图片 + 水印
  - 先绘制原图，再绘制底部背景 + Logo + EXIF 文本 + 作者
  - 最终输出为 `ui.Image`，供导出使用
- 设计理念：预览与导出使用同一套文本布局逻辑，减少“预览与实际不一致”的风险

## 六、工具与模型层

### 1. ExifUtils（EXIF 工具）

- 文件：`lib/utils/exif_utils.dart`
- 功能：
  - `pick`：按 key 列表优先级从 EXIF map 中取第一个非空值
  - `formatFocal`：将焦距字段统一为 `xx mm` 格式，支持分数型字符串
  - `formatISO`：标准化为 `ISO xxx`
  - `formatFNumber`：统一为 `f/xx` 格式
  - `twoLines`：将多种 EXIF 字段组合为上下两行便于显示
- 价值：统一格式化规则，确保 UI 与导出中的文案一致

### 2. WatermarkType（水印类型模型）

- 文件：`lib/models/watermark.dart`
- 当前只有 `WatermarkType.exif`
- 后续扩展新水印方案时，建议：
  - 在枚举中新增类型
  - 在 `TypeSelectScreen` 中添加对应卡片
  - 在 `EditorScreen` 中按类型分支不同配置或渲染逻辑

## 七、文件与依赖关系概览

- 入口：
  - `main.dart` → `app.dart` → `EntryScreen`
- 页面：
  - `screens/entry_screen.dart`
  - `screens/type_select_screen.dart`
  - `screens/editor_screen.dart`
- 服务与工具：
  - `services/prefs.dart`：本地偏好存储
  - `utils/exif_utils.dart`：EXIF 文本格式化
- 渲染：
  - `painters/preview_painter.dart`：预览绘制
  - `EditorScreen._compose`：最终合成与导出
- 模型：
  - `models/watermark.dart`：水印类型枚举

## 八、扩展思路

- 新增水印类型：
  - 扩展 `WatermarkType` 枚举和类型选择页面
  - 为每种类型设计独立配置面板与绘制逻辑
- 优化架构方向：
  - 抽象统一的“水印配置”模型，减少 EditorScreen 内部字段数量
  - 将合成逻辑封装到单独 service，便于测试与复用
  - 引入状态管理方案（如 Riverpod 等）时，可更好分离 UI 与业务
