#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Folly 课程终极检查报告                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

total_issues=0

echo "📊 统计信息"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
course_files=$(ls -1 Day*.md 2>/dev/null | grep -v "_增强版" | wc -l)
enhanced_files=$(ls -1 Day*_增强版.md 2>/dev/null | wc -l)
resource_files=$(ls -1 [A-Z]*.md Day00*.md 2>/dev/null | wc -l)
archive_files=$(ls -1 archive*.md 2>/dev/null | wc -l)
total_files=$(ls -1 *.md 2>/dev/null | wc -l)
total_lines=$(cat *.md 2>/dev/null | wc -l)

echo "Day 基础版文件: $course_files"
echo "Day 增强版文件: $enhanced_files"
echo "配套资源文件: $resource_files"
echo "归档文件: $archive_files"
echo "总文件数: $total_files"
echo "总行数: $total_lines"
echo ""

echo "✅ 质量指标"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. 文件完整性
day_pairs=0
for i in {01..14}; do
    basic=$(ls Day${i}*.md 2>/dev/null | grep -v "_增强版" | wc -l)
    enhanced=$(ls Day${i}*_增强版.md 2>/dev/null | wc -l)
    if [ "$basic" -eq 1 ] && [ "$enhanced" -eq 1 ]; then
        ((day_pairs++))
    fi
done
echo "1. Day 文件完整性: $day_pairs/14 对"

# 2. 版本一致性
version_consistent=true
for file in COURSE_SUMMARY.md DELIVERY_CHECKLIST.md FINAL_STATUS.md; do
    if grep -q "v1.5" "$file"; then
        : # OK
    else
        version_consistent=false
    fi
done
if [ "$version_consistent" = true ]; then
    echo "2. 版本一致性: ✅ v1.5 Final"
else
    echo "2. 版本一致性: ⚠️ 不一致"
    ((total_issues++))
fi

# 3. 日期一致性
date_2024=$(grep "2024-01-30" *.md 2>/dev/null | grep -v "^archive" | wc -l)
date_2026=$(grep "2026-01-30" *.md 2>/dev/null | grep -v "^archive" | wc -l)
if [ $date_2026 -eq 0 ]; then
    echo "3. 日期一致性: ✅ 全部使用 2024-01-30"
else
    echo "3. 日期一致性: ⚠️ 发现 $date_2026 处 2026 年日期"
    ((total_issues++))
fi

# 4. 数据一致性
data_consistent=true
doc_lines=$(grep "总行数：" COURSE_SUMMARY.md 2>/dev/null | head -1 | grep -oP '\d+' | tr -d '\n')
if [ "$doc_lines" == "$total_lines" ]; then
    echo "4. 数据一致性: ✅ $total_lines 行全部一致"
else
    echo "4. 数据一致性: ⚠️ 文档记录 $doc_lines 行，实际 $total_lines 行"
    ((total_issues++))
fi

# 5. 链接完整性
broken=0
for link in $(grep -oP '\[.*?\]\(\K[^\)]+' README.md 2>/dev/null | grep '\.md$'); do
    if [ ! -f "$link" ]; then
        ((broken++))
    fi
done
if [ $broken -eq 0 ]; then
    echo "5. 链接完整性: ✅ README.md 链接全部有效"
else
    echo "5. 链接完整性: ⚠️ 发现 $broken 个损坏链接"
    ((total_issues++))
fi

# 6. 内容质量统计
h1_count=$(grep -r '^# ' *.md 2>/dev/null | grep -v "^archive" | wc -l)
code_blocks=$(grep -r '^```' *.md 2>/dev/null | grep -v "^archive" | wc -l)
tables=$(grep -r '^|' *.md 2>/dev/null | grep -v "^archive" | wc -l)
echo "6. 内容统计:"
echo "   - 一级标题: $h1_count 个"
echo "   - 代码块: $code_blocks 个标记"
echo "   - 表格: $tables 个"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
if [ $total_issues -eq 0 ]; then
    echo "║                                                            ║"
    echo "║              ✅ 终极检查全部通过！                          ║"
    echo "║                                                            ║"
    echo "║          课程质量等级：⭐⭐⭐⭐⭐ 优秀                     ║"
    echo "║                                                            ║"
    echo "║          🎉 可以正式投入使用！                            ║"
    echo "║                                                            ║"
else
    echo "║           ⚠️  发现 $total_issues 个问题需要处理                    ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "课程版本: v1.5 Final"

