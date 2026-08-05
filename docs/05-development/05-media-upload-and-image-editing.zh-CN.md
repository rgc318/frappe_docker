# 统一媒体上传与图片编辑设计

## 1. 目标与范围

本设计统一 MyApp 的图片选择、裁剪、压缩、格式化、上传、替换和重新编辑能力，解决不同终端上传图片比例、像素、文件大小和格式不一致的问题。

首期覆盖：

- Web 商品创建、商品编辑、商品详情和 AI 商品草稿中的商品图片。
- Web AI 当前商品详情中的即时上传、替换、删除和重新裁剪。
- Web 个人设置中的用户头像。
- Mobile 商品创建和商品详情中的相册选择、拍照、裁剪和替换。
- Backend 商品图片与用户头像上传接口的统一安全校验和规范化。

CSV、XLSX、PDF 等结构化或文档文件不进入图片裁剪器。它们继续采用各自的扩展名白名单、大小限制、模板校验、预览和导入审计流程。未来新增品牌 Logo、公司 Logo、附件图片或业务凭证时，应复用本设计的 profile，而不是复制页面级上传逻辑。

## 2. 调研结论

本设计参考以下官方资料：

- Ant Design Upload：支持在 `beforeUpload` 中转换文件，并把“上传前裁剪”作为正式示例模式。
  - <https://ant.design/components/upload/>
- Cloudinary Image Transformations：企业媒体平台通常以可复用 transformation/profile 管理比例、裁剪、尺寸、格式和质量；交付层再根据终端生成派生版本。
  - <https://cloudinary.com/documentation/image_transformations>
- MDN `HTMLCanvasElement.toBlob()`：浏览器可以指定 JPEG/WebP 等输出格式和压缩质量，适合在上传前生成规范化文件。
  - <https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toBlob>
- OWASP File Upload Cheat Sheet：扩展名和客户端 `Content-Type` 不能单独作为安全依据；服务端应同时做白名单、真实内容/签名检查、文件名治理、大小限制、权限和存储隔离。
  - <https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html>

主流企业级方案的共同点：

1. 页面不自行决定任意尺寸，而是选择稳定的媒体 profile。
2. 客户端编辑用于用户体验和减少带宽，服务端规范化用于最终一致性和安全。
3. 原始输入和正式业务图片有明确生命周期，不把未确认上传直接写入正式主数据。
4. 文件格式、像素、字节大小、真实内容和权限分别校验，不能只看扩展名或 MIME。
5. 返回可审计的媒体元数据，便于后续迁移到 OSS、S3、MinIO 或派生缩略图服务。

## 3. 统一媒体 Profile

| Profile            | 用途     | 客户端编辑                                                | 后端正式输出                                  | 最低来源分辨率 |
| ------------------ | -------- | --------------------------------------------------------- | --------------------------------------------- | -------------- |
| `item-flexible-v2` | 商品主图 | 自由、1:1、4:3、3:2、16:9，支持横纵切换、拖动、缩放和旋转 | 保留裁剪比例，最长边 1600px WebP，起始质量 82 | 最短边 300px   |
| `avatar-square-v1` | 用户头像 | 固定 1:1 裁剪、拖动、缩放、90°旋转                        | 固定 512 × 512 WebP，起始质量 85              | 最短边 128px   |

共同限制：

- 官方 Web 客户端接受 JPG、PNG、WebP。
- 原始上传最大 20MB。
- 原始图片最大 4000 万像素，避免超大图片解码造成内存风险。
- 商品规范化文件最大 5MB；头像规范化文件最大 2MB。
- 商品自由裁剪宽高比限制为 `0.4–2.5`，避免生成极端狭长、难以在业务列表和打印中使用的图片。
- 超过输出字节上限时逐级降低 WebP 质量；达到最低质量仍超限则拒绝保存。
- 动图不作为正式商品图或头像能力；动画帧、EXIF 和其他原始元数据不会进入正式输出。
- 后端会纠正 EXIF 方向、真实解码图片、按 profile 保留比例或居中兜底裁剪、LANCZOS 缩放并重新编码为 WebP。

## 4. 处理链路

