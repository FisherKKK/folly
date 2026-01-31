#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║      Folly 课程完整性检查报告 - 最终版本                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 统计总文件数（不包括归档文件）
course_files=$(ls -1 *.md 2>/dev/null | grep -v "^archive_" | wc -l)
archive_files=$(ls -1 archive_*.md 2>/dev/null | wc -l)
total_files=$(ls -1 *.md 2>/dev/null | wc -l)

echo "📊 文件统计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "课程文件数: $course_files"
echo "归档文件数: $archive_files"
echo "总文件数:   $total_files"
echo ""

# 统计行数
total_lines=$(cat *.md 2>/dev/null | wc -l)
course_lines=$(cat *.md 2>/dev/null | grep -v "^archive_" | wc -l)
archive_lines=$(cat archive_*.md 2>/dev/null | wc -l)

echo "📏 行数统计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "课程文件总行数: $course_lines"
echo "归档文件行数:   $archive_lines"
echo "所有文件总行数: $total_lines"
echo ""

# 检查 Day 文件
echo "📚 Day 文件检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
all_complete=true
for i in {01..14}; do
    basic=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版" | wc -l)
    enhanced=$(ls Day${i}_*_增强版.md 2>/dev/null | wc -l)
    
    if [ "$basic" -gt 0 ] && [ "$enhanced" -gt 0 ]; then
        basic_name=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版")
        enhanced_name=$(ls Day${i}_*_增强版.md 2>/dev/null)
        basic_lines=$(wc -l < "$basic_name" 2>/dev/null)
        enhanced_lines=$(wc -l < "$enhanced_name" 2>/dev/null)
        echo "✅ Day${i}: 基础版 ${basic_lines}行, 增强版 ${enhanced_lines}行"
    else
        echo "❌ Day${i}: 文件缺失"
        all_complete=false
    fi
done
echo ""

# 检查配套资源
echo "🛠️  配套资源检查"
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

resource_count=0
for resource in "${resources[@]}"; do
    if [ -f "$resource" ]; then
        lines=$(wc -l < "$resource")
        echo "✅ $resource ($lines 行)"
        ((resource_count++))
    else
        echo "❌ $resource - 缺失"
    fi
done
echo ""
echo "配套资源完成度: $resource_count / ${#resources[@]}"
echo ""

# 检查数据一致性
echo "🔍 数据一致性检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查 COURSE_SUMMARY.md 中的总行数
if [ -f "COURSE_SUMMARY.md" ]; then
    summary_lines=$(grep "总行数：" COURSE_SUMMARY.md | head -1 | grep -oP '\d+')
    if [ "$summary_lines" == "$total_lines" ]; then
        echo "✅ COURSE_SUMMARY.md 总行数正确 ($summary_lines)"
    else
        echo "⚠️  COURSE_SUMMARY.md 总行数: $summary_lines (实际: $total_lines)"
    fi
fi

# 检查 DELIVERY_CHECKLIST.md 中的总行数
if [ -f "DELIVERY_CHECKLIST.md" ]; then
    delivery_lines=$(grep "总行数：" DELIVERY_CHECKLIST.md | head -1 | grep -oP '\d+')
    if [ "$delivery_lines" == "$total_lines" ]; then
        echo "✅ DELIVERY_CHECKLIST.md 总行数正确 ($delivery_lines)"
    else
        echo "⚠️  DELIVERY_CHECKLIST.md 总行数: $delivery_lines (实际: $total_lines)"
    fi
fi

# 检查 FINAL_STATUS.md 中的总行数
if [ -f "FINAL_STATUS.md" ]; then
    status_lines=$(grep "总行数：" FINAL_STATUS.md | head -1 | grep -oP '\d+')
    if [ "$status_lines" == "$total_lines" ]; then
        echo "✅ FINAL_STATUS.md 总行数正确 ($status_lines)"
    else
        echo "⚠️  FINAL_STATUS.md 总行数: $status_lines (实际: $total_lines)"
    fi
fi
echo ""

# 检查归档文件
echo "📦 归档文件检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "archive_00_学习指南.md" ]; then
    archive_lines=$(wc -l < archive_00_学习指南.md)
    echo "✅ archive_00_学习指南.md ($archive_lines 行) - 已归档"
    
    # 确认课程目录中没有引用旧文件名
    if grep -q "00_学习指南.md" README.md INDEX.md QUICKSTART.md 2>/dev/null; then
        echo "⚠️  发现对旧文件名的引用（不包括归档）"
    else
        echo "✅ 没有对旧文件名的引用"
    fi
else
    echo "❌ 归档文件缺失"
fi
echo ""

# 最终总结
echo "╔════════════════════════════════════════════════════════════╗"
if [ "$all_complete" = true ] && [ "$resource_count" -eq "${#resources[@]}" ]; then
    echo "║              ✅ 所有检查通过，课程完整！                    ║"
else
    echo "║              ⚠️  发现问题，请查看上述详情                    ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"

