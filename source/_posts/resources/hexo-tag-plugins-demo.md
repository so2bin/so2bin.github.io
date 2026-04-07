---
title: Hexo Tag Plugins 写法速查
date: 2026-04-07
categories: resources
tags:
  - Hexo
  - 写作
  - 工具
---

# Hexo Tag Plugins 写法速查

本文汇总 Butterfly / NexT 主题常用的 Tag Plugin 写法，方便写文章时随时参考。

---

## 1. Tabs 标签页切换（Butterfly + NexT 通用）

{% tabs demo-tabs %}
<!-- tab Go -->
```go
func main() {
    fmt.Println("Hello Go")
}
```
<!-- endtab -->

<!-- tab Python -->
```python
def main():
    print("Hello Python")
```
<!-- endtab -->

<!-- tab Bash -->
```bash
echo "Hello Bash"
```
<!-- endtab -->
{% endtabs %}

**写法：**

```
{% raw %}
{% tabs 唯一名称 %}
<!-- tab 标题1 -->
内容1
<!-- endtab -->

<!-- tab 标题2 -->
内容2
<!-- endtab -->
{% endtabs %}
{% endraw %}
```

> 图标可选（Butterfly），格式为 `<!-- tab 标题@fas fa-xxx -->`
> 指定默认激活第 N 个：`{% raw %}{% tabs 名称, 2 %}{% endraw %}`

---

## 2. Note 彩色提示块（Butterfly + NexT 通用）

{% note default %}
**default** — 默认灰色提示
{% endnote %}

{% note info %}
**info** — 蓝色信息提示
{% endnote %}

{% note success %}
**success** — 绿色成功提示
{% endnote %}

{% note warning %}
**warning** — 黄色警告提示
{% endnote %}

{% note danger %}
**danger** — 红色危险提示
{% endnote %}

**写法：**

```
{% raw %}
{% note 类型 %}
内容（支持 Markdown）
{% endnote %}

类型: default / info / success / warning / danger

Butterfly 额外支持样式参数:
{% note info simple %}  简洁样式
{% note info modern %}  现代样式（带左侧色条）
{% note info flat %}    扁平样式（全背景色）
{% endraw %}
```

---

## 3. 折叠展开（通用 HTML）

<details>
<summary>点击展开：查看部署步骤</summary>

1. 执行 `hexo clean`
2. 执行 `hexo generate`
3. 执行 `hexo deploy`

</details>

<details>
<summary>点击展开：hexo server 启动命令</summary>

```bash
hexo server -p 4000
```

</details>

**通用写法（所有主题兼容）：**

```html
<details>
<summary>显示的标题</summary>

折叠的内容（支持 Markdown）

</details>
```

**Butterfly 专属写法（效果更好看）：**

```
{% raw %}
{% hideToggle 显示的标题 %}
折叠的内容
{% endhideToggle %}

{% hideToggle 显示的标题, blue %}
支持颜色: blue / red / green / yellow / purple
{% endhideToggle %}
{% endraw %}
```

---

## 4. Button 按钮

NexT 写法：

{% btn https://github.com/so2bin, GitHub, fab fa-github %}
{% btn https://hexo.io, Hexo 官网, fas fa-globe %}

**写法：**

```
{% raw %}
NexT:
{% btn 链接, 文字, 图标 %}

Butterfly:
{% btn 链接, 文字, 图标, outline %}
{% endraw %}
```

**通用 HTML 替代：**

```html
<a href="https://github.com/so2bin" target="_blank">GitHub</a>
```

---

## 5. Label 行内标签（Butterfly 专属）

NexT 不支持，Butterfly 写法如下：

```
{% raw %}
{% label 类型 @文字 %}

类型: default / info / success / warning / danger
{% endraw %}
```

**通用 HTML 替代：**

`<span style="background:#49b1f5;color:#fff;padding:2px 6px;border-radius:3px;">标签</span>` → <span style="background:#49b1f5;color:#fff;padding:2px 6px;border-radius:3px;">标签</span>

---

## 6. Timeline 时间线（Butterfly 专属）

NexT 不支持，Butterfly 写法如下：

```
{% raw %}
{% timeline 2026 %}
<!-- timeline 04-07 -->
创建 Hexo Tag Plugins 速查文档
<!-- endtimeline -->
{% endtimeline %}
{% endraw %}
```

---

## 兼容性总结

| 写法 | Butterfly | NexT | 通用 HTML 替代 |
|------|-----------|------|----------------|
| Tabs | 支持 | 支持 | 无 |
| Note | 支持（3种样式） | 支持 | 无 |
| hideToggle | 支持 | 不支持 | `<details>` |
| Button | 支持 | 支持（语法略不同） | `<a>` |
| Label | 支持 | 不支持 | `<span>` |
| Timeline | 支持 | 不支持 | 无 |
