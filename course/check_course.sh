#!/bin/bash
echo "=== 课程完整性检查报告 ==="
echo ""

echo "1. 检查 Day 文件完整性"
echo "----------------------------"
missing_enhanced=0
missing_basic=0

for i in {01..14}; do
    basic=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版" | wc -l)
    enhanced=$(ls Day${i}_*_增强版.md 2>/dev/null | wc -l)
    
    if [ "$basic" -eq 0 ]; then
        echo "❌ Day${i}: 缺少基础版"
        ((missing_basic++))
    elif [ "$enhanced" -eq 0 ]; then
        echo "❌ Day${i}: 缺少增强版"
        ((missing_enhanced++))
    else
        basic_name=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版")
        enhanced_name=$(ls Day${i}_*_增强版.md 2>/dev/null)
        basic_lines=$(wc -l < "$basic_name")
        enhanced_lines=$(wc -l < "$enhanced_name")
        echo "✅ Day${i}: 基础版 ${basic_lines}行, 增强版 ${enhanced_lines}行"
    fi
done

echo ""
echo "2. 文件统计"
echo "----------------------------"
total_files=$(ls -1 *.md 2>/dev/null | wc -l)
total_lines=$(cat *.md | wc -l)
echo "总文件数: $total_files"
echo "总行数: $total_lines"

echo ""
echo "3. 重复文件检查"
echo "----------------------------"
if [ -f "00_学习指南.md" ] && [ -f "Day00_学习指南.md" ]; then
    echo "⚠️  发现两个学习指南文件:"
    echo "   - 00_学习指南.md ($(wc -l < 00_学习指南.md) 行)"
    echo "   - Day00_学习指南.md ($(wc -l < Day00_学习指南.md) 行)"
    echo "   建议: 保留 Day00_学习指南.md，归档或移除 00_学习指南.md"
fi

echo ""
echo "4. 检查总结"
echo "----------------------------"
if [ $missing_basic -eq 0 ] && [ $missing_enhanced -eq 0 ]; then
    echo "✅ 所有 Day 文件完整"
else
    echo "❌ 缺少 $missing_basic 个基础版, $missing_enhanced 个增强版"
fi

echo ""
echo "5. 配套资源检查"
echo "----------------------------"
resources=(
    "README.md:课程导航"
    "INDEX.md:综合索引"
    "QUICKSTART.md:快速入门"
    "EXERCISES.md:习题集"
    "QUICK_REFERENCE.md:快速参考"
    "TROUBLESHOOTING.md:故障排查"
    "VISUAL_GUIDE.md:可视化指南"
    "PROJECT_IDEAS.md:项目ideas"
    "PROGRESS_TRACKER.md:进度跟踪"
    "CODE_EXAMPLES.md:代码示例"
    "PRODUCTION_CHECKLIST.md:生产清单"
    "INTERVIEW_QUESTIONS.md:面试问题"
    "GLOSSARY.md:术语表"
    "FAQ.md:常见问题"
    "COMMON_PITFALLS.md:常见错误"
    "COURSE_SUMMARY.md:课程总结"
    "DELIVERY_CHECKLIST.md:交付清单"
    "FINAL_STATUS.md:最终状态"
)

for resource in "${resources[@]}"; do
    file="${resource%%:*}"
    desc="${resource##*:}"
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo "✅ $file ($lines 行) - $desc"
    else
        echo "❌ $file - 缺失"
    fi
done

echo ""
echo "6. 数据一致性检查"
echo "----------------------------"
# 检查 INDEX.md 中的行数是否准确
if [ -f "INDEX.md" ]; then
    echo "检查 INDEX.md 中文件大小排序..."
fi

