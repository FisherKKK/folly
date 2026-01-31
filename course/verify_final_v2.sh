#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Folly 课程最终验证报告 v2.0                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 统计课程文件（不包括归档文件）
course_files=$(ls -1 *.md 2>/dev/null | grep -v "^archive_" | wc -l)
# 统计归档文件
archive_files=$(ls -1 archive*.md 2>/dev/null | wc -l)
# 总文件数
total_files=$(ls -1 *.md 2>/dev/null | wc -l)
# 总行数
total_lines=$(cat *.md 2>/dev/null | wc -l)

echo "✅ 最终验证结果"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "课程文件数: $course_files"
echo "归档文件数: $archive_files"
echo "总文件数:   $total_files"
echo "总行数:     $total_lines"
echo ""

echo "✅ Day 文件完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
all_complete=true
for i in {01..14}; do
    basic=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版" | wc -l)
    enhanced=$(ls Day${i}_*_增强版.md 2>/dev/null | wc -l)
    
    if [ "$basic" -gt 0 ] && [ "$enhanced" -gt 0 ]; then
        echo "Day${i}: ✅"
    else
        echo "Day${i}: ❌"
        all_complete=false
    fi
done
echo ""

echo "✅ 配套资源完整性 (19个)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
resources=(
    "README.md"
    "INDEX.md"
    "QUICKSTART.md"
    "Day00_学习指南.md"
    "EXERCISES.md"
    "QUICK_REFERENCE.md"
    "TROUBLESHOOTING.md"
    "VISUAL_GUIDE.md"
    "PROJECT_IDEAS.md"
    "PROGRESS_TRACKER.md"
    "CODE_EXAMPLES.md"
    "PRODUCTION_CHECKLIST.md"
    "INTERVIEW_QUESTIONS.md"
    "GLOSSARY.md"
    "FAQ.md"
    "COMMON_PITFALLS.md"
    "COURSE_SUMMARY.md"
    "DELIVERY_CHECKLIST.md"
    "FINAL_STATUS.md"
)

all_present=true
for resource in "${resources[@]}"; do
    if [ -f "$resource" ]; then
        echo "✅ $resource"
    else
        echo "❌ $resource"
        all_present=false
    fi
done
echo ""

echo "✅ 归档文件 ($archive_files 个)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for archive_file in archive*.md; do
    if [ -f "$archive_file" ]; then
        lines=$(wc -l < "$archive_file")
        echo "✅ $archive_file ($lines 行)"
    fi
done
echo ""

echo "✅ 数据一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for file in COURSE_SUMMARY.md DELIVERY_CHECKLIST.md FINAL_STATUS.md; do
    if [ -f "$file" ]; then
        # 提取文档中的总行数（处理逗号）
        doc_lines=$(grep "总行数：" "$file" | head -1 | grep -oP '\d+' | tr -d '\n')
        if [ "$doc_lines" == "$total_lines" ]; then
            echo "✅ $file ($doc_lines 行)"
        else
            echo "⚠️  $file: 文档中 $doc_lines 行 (实际 $total_lines 行)"
        fi
    fi
done
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
if [ "$all_complete" = true ] && [ "$all_present" = true ]; then
    echo "║           ✅ 课程完整，所有检查通过！                         ║"
else
    echo "║           ⚠️  发现问题，请查看上述详情                          ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
