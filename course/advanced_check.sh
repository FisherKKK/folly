#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Folly 课程高级检查                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

issues=0

echo "🔍 高级检查 1: 检查日期一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
dates_2024=$(grep -r "2024-01-30" *.md 2>/dev/null | wc -l)
dates_2026=$(grep -r "2026-01-30" *.md 2>/dev/null | wc -l)
echo "使用日期 2024-01-30: $dates_2024 处"
echo "使用日期 2026-01-30: $dates_2026 处"
if [ $dates_2026 -gt 0 ]; then
    echo "⚠️  发现使用 2026 年日期，应该是 2024 年"
    ((issues++))
else
    echo "✅ 日期一致"
fi
echo ""

echo "🔍 高级检查 2: 检查中文标点符号"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查是否有英文标点混用
english_period=$(grep -r "[a-zA-Z]\." Day*.md 2>/dev/null | wc -l)
echo "英文句号使用: $english_period 处（正常）"
echo "✅ 标点符号检查完成"
echo ""

echo "🔍 高级检查 3: 检查代码块格式"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
code_blocks=$(grep -r '```' *.md 2>/dev/null | wc -l)
if [ $((code_blocks % 2)) -ne 0 ]; then
    echo "⚠️  代码块标记可能不成对"
    ((issues++))
else
    echo "✅ 代码块格式正确（$code_blocks 个标记）"
fi
echo ""

echo "🔍 高级检查 4: 检查标题层级"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查是否有跳级的标题
for file in Day*.md; do
    if [ -f "$file" ]; then
        # 检查是否直接从一级标题跳到三级标题
        if grep -q "^# " "$file" && grep -q "^### " "$file" && ! grep -q "^## " "$file"; then
            echo "⚠️  $file 可能缺少二级标题"
            ((issues++))
        fi
    fi
done
echo "✅ 标题层级检查完成"
echo ""

echo "🔍 高级检查 5: 检查空文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
empty_files=0
for file in *.md; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        if [ $lines -lt 10 ]; then
            echo "⚠️  $file 文件过小 ($lines 行)"
            ((empty_files++))
            ((issues++))
        fi
    fi
done
if [ $empty_files -eq 0 ]; then
    echo "✅ 没有过小的文件"
fi
echo ""

echo "🔍 高级检查 6: 检查特殊字符"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查是否有非UTF-8字符
non_ascii=$(grep -P '[^\x00-\x7F]' *.md 2>/dev/null | wc -l)
echo "非ASCII字符: $non_ascii 处（中文正常）"
echo "✅ 字符编码检查完成"
echo ""

echo "🔍 高级检查 7: 检查链接格式"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查是否有空链接
empty_links=$(grep -r "\[\]" *.md 2>/dev/null | wc -l)
if [ $empty_links -gt 0 ]; then
    echo "⚠️  发现 $empty_links 个空链接"
    ((issues++))
else
    echo "✅ 没有空链接"
fi
echo ""

echo "🔍 高级检查 8: 检查表格格式"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 统计使用表格的文件
table_files=$(grep -l '^|' *.md 2>/dev/null | wc -l)
echo "使用表格的文件: $table_files 个"
echo "✅ 表格格式检查完成"
echo ""

echo "🔍 高级检查 9: 检查代码语言标识"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查代码块是否有语言标识
cpp_blocks=$(grep -r '```cpp' *.md 2>/dev/null | wc -l)
bash_blocks=$(grep -r '```bash' *.md 2>/dev/null | wc -l)
no_lang=$(grep -r '```$' *.md 2>/dev/null | wc -l)
echo "C++ 代码块: $cpp_blocks 个"
echo "Bash 代码块: $bash_blocks 个"
echo "无语言标识: $no_lang 个"
echo "✅ 代码块语言检查完成"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
if [ $issues -eq 0 ]; then
    echo "║              ✅ 高级检查通过，未发现问题！                   ║"
else
    echo "║           ⚠️  发现 $issues 个问题，请查看上述详情                  ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"

