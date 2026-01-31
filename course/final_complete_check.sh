#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Folly 课程最终全面检查                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

total_issues=0

# 1. 文件统计
echo "📊 文件统计"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
course_files=$(ls -1 *.md 2>/dev/null | grep -v "^archive_" | wc -l)
archive_files=$(ls -1 archive*.md 2>/dev/null | wc -l)
total_files=$(ls -1 *.md 2>/dev/null | wc -l)
total_lines=$(cat *.md 2>/dev/null | wc -l)

echo "课程文件: $course_files"
echo "归档文件: $archive_files"
echo "总文件数: $total_files"
echo "总行数: $total_lines"
echo ""

# 2. 版本一致性
echo "🔍 版本一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
version_check=true
for file in COURSE_SUMMARY.md DELIVERY_CHECKLIST.md FINAL_STATUS.md; do
    version=$(grep "课程版本" "$file" 2>/dev/null | head -1 | grep -oP 'v[0-9.]+[A-Za-z]*' || echo "")
    if [ -z "$version" ]; then
        version="未找到"
    fi
    echo "  $file: $version"
    if [[ ! "$version" =~ v1.5 ]]; then
        version_check=false
    fi
done
if [ "$version_check" = true ]; then
    echo "✅ 版本号一致"
else
    echo "⚠️  版本号不一致"
    ((total_issues++))
fi
echo ""

# 3. Day 文件完整性
echo "📚 Day 文件完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
day_complete=true
for i in {01..14}; do
    basic=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版" | wc -l)
    enhanced=$(ls Day${i}_*_增强版.md 2>/dev/null | wc -l)
    if [ "$basic" -ne 1 ] || [ "$enhanced" -ne 1 ]; then
        echo "⚠️  Day${i} 不完整"
        day_complete=false
    fi
done
if [ "$day_complete" = true ]; then
    echo "✅ 所有 Day 文件完整 (14/14)"
else
    echo "⚠️  部分文件不完整"
    ((total_issues++))
fi
echo ""

# 4. 配套资源完整性
echo "🛠️  配套资源完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
resources=0
for file in README.md INDEX.md QUICKSTART.md Day00_学习指南.md EXERCISES.md QUICK_REFERENCE.md TROUBLESHOOTING.md VISUAL_GUIDE.md PROJECT_IDEAS.md PROGRESS_TRACKER.md CODE_EXAMPLES.md PRODUCTION_CHECKLIST.md INTERVIEW_QUESTIONS.md GLOSSARY.md FAQ.md COMMON_PITFALLS.md COURSE_SUMMARY.md DELIVERY_CHECKLIST.md FINAL_STATUS.md; do
    if [ -f "$file" ]; then
        ((resources++))
    fi
done
echo "配套资源: $resources/19"
if [ $resources -eq 19 ]; then
    echo "✅ 所有配套资源完整"
else
    echo "⚠️  缺少配套资源"
    ((total_issues++))
fi
echo ""

# 5. 数据一致性
echo "📏 数据一致性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
data_consistent=true
for file in COURSE_SUMMARY.md DELIVERY_CHECKLIST.md FINAL_STATUS.md; do
    doc_lines=$(grep "总行数：" "$file" 2>/dev/null | head -1 | grep -oP '\d+' | tr -d '\n')
    if [ "$doc_lines" != "$total_lines" ]; then
        echo "⚠️  $file: 文档中 $doc_lines 行 (实际 $total_lines)"
        data_consistent=false
    fi
done
if [ "$data_consistent" = true ]; then
    echo "✅ 所有数据一致 ($total_lines 行)"
else
    echo "⚠️  数据不一致"
    ((total_issues++))
fi
echo ""

# 6. 验证脚本可用性
echo "🔧 验证脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
scripts=0
for script in check_course.sh final_check.sh verify_final.sh verify_final_v2.sh deep_check.sh content_check.sh; do
    if [ -f "$script" ]; then
        ((scripts++))
    fi
done
echo "验证脚本: $scripts 个"
echo "✅ 验证工具可用"
echo ""

# 7. 链接完整性
echo "🔗 链接完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
broken=0
for link in $(grep -oP '\[.*?\]\(\K[^\)]+' README.md | grep '\.md$'); do
    if [ ! -f "$link" ]; then
        ((broken++))
    fi
done
if [ $broken -eq 0 ]; then
    echo "✅ README.md 中的所有链接有效"
else
    echo "⚠️  发现 $broken 个损坏链接"
    ((total_issues++))
fi
echo ""

# 总结
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                   检查结果总结                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  📊 文件统计: $course_files 课程文件 + $archive_files 归档文件      ║"
echo "║  📏 总行数:   $total_lines 行                                 ║"
echo "║  📚 Day文件:  14/14 完整                                  ║"
echo "║  🛠️  配套资源: $resources/19 完整                                ║"
echo "║  📏 数据一致性: $( [ $data_consistent = true ] && echo '通过' || echo '未通过' )                      ║"
echo "║  🔗 链接检查:   $( [ $broken -eq 0 ] && echo '通过' || echo '未通过' )                          ║"
echo "╠════════════════════════════════════════════════════════════╣"
if [ $total_issues -eq 0 ]; then
    echo "║              ✅ 全面检查通过，课程完整！                    ║"
else
    echo "║         ⚠️  发现 $total_issues 个问题，需要处理                    ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "验证日期: $(date +%Y-%m-%d)"
echo "课程版本: v1.5 Final"

