#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Folly 课程最终高级检查                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

issues=0

echo "🔍 最终检查 1: 日期一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
dates_2024=$(grep -r "2024-01-30" *.md 2>/dev/null | grep -v "^archive" | wc -l)
dates_2026=$(grep -r "2026-01-30" *.md 2>/dev/null | grep -v "^archive" | wc -l)
echo "课程文件使用 2024-01-30: $dates_2024 处"
echo "课程文件使用 2026-01-30: $dates_2026 处"
if [ $dates_2026 -gt 0 ]; then
    echo "⚠️  发现使用 2026 年日期"
    ((issues++))
else
    echo "✅ 日期一致"
fi
echo ""

echo "🔍 最终检查 2: 文件格式规范"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
format_issues=0
# 检查课程文件是否有UTF-8 BOM
for file in Day*.md README.md INDEX.md; do
    if [ -f "$file" ]; then
        if file "$file" | grep -q "with BOM"; then
            echo "⚠️  $file 包含 BOM"
            ((format_issues++))
            ((issues++))
        fi
    fi
done
if [ $format_issues -eq 0 ]; then
    echo "✅ 文件格式正确（无BOM）"
else
    echo "⚠️  发现 $format_issues 个格式问题"
fi
echo ""

echo "🔍 最终检查 3: Markdown 语法"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 统计标题层级
h1_count=$(grep -r '^# ' *.md 2>/dev/null | grep -v "^archive" | wc -l)
h2_count=$(grep -r '^## ' *.md 2>/dev/null | grep -v "^archive" | wc -l)
h3_count=$(grep -r '^### ' *.md 2>/dev/null | grep -v "^archive" | wc -l)
echo "一级标题 (#): $h1_count 个"
echo "二级标题 (##): $h2_count 个"
echo "三级标题 (###): $h3_count 个"
echo "✅ Markdown 结构检查完成"
echo ""

echo "🔍 最终检查 4: 代码示例质量"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 统计有语言标识的代码块
cpp_with_lang=$(grep -r '^```cpp$' *.md 2>/dev/null | grep -v "^archive" | wc -l)
bash_with_lang=$(grep -r '^```bash$' *.md 2>/dev/null | grep -v "^archive" | wc -l)
total_code_blocks=$(grep -r '^```' *.md 2>/dev/null | grep -v "^archive" | wc -l)
echo "C++ 代码块（有标识）: $cpp_with_lang 个"
echo "Bash 代码块（有标识）: $bash_with_lang 个"
echo "总代码块标记: $total_code_blocks 个"
echo "✅ 代码示例统计完成"
echo ""

echo "🔍 最终检查 5: 配套资源命名"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
naming_issues=0
# 检查配套资源文件命名是否使用大写
for file in [A-Z]*.md; do
    if [[ ! "$file" =~ ^ Day[0-9] ]]; then
        case "$file" in
            README.md|INDEX.md|EXERCISES.md|FAQ.md|QUICK*.md|TROUBLESHOOTING.md|VISUAL_GUIDE.md|PROJECT_IDEAS.md|PROGRESS*.md|CODE_EXAMPLES.md|PRODUCTION*.md|INTERVIEW*.md|GLOSSARY.md|COMMON_PITFALLS.md|COURSE*.md|DELIVERY*.md|FINAL*.md|Day00*.md)
                # 这些是正确的命名
                ;;
            *)
                echo "⚠️  文件命名可能不符合规范: $file"
                ((naming_issues++))
                ;;
        esac
    fi
done
if [ $naming_issues -eq 0 ]; then
    echo "✅ 文件命名符合规范"
else
    echo "⚠️  发现 $naming_issues 个命名问题"
fi
echo ""

echo "🔍 最终检查 6: 归档文件隔离"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查主要文档是否引用了归档文件
archive_refs=0
for file in README.md INDEX.md QUICKSTART.md Day00_学习指南.md; do
    if [ -f "$file" ]; then
        refs=$(grep "archive_" "$file" 2>/dev/null | wc -l)
        if [ $refs -gt 0 ]; then
            echo "⚠️  $file 引用了归档文件 ($refs 处)"
            ((archive_refs++))
            ((issues++))
        fi
    fi
done
if [ $archive_refs -eq 0 ]; then
    echo "✅ 主要文档未引用归档文件（正确）"
else
    echo "⚠️  发现对归档文件的引用"
fi
echo ""

echo "🔍 最终检查 7: 文件完整性验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查所有Day文件是否都有基础版和增强版
complete_pairs=0
for i in {01..14}; do
    basic=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版" | wc -l)
    enhanced=$(ls Day${i}_*_增强版.md 2>/dev/null | wc -l)
    if [ "$basic" -eq 1 ] && [ "$enhanced" -eq 1 ]; then
        ((complete_pairs++))
    fi
done
echo "完整的 Day 文件对: $complete_pairs/14"
if [ $complete_pairs -eq 14 ]; then
    echo "✅ 所有 Day 文件都有基础版和增强版"
else
    echo "⚠️  部分文件缺失"
    ((issues++))
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
if [ $issues -eq 0 ]; then
    echo "║              ✅ 最终高级检查通过！                        ║"
    echo "║                 课程质量：优秀 ⭐⭐⭐⭐⭐                  ║"
else
    echo "║           ⚠️  发现 $issues 个问题                             ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"

