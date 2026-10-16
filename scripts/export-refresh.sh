#!/usr/bin/env bash
#
# 在【源机器】上重新导出配置，直接写进 git 工作副本。产出即为可公开状态：
#   · 抹掉 .zshrc 里所有硬编码密钥
#   · 抹掉证书签名身份（真实姓名 + Team ID）
#   · plist 绝对路径 → @@SRC_HOME@@ 占位符
#   · 剥离 iTerm2 机器状态 key（安装 ID / 窗口位置 / 系统版本 …）
#
#   ./scripts/export-refresh.sh                      # 默认 ~/Developer/iterm2-setup
#   ./scripts/export-refresh.sh /path/to/repo        # 指定仓库目录
#
set -Eeuo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

DEST="${1:-$HOME/Developer/iterm2-setup}"
SRC_HOME="$HOME"
ITERM_SUPPORT="$HOME/Library/Application Support/iTerm2"
PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"

say(){ printf '\033[1;34m▸\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m!\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "只支持 macOS。"
[[ -f "$PLIST" ]] || die "找不到 $PLIST"
mkdir -p "$DEST"/{iterm2/DynamicProfiles,dotfiles,extras/swiftbar,scripts}

# ── 1. iTerm2 偏好 plist ─────────────────────────────────
say "导出 iTerm2 偏好设置（匿名化 + 剥离机器状态）"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
plutil -convert xml1 -o "$TMP/iterm2.plist" "$PLIST"
python3 - "$TMP/iterm2.plist" "$SRC_HOME" <<'PY'
import plistlib, sys, pathlib
path, home = pathlib.Path(sys.argv[1]), sys.argv[2]
raw = path.read_text().replace(home, "@@SRC_HOME@@")
path.write_text(raw)
d = plistlib.loads(raw.encode())
STRIP = {"NoSyncInstallationId","NoSyncSavedWindowPositions","NoSyncRestoreWindowsCount",
 "NoSyncLastShutdownWasClean","NoSyncAllAppVersions","NoSyncLastOSVersion",
 "NoSyncLaunchExperienceControllerRunCount","NoSyncLastSystemPythonVersionRequirement",
 "NoSyncLastTipTime","NoSyncNextAnnoyanceTime","NoSyncTipsToNotShow",
 "NoSyncTipOfTheDayEligibilityBeganTime","NoSyncSuppressedAlertsCatalog",
 "NoSyncPermissionToShowTip","NoSyncIgnoreSystemWindowRestoration",
 "NoSyncPersistentRateLimitedUpdates","SUHasLaunchedBefore"}
n = 0
for k in list(d):
    if k in STRIP or k.startswith("NSWindow Frame"):
        del d[k]; n += 1
path.write_bytes(plistlib.dumps(d))
print(f"  剥离 {n} 个机器状态 key，剩余 {len(d)} 个顶层 key")
PY
cp "$TMP/iterm2.plist" "$DEST/iterm2/com.googlecode.iterm2.plist"
ok "com.googlecode.iterm2.plist"

if compgen -G "$ITERM_SUPPORT/DynamicProfiles/*.json" >/dev/null; then
  cp "$ITERM_SUPPORT"/DynamicProfiles/*.json "$DEST/iterm2/DynamicProfiles/"
  ok "动态 Profile：$(ls "$DEST/iterm2/DynamicProfiles" | tr '\n' ' ')"
else
  warn "没有找到动态 Profile"
fi

# ── 2. shell 配置（脱敏）─────────────────────────────────
say "导出 shell 配置（自动脱敏）"
[[ -f ~/.p10k.zsh ]] && cp ~/.p10k.zsh "$DEST/dotfiles/p10k.zsh"
[[ -f ~/.zprofile ]] && cp ~/.zprofile "$DEST/dotfiles/zprofile"

if [[ -f ~/.zshrc ]]; then
  sed -E \
    -e 's@^export[[:space:]]+([A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[A-Za-z0-9_]*)=.*@# [已脱敏] 原机在此硬编码了 \1，请改用 ~/.config/secrets.env@' \
    -e 's@^export[[:space:]]+[A-Za-z0-9_]*SIGN_IDENTITY=.*@# [已脱敏] 证书签名身份含真实姓名与 Team ID，请改用 ~/.config/secrets.env@' \
    -e 's@Developer ID Application:[^"]*@Developer ID Application: <已脱敏>@g' \
    ~/.zshrc > "$DEST/dotfiles/zshrc"
  # 去掉任何自我追加的 echo ... >> ~/.zshrc（历史遗留 bug）
  grep -v "^[[:space:]]*echo .*>> ~/\.zshrc" "$DEST/dotfiles/zshrc" > "$TMP/z" && mv "$TMP/z" "$DEST/dotfiles/zshrc"
  if grep -q "已脱敏" "$DEST/dotfiles/zshrc"; then
    warn "检测到密钥 / 证书身份并已抹掉，请 diff 一下 dotfiles/zshrc"
    grep -q "secrets.env" "$DEST/dotfiles/zshrc" || \
      printf '\n[[ -f ~/.config/secrets.env ]] && source ~/.config/secrets.env\n' >> "$DEST/dotfiles/zshrc"
  fi
  ok "dotfiles/ 完成"
fi

# ── 3. Brewfile（探测结果只用于比对，不覆盖手写版本）─────
say "探测本机 Homebrew 包"
NORM='s/^[[:space:]]*(brew|cask|tap)[[:space:]]+"([^"]+)".*/\1 "\2"/p'
: > "$TMP/detected.txt"
if command -v brew >/dev/null 2>&1; then
  export HOMEBREW_NO_AUTO_UPDATE=1
  CASKS="$(brew list --cask    2>/dev/null || true)"
  FORMULAE="$(brew list --formula 2>/dev/null || true)"
  for c in iterm2 font-meslo-for-powerlevel10k font-jetbrains-mono-nerd-font swiftbar; do
    if printf '%s\n' "$CASKS" | grep -qx -- "$c"; then echo "cask \"$c\"" >> "$TMP/detected.txt"; fi
  done
  for f in bat eza fzf gh uv ffmpeg; do
    if printf '%s\n' "$FORMULAE" | grep -qx -- "$f"; then echo "brew \"$f\"" >> "$TMP/detected.txt"; fi
  done
  sort -o "$TMP/detected.txt" "$TMP/detected.txt"
  ok "本机探测到 $(wc -l < "$TMP/detected.txt" | tr -d ' ') 个包"
else
  warn "没找到 brew，跳过 Brewfile 比对"
fi

if [[ -f "$DEST/Brewfile" ]]; then
  sed -nE "$NORM" "$DEST/Brewfile" | sort > "$TMP/committed.txt"
  # 只关心「本机有、但 Brewfile 里没写」的包（反之是允许的，比如手动装的 iTerm2）
  MISSING="$(comm -13 "$TMP/committed.txt" "$TMP/detected.txt" 2>/dev/null || true)"
  if [[ -z "$MISSING" ]]; then
    ok "Brewfile 已覆盖本机全部包（保留手写注释版）"
  else
    warn "本机新装了这些包，但 Brewfile 里没有，建议手动补进去："
    echo "$MISSING" | sed 's/^/     + /'
  fi
else
  { echo "# 由 export-refresh.sh 于 $(date '+%F %H:%M') 生成"
    echo "# 用法： brew bundle install --file=Brewfile"
    cat "$TMP/detected.txt"; } > "$DEST/Brewfile"
  ok "已生成 Brewfile"
fi

# ── 4. SwiftBar（可选）───────────────────────────────────
if compgen -G "$HOME/SwiftBarPlugins/*.sh" >/dev/null; then
  cp "$HOME"/SwiftBarPlugins/*.sh "$DEST/extras/swiftbar/" && chmod +x "$DEST/extras/swiftbar/"/*.sh
  ok "SwiftBar 脚本已导出"
fi

# ── 5. 框架文件（README / install.sh / 脚本 / 模板）──────
say "同步框架文件"
if [[ "$REPO_ROOT" -ef "$DEST" ]]; then
  ok "就在仓库内运行，无需同步"
else
  _sync() {  # _sync <相对路径>
    local s="$REPO_ROOT/$1" d="$DEST/$1"
    [[ -f "$s" ]] || return 0
    [[ -e "$d" && "$s" -ef "$d" ]] && return 0
    mkdir -p "$(dirname "$d")"
    cp "$s" "$d"
  }
  _sync install.sh; _sync README.md; _sync MANIFEST.txt; _sync .gitignore
  _sync scripts/privacy-scan.sh; _sync scripts/export-refresh.sh
  _sync dotfiles/secrets.env.example
  ok "框架文件已同步"
fi
[[ -f "$DEST/install.sh" ]] && chmod +x "$DEST/install.sh"
for s in "$DEST"/scripts/*.sh "$DEST"/extras/swiftbar/*.sh; do
  [[ -f "$s" ]] && chmod +x "$s"
done

# ── 6. 自检 ──────────────────────────────────────────────
say "推送前自检"
if "$DEST/scripts/privacy-scan.sh" "$DEST"; then
  echo
  ok "→ $DEST"
  cat <<NEXT

下一步：
  cd "$DEST"
  git add -A && git status          # 先看一眼改了什么
  git commit -m "update: \$(date +%F)"
  git push
NEXT
else
  warn "自检发现可疑内容，已导出但请先处理再 push：$DEST"
  exit 1
fi
