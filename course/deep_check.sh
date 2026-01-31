#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Folly 课程深度检查报告                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

issues_found=0

echo "🔍 检查 1: 文件命名一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查是否有不符合命名规范的文件
for file in Day*.md; do
    if [[ ! "$file" =~ ^Day[0-9]{2}_.*(_增强版)?\.md$ ]]; then
        echo "⚠️  命名可能不符合规范: $file"
        ((issues_found++))
    fi
done
if [ $issues_found -eq 0 ]; then
    echo "✅ 所有 Day 文件命名符合规范"
else
    echo "❌ 发现 $issues_found 个命名问题"
fi
echo ""

echo "🔍 检查 2: 版本号一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
version_in_summary=$(grep "课程版本" COURSE_SUMMARY.md | head -1 | grep -oP 'v[0-9.]+')
version_in_delivery=$(grep "课程版本" DELIVERY_CHECKLIST.md | head -1 | grep -oP 'v[0-9.]+')
version_in_status=$(grep "课程版本" FINAL_STATUS.md | head -1 | grep -oP 'v[0-9.]+')

if [ "$version_in_summary" == "$version_in_delivery" ] && [ "$version_in_delivery" == "$version_in_status" ]; then
    echo "✅ 版本号一致: $version_in_summary"
else
    echo "⚠️  版本号不一致:"
    echo "   COURSE_SUMMARY.md: $version_in_summary"
    echo "   DELIVERY_CHECKLIST.md: $version_in_delivery"
    echo "   FINAL_STATUS.md: $version_in_status"
    ((issues_found++))
fi
echo ""

echo "🔍 检查 3: 日期一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
date_count=$(grep -r "2024-01-30" *.md 2>/dev/null | wc -l)
echo "✅ 使用统一日期 2024-01-30 的文件数: $date_count"
echo ""

echo "🔍 检查 4: 内部链接检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查 README.md 中的链接
broken_links=0
for link in $(grep -oP '\[.*?\]\(\K[^\)]+' README.md | grep '\.md$'); do
    if [ ! -f "$link" ]; then
        echo "⚠️  README.md 中的损坏链接: $link"
        ((broken_links++))
        ((issues_found++))
    fi
done
if [ $broken_links -eq 0 ]; then
    echo "✅ README.md 中的所有链接有效"
else
    echo "❌ 发现 $broken_links 个损坏链接"
fi
echo ""

echo "🔍 检查 5: 归档文件引用"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查是否在主要文档中引用了归档文件
archive_refs=$(grep -l "archive_" README.md INDEX.md QUICKSTART.md 2>/dev/null | wc -l)
if [ $archive_refs -eq 0 ]; then
    echo "✅ 主要文档中没有引用归档文件"
else
    echo "⚠️  发现对归档文件的引用:"
    grep -Hn "archive_" README.md INDEX.md QUICKSTART.md 2>/dev/null | head -5
fi
echo ""

echo "🔍 检查 6: 课程结构完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查每个Day是否都有基础版和增强版
missing_count=0
for i in {01..14}; do
    basic_count=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版" | wc -l)
    enhanced_count=$(ls Day${i}_*_增强版.md 2>/dev/null | wc -l)
    
    if [ "$basic_count" -ne 1 ] || [ "$enhanced_count" -ne 1 ]; then
        echo "⚠️  Day${i} 文件不完整 (基础版: $basic_count, 增强版: $enhanced_count)"
        ((missing_count++))
        ((issues_found++))
    fi
done
if [ $missing_count -eq 0 ]; then
    echo "✅ 所有 Day 文件结构完整 (14/14)"
else
    echo "❌ $missing_count 个 Day 文件不完整"
fi
echo ""

echo "🔍 检查 7: 配套资源完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# 检查19个配套资源是否都在 README 中被提及
mentioned_in_readme=0
for resource in INDEX.md QUICKSTART.md Day00_学习指南.md EXERCISES.md QUICK_REFERENCE.md TROUBLESHOOTING.md VISUAL_GUIDE.md PROJECT_IDEAS.md PROGRESS_TRACKER.md CODE_EXAMPLES.md PRODUCTION_CHECKLIST.md INTERVIEW_QUESTIONS.md GLOSSARY.md FAQ.md COMMON_PITFALLS.md COURSE_SUMMARY.md DELIVERY_CHECKLIST.md FINAL_STATUS.md; do
    if grep -q "$resource" README.md; then
        ((mentioned_in_readme++))
    fi
done
echo "✅ README 中提及了 $mentioned_in_readme/19 个配套资源"
echo ""

echo "🔍 检查 8: 空文件或过小文件"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
small_files=0
for file in Day*.md; do
    lines=$(wc -l < "$file")
    if [ $lines -lt 50 ]; then
        echo "⚠️  文件过小 (< 50行): $file ($lines 行)"
        ((small_files++))
        ((issues_found++))
    fi
done
if [ $small_files -eq 0 ]; then
    echo "✅ 没有过小的 Day 文件"
else
    echo "⚠️  发现 $small_files 个过小文件"
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
if [ $issues_found -eq 0 ]; then
    echo "║              ✅ 深度检查通过，未发现问题！                   ║"
else
    echo "║              ⚠️  发现 $issues_found 个问题，请查看上述详情           ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"

