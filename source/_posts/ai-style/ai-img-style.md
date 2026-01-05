---
layout: pages
title: nano banana 技术风格
date: 2026-01-05 13:02:05
tags: [AI, gemini]
---
# 风格
## "Retro Engineering Schematic" (复古工程蓝图/原理图风格)

* 特点：融合了“达芬奇手稿”、“老式专利图纸”和“现代UI图标”

### 🎨 风格定义 (Style Definition)
这种风格的核心要素包含：
1. 背景 (Background):
    * 材质: 米黄色纸张 (Yellowish Paper)、羊皮纸 (Vintage Parchment)、做旧纸张 (Aged Paper)。
    * 纹理: 轻微的纸张纹理，偶尔带有网格线或测量标记 (Grid/Measurement Lines)，增加工程感。
2. 线条 (Line Work):
    * 墨线 (Ink Lines): 清晰、精细的黑色轮廓线，像针管笔手绘。
    * 风格: 干净利落 (Clean)，非素描草图，具有专业制图的严谨性。
3. 色彩 (Color Palette):
    * 主色调: 暖色调背景 + 黑色线条。
    * 点缀色 (Accents): 使用 低饱和度淡彩 (Light Pastels) 或 复古墨水色（如青色 Teal、砖红色 Brick Red、琥珀色 Amber）来区分功能块。避免使用高饱和度的霓虹色。
4. 内容元素 (Elements):
    * 微缩图示 (Micro-Schematics): 每个模块内部包含具体的微型图标（文档、树状图、网络、放大镜），而非抽象的空框。
    * 布局: 结构化布局（层级堆叠或线性流程），强调逻辑关系。

### 📝 通用提示词模板 (Universal Prompt Template)
您可以将下方的 [您的主题] 和 [具体内容] 替换为您需要生成的任何技术内容。
#### 英文模板 (推荐)
> Create an image illustrating [YOUR TECHNICAL TOPIC].
>
> Style: Retro Engineering Schematic on Yellowish Paper.
>
> * Visual Aesthetic: Vintage technical drawing style, clean black ink lines on warm aged paper background. Professional, detailed, and precise.
> * Colors: Black outlines with soft pastel color accents (Teal, Brick Red, Amber) to highlight key elements. NO neon or dark mode colors.
> * Structure: [DESCRIBE LAYOUT, e.g., A vertical stack of 5 layers / A horizontal flowchart].
> * Details: Inside each block/node, draw detailed schematic icons representing its function (e.g., [LIST ICONS, e.g., databases, servers, code blocks]). Avoid heavy industrial machinery; use modern UI/software metaphors instead.
>
> Specific Content:
> 1. [Part 1 Name]: [Description of icon/action]. Label: "[Label Name]".
> 2. [Part 2 Name]: [Description of icon/action]. Label: "[Label Name]".
> 3. [Part 3 Name]: [Description of icon/action]. Label: "[Label Name]".
> ...
>
> Key: High-quality technical illustration, schematic clarity, vintage aesthetic.

**中文应用示例 (以"微服务架构"为例)**

如果您想生成一张 微服务架构图，您可以这样填写模板：

> Create an image illustrating a Microservices Architecture.
>
> Style: Retro Engineering Schematic on Yellowish Paper.
>
> * Visual Aesthetic: Vintage technical drawing style, clean black ink lines on warm aged paper background.
> * Colors: Black outlines with soft pastel color accents (Teal for services, Red for databases).
> * Structure: A central hub connected to multiple independent service blocks.
> * Details: Inside each block, draw schematic icons like Servers, APIs, and Databases.
>
> Specific Content:
> 1. Gateway: An icon of a door or switch. Label: "API Gateway".
> 2. Service A: An icon of a user profile. Label: "User Service".
> 3. Service B: An icon of a shopping cart. Label: "Order Service".
> 4. Database: Cylinder icons connected to services. Label: "DB Clusters".
>
> Key: High-quality technical illustration, schematic clarity, vintage aesthetic.

### 💡 关键修饰词 (Magic Keywords)
如果您想微调风格，可以尝试添加或强调以下词汇：
* 更复古: "Leonardo da Vinci sketch style" (达芬奇手稿风), "Patent illustration" (专利图纸风).
* 更现代/整洁: "Minimalist schematic" (极简原理图), "Infographic style" (信息图风格).
* 强调细节: "Intricate details" (错综复杂的细节), "Micro-icons" (微图标).
希望这个模板能帮助您在未来的技术文档中保持这种高质量的视觉风格！
