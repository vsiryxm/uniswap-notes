#!/bin/bash

# 创建一个记录文件
mkdir -p docs

# 将信息写入文件
{
  echo "# Uniswap 代码版本信息"
  echo ""
  echo "## v3-core"
  cd v3/v3-core
  echo "分支: $(git branch --show-current)"
  echo "提交: $(git log -1 --format="%H %ad %s" --date=short)"
  echo "标签: $(git describe --tags 2>/dev/null || echo '无标签')"
  echo ""
  echo "## v3-periphery"
  cd ../v3-periphery
  echo "分支: $(git branch --show-current)"
  echo "提交: $(git log -1 --format="%H %ad %s" --date=short)" 
  echo "标签: $(git describe --tags 2>/dev/null || echo '无标签')"
} > docs/version-info.md