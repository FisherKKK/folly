#!/bin/bash
echo "=== 课程文件分析 ==="
echo ""

# 统计不包括 COURSE_COMPLETION_REPORT.md 的文件和行数
course_files=$(ls -1 *.md 2>/dev/null | grep -v "^archive_" | grep -v "^COURSE_COMPLETION_REPORT.md" | wc -l)
course_lines=$(cat *.md 2>/dev/null | grep -v "^COURSE_COMPLETION_REPORT.md" | wc -l)

# 统计归档和附加文件
archive_count=$(ls -1 archive*.md 2>/dev/null | wc -l)
report_count=$(ls -1 COURSE_COMPLETION_REPORT.md 2>/dev/null | wc -l)
extra_files=$((archive_count + report_count))

echo "📚 课程文件（不含报告和归档）: $course_files 个"
echo "📦 归档和附加文件: $extra_files 个"
echo "📊 总文件数: $((course_files + extra_files)) 个"
echo ""
echo "📏 课程文件行数: $course_lines"
echo "📏 COURSE_COMPLETION_REPORT.md: $(wc -l < COURSE_COMPLETION_REPORT.md 2>/dev/null || echo 0) 行"
echo "📏 总行数: $(cat *.md 2>/dev/null | wc -l) 行"
echo ""

# 检查是否应该将 COURSE_COMPLETION_REPORT.md 归档
echo "=== 建议的文件分类 ==="
echo "1. 将 COURSE_COMPLETION_REPORT.md 归档"
echo "2. 更新统计数据为："
echo "   - 课程文件: 48 个"
echo "   - 归档文件: 2 个 (archive_00_学习指南.md + archive_COURSE_COMPLETION_REPORT.md)"
echo "   - 总文件数: 50 个"
echo "   - 总行数: 26,510 行"