```text
用户选择/拍照
    ↓
客户端来源校验（类型、20MB、像素、最低分辨率）
    ↓
Profile 编辑（自由/预设比例、裁剪、拖动、缩放、旋转）
    ↓
客户端生成 WebP，降低上传带宽
    ↓
Gateway 上传接口
    ↓
后端真实解码、像素限制、EXIF 修正、二次规范化、元数据移除
    ↓
Frappe File（Temporary 或正式绑定）
    ↓
Item.image / User.user_image
```

客户端处理不是安全边界。旧客户端、Mobile、脚本或绕过 Web 编辑器的调用最终都必须经过后端 profile。

## 5. 前端组件边界

Web：

- `src/components/ImageEditorUpload.tsx`
  - 统一文件选择、读取当前图片、编辑弹窗、自由/预设比例、横纵切换、拖动、缩放、旋转和输出。
  - 支持“重新裁剪”已有图片；读取失败时要求重新选择本地原图。
- `src/utils/image-processing.ts`
  - 定义 profile、来源校验、位移约束、Canvas 导出、WebP 质量和文件名格式化。
- `src/components/ItemImageUpload.tsx`
  - 只负责商品图片的 staged/immediate 事务语义和商品媒体 API。
- `src/pages/Account/AvatarUpload.tsx`
  - 只负责头像上传 API 和头像展示。

页面不得再次实现 `FileReader`、Canvas 裁剪、压缩质量、输出尺寸或 MIME 规则。新增图片类型时先新增 profile，再复用 `ImageEditorUpload`。

Mobile：

- `components/item-image-field.tsx` 使用 `react-native-image-crop-picker` 提供自由、1:1、4:3、3:2、16:9 裁剪和横纵切换。
- 相册和相机使用同一“最长边 1600px / quality 0.82”策略。
- Web fallback 使用 Expo `allowsEditing` 和所选预设比例；自由模式由平台编辑器决定裁剪框，最终比例与输出边界仍由后端保证。

## 6. 后端边界与返回元数据

`myapp.utils.image_processing` 是后端正式图片规范化边界。商品图片和头像服务必须选择 profile 后调用它，不得在各服务中手写裁剪或格式转换。

上传响应除现有 `file_url`、`file_id`、绑定关系和存储提供方外，增加：

- `content_type`
- `file_size`
- `width`
- `height`
- `aspect_ratio`
- `profile`
- `quality`
- `source_width`
- `source_height`
- `source_format`

这些字段用于确认正式输出、排查历史客户端和未来媒体存储迁移，不允许客户端据此绕过业务字段保存事务。

## 7. 生命周期与一致性

- 商品创建、普通编辑和 AI 商品草稿默认 staged：图片先进入 Temporary，保存商品或执行草稿时再绑定。
- 用户取消表单不会提前修改正式 `Item.image`。
- 明确的独立图片动作使用 immediate：上传成功后立即替换正式图片，并在事务成功后清理旧受管文件。
- “重新裁剪”会生成新文件，沿用同样的 staged/immediate 语义，不原地覆盖已有文件。
- 用户头像属于明确独立动作，上传成功后更新 `User.user_image` 并清理旧受管头像。
- 暂存商品图片仍由既有 24 小时清理任务治理，并保护活动 AI 草稿引用。

## 8. 当前取舍与后续扩展

当前只保存规范化正式图片，不额外长期保存用户原始文件，优先控制存储成本、隐私元数据和历史大文件。若未来需要无损反复编辑、印刷原稿、DAM 或内容审核，应增加独立的 original asset，而不是把原图继续写入 `Item.image`。

未来可扩展：

- `brand-logo-v1`、`company-logo-v1`、`document-proof-v1` 等新 profile。
- 列表缩略图、详情中图、打印图等服务端派生尺寸和 CDN 缓存。
- 内容审核、病毒扫描、感知哈希、重复图片检测和图片质量评分。
- 对象存储直传、异步处理状态和失败恢复。
- 保留原始资产时的权限、保留期、版本和删除审计。

## 9. 验证要求

- Web：`npm run tsc`、`npm run biome:lint`、相关 Jest 和全量 Jest；覆盖自由比例边界、预设输出尺寸与横纵切换。
- Backend：容器内运行图片处理、媒体服务和用户头像单元测试。
- Mobile：`npm run lint`，并至少在 Android/iOS 原生裁剪器和 Web fallback 各验证一次。
- HTTP smoke 应验证自由比例、1:1、4:3、3:2、16:9、横图、竖图、透明 PNG、超大来源、伪造扩展名、低分辨率和已有图片重新裁剪。
