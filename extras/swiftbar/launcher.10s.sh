#!/bin/bash
# <xbar.title>脚本启动器</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Codex</xbar.author>
# <xbar.desc>扫描脚本目录，把每个脚本变成菜单栏里的一键操作</xbar.desc>
# <xbar.dependencies>bash,find,sed</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

SCRIPTS_DIR="${SWIFTBAR_SCRIPTS_DIR:-$HOME/SwiftBarScripts}"

# 读取脚本头部注释里的指令，例如:  # swiftbar:title=我的脚本
directive() {
  /usr/bin/sed -n "s/^[[:space:]]*#[[:space:]]*swiftbar:$2[[:space:]]*=[[:space:]]*//p" "$1" 2>/dev/null | /usr/bin/head -n 1
}

count=0
if [ -d "$SCRIPTS_DIR" ]; then
  count=$(/usr/bin/find "$SCRIPTS_DIR" -type f ! -name '.*' ! -name '*.md' ! -name '*.txt' 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')
fi

# ---------- Header（菜单栏上显示的内容） ----------
if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "脚本 | sfimage=exclamationmark.triangle.fill | color=orange | tooltip=$SCRIPTS_DIR 不存在"
elif [ "$count" -eq 0 ]; then
  echo "脚本 | sfimage=hammer | color=gray | tooltip=$SCRIPTS_DIR 是空的"
else
  echo "脚本 $count | sfimage=hammer.fill"
fi
echo "---"

# ---------- 单个脚本 -> 一个菜单项 ----------
emit() {
  local f="$1" indent="$2"
  local title term icon key interp href params alt_term

  title=$(directive "$f" title)
  [ -z "$title" ] && title="$(basename "$f")"
  # 去掉常见后缀，让菜单文字更干净
  for ext in sh bash zsh py rb js osascript command term; do title="${title%.$ext}"; done
  title=$(printf '%s' "$title" | /usr/bin/tr '|' '/' | /usr/bin/tr '_' ' ')

  # 终端里跑还是后台跑：指令优先，其次看文件名约定 (.term. / .command)
  term=$(directive "$f" terminal)
  if [ -z "$term" ]; then
    case "$f" in *.term.*|*.command) term=true ;; *) term=false ;; esac
  fi

  icon=$(directive "$f" icon)
  key=$(directive "$f" key)
  interp=$(directive "$f" interpreter)
  href=$(directive "$f" href)

  params=""
  [ -n "$icon" ] && params="$params sfimage=$icon"
  [ -n "$key" ]  && params="$params shortcut=$key"

  if [ -n "$href" ]; then
    echo "${indent}${title} | href=\"$href\" tooltip=\"$f\"$params"
    return
  fi

  if [ -n "$interp" ]; then
    echo "${indent}${title} | bash=\"$interp\" param1=\"$f\" terminal=$term refresh=true tooltip=\"$f\"$params"
  else
    echo "${indent}${title} | bash=\"$f\" terminal=$term refresh=true tooltip=\"$f\"$params"
  fi

  # 按住 Option 点这一项 -> 用另一种方式运行（终端 <-> 后台）
  if [ "$term" = "true" ]; then alt_term=false; else alt_term=true; fi
  echo "${indent}${title} | alternate=true bash=\"$f\" terminal=$alt_term refresh=true tooltip=\"Option+点击：换一种方式运行\""
}

# ---------- 递归遍历目录，子目录变成子菜单 ----------
walk() {
  local dir="$1" depth="$2" indent="" i=0 sub f
  [ "$depth" -gt 4 ] && return
  while [ "$i" -lt "$depth" ]; do indent="${indent}--"; i=$((i+1)); done

  while IFS= read -r sub; do
    [ -z "$sub" ] && continue
    echo "${indent}$(basename "$sub") | sfimage=folder.fill"
    walk "$sub" $((depth+1))
  done < <(/usr/bin/find "$dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | /usr/bin/sort)

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    emit "$f" "$indent"
  done < <(/usr/bin/find "$dir" -mindepth 1 -maxdepth 1 -type f ! -name '.*' ! -name '*.md' ! -name '*.txt' 2>/dev/null | /usr/bin/sort)
}

if [ -d "$SCRIPTS_DIR" ]; then
  walk "$SCRIPTS_DIR" 0
  [ "$count" -eq 0 ] && echo "把脚本丢进 $SCRIPTS_DIR 就会出现在这里 | color=gray size=12 disabled=true"
else
  echo "目录不存在 | color=red disabled=true"
  echo "创建 $SCRIPTS_DIR | sfimage=folder.badge.plus bash=/bin/mkdir param1=-p param2=\"$SCRIPTS_DIR\" terminal=false refresh=true"
fi

echo "---"
echo "打开脚本文件夹 | sfimage=folder.badge.gearshape bash=/usr/bin/open param1=\"$SCRIPTS_DIR\" terminal=false"
echo "修复执行权限 | sfimage=lock.open bash=/bin/chmod param1=-R param2=+x param3=\"$SCRIPTS_DIR\" terminal=false refresh=true"
echo "重新加载所有插件 | sfimage=arrow.clockwise bash=/usr/bin/open param1=-g param2=swiftbar://refreshallplugins terminal=false"
