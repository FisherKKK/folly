#!/bin/bash
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Folly 课程内容完整性检查                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

issues=0

echo "🔍 检查 1: Day 文件是否有基础版和增强版标记"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for i in {01..14}; do
    basic_file=$(ls Day${i}_*.md 2>/dev/null | grep -v "_增强版" | head -1)
    enhanced_file=$(ls Day${i}_*_增强版.md 2>/dev/null | head -1)
    
    if [ -f "$basic_file" ]; then
        if ! grep -q "^# " "$basic_file"; then
            echo "⚠️  $basic_file 缺少标题"
            ((issues++))
        fi
    fi
    
    if [ -f "$enhanced_file" ]; then
        if ! grep -q "^# " "$enhanced_file"; then
            echo "⚠️  $enhanced_file 缺少标题"
            ((issues++))
        fi
    fi
done
echo "✅ Day 文件标题检查完成"
echo ""

echo "🔍 检查 2: README.md 必要章节"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
required_sections=("课程概览" "快速开始" "课程大纲" "学习路径")
for section in "${required_sections[@]}"; do
    if ! grep -q "$section" README.md; then
        echo "⚠️  README.md 缺少章节: $section"
        ((issues++))
    fi
done
echo "✅ README.md 章节检查完成"
echo ""

echo "🔍 检查 3: INDEX.md 必要索引"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
required_indexes=("按功能分类" "按天数索引" "按组件查找" "按难度查找")
for index in "${required_indexes[@]}"; do
    if ! grep -q "$index" INDEX.md; then
        echo "⚠️  INDEX.md 缺少索引: $index"
        ((issues++))
    fi
done
echo "✅ INDEX.md 索引检查完成"
echo ""

echo "🔍 检查 4: 代码示例数量"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "CODE_EXAMPLES.md" ]; then
    example_count=$(grep -c '```' CODE_EXAMPLES.md)
    if [ $example_count -lt 50 ]; then
        echo "⚠️  CODE_EXAMPLES.md 代码示例数量较少: $example_count"
        ((issues++))
    else
        echo "✅ CODE_EXAMPLES.md 包含充足的代码示例: $example_count 个代码块"
    fi
fi
echo ""

echo "🔍 检查 5: 词汇表完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "GLOSSARY.md" ]; then
    term_count=$(grep -c "^##" GLOSSARY.md)
    if [ $term_count -lt 50 ]; then
        echo "⚠️  GLOSSARY.md 术语数量较少: $term_count"
        ((issues++))
    else
        echo "✅ GLOSSARY.md 包含充足的术语: $term_count 个"
    fi
fi
echo ""

echo "🔍 检查 6: 面试问题完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "INTERVIEW_QUESTIONS.md" ]; then
    question_count=$(grep -c "^###" INTERVIEW_QUESTIONS.md)
    if [ $question_count -lt 15 ]; then
        echo "⚠️  INTERVIEW_QUESTIONS.md 问题数量较少: $question_count"
        ((issues++))
    else
        echo "✅ INTERVIEW_QUESTIONS.md 包含充足的问题: $question_count 个"
    fi
fi
echo ""

echo "🔍 检查 7: FAQ 完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "FAQ.md" ]; then
    faq_count=$(grep -c "^##" FAQ.md)
    if [ $faq_count -lt 20 ]; then
        echo "⚠️  FAQ.md 问题数量较少: $faq_count"
        ((issues++))
    else
        echo "✅ FAQ.md 包含充足的常见问题: $faq_count 个"
    fi
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
if [ $issues -eq 0 ]; then
    echo "║              ✅ 内容完整性检查通过！                       ║"
else
    echo "║           ⚠️  发现 $issues 个问题                             ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"

