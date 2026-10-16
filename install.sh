#!/usr/bin/env bash
#
# 在新 Mac 上一键复刻 iTerm2 + zsh/Powerlevel10k 环境
#
#   ./install.sh              # 全部安装
#   ./install.sh --dry-run    # 只看会做什么，不动任何文件
#   ./install.sh --no-brew    # 跳过 Homebrew 包安装
#   ./install.sh --only-iterm # 只恢复 iTerm2 偏好与动态 Profile
#
# 所有被覆盖的文件都会先备份到 ~/iterm2-restore-backup-<时间戳>/
#
set -Eeuo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_PLACEHOLDER="@@SRC_HOME@"                      # plist 里的源机器 home 路径占位符
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/iterm2-restore-backup-$TS"
ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
ITERM_SUPPORT="$HOME/Library/Application Support/iTerm2"

DRY=0; DO_BREW=1; DO_SHELL=1; DO_ITERM=1; DO_EXTRAS=1
ONLY=""

for a in "$@"; do
  case "$a" in
    --dry-run)    DRY=1 ;;
    --no-brew)    DO_BREW=0 ;;
    --no-shell)   DO_SHELL=0 ;;
    --no-iterm)   DO_ITERM=0 ;;
    --no-extras)  DO_EXTRAS=0 ;;
    --only-iterm) ONLY=iterm ;;
    --only-shell) ONLY=shell ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $a（用 --help 看用法）" >&2; exit 2 ;;
  esac
done
if [[ "$ONLY" == iterm ]]; then DO_BREW=0; DO_SHELL=0; DO_EXTRAS=0; DO_ITERM=1; fi
if [[ "$ONLY" == shell ]]; then DO_BREW=0; DO_SHELL=1; DO_EXTRAS=0; DO_ITERM=0; fi

# ── 小工具 ────────────────────────────────────────────────
say()  { printf '\033[1;34m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if (( DRY )); then echo "  [dry-run] $*"; else eval "$@"; fi; }

bak() {  # bak <file>
  [[ -e "$1" ]] || return 0
  if (( DRY )); then echo "  [dry-run] backup $1"; return 0; fi
  mkdir -p "$BACKUP_DIR"
  local dest="$BACKUP_DIR/$(echo "${1/#$HOME/~}" | tr '/' '_')"
  cp -Rp "$1" "$dest"
  ok "已备份 $1 → $dest"
}

[[ "$(uname)" == "Darwin" ]] || die "这个脚本只支持 macOS。"
(( DRY )) && warn "DRY-RUN 模式：不会真正写入任何文件。"

# ── 1. Homebrew + 包 + 字体 ───────────────────────────────
if (( DO_BREW )); then
  say "安装 Homebrew 包与字体"
  if ! command -v brew >/dev/null 2>&1; then
    warn "没检测到 Homebrew，先装它："
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo "  然后重跑： $0"
  else
    run "brew bundle install --file='$BUNDLE_DIR/Brewfile'"
    ok "Homebrew 包就绪（bat / eza / fzf / gh / uv / ffmpeg / iTerm2 / 字体）"
  fi
fi

# ── 2. oh-my-zsh + 插件 + 主题 ────────────────────────────
if (( DO_SHELL )); then
  say "配置 oh-my-zsh / Powerlevel10k / 插件"
  export RUNZSH=no CHSH=no KEEP_ZSHRC=yes
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    run "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
  else
    ok "oh-my-zsh 已存在，跳过安装"
  fi

  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  clone_if_missing() {  # clone_if_missing <url> <dir>
    if [[ -d "$2/.git" ]]; then ok "已存在 $(basename "$2")，跳过"; return 0; fi
    run "git clone --depth=1 '$1' '$2'"
  }
  clone_if_missing https://github.com/romkatv/powerlevel10k.git          "$ZSH_CUSTOM/themes/powerlevel10k"
  clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  clone_if_missing https://github.com/zsh-users/zsh-completions.git      "$ZSH_CUSTOM/plugins/zsh-completions"
  clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  # dotfiles
  bak "$HOME/.zshrc";    run "cp '$BUNDLE_DIR/dotfiles/zshrc' '$HOME/.zshrc'"
  bak "$HOME/.p10k.zsh"; run "cp '$BUNDLE_DIR/dotfiles/p10k.zsh' '$HOME/.p10k.zsh'"
  ok "已写入 ~/.zshrc 与 ~/.p10k.zsh"

  # .zprofile：不整体覆盖，只确保 brew shellenv 在
  if [[ ! -f "$HOME/.zprofile" ]]; then
    run "cp '$BUNDLE_DIR/dotfiles/zprofile' '$HOME/.zprofile'"
  elif ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    bak "$HOME/.zprofile"
    run "printf '\n%s\n' 'eval \"\$(/opt/homebrew/bin/brew shellenv zsh)\"' >> '$HOME/.zprofile'"
  else
    ok "~/.zprofile 已有 brew shellenv，保持不变"
  fi

  # 敏感变量：只在还没有 secrets.env 时创建，绝不覆盖已有文件
  mkdir -p "$HOME/.config"
  if [[ ! -f "$HOME/.config/secrets.env" ]]; then
    run "cp '$BUNDLE_DIR/dotfiles/secrets.env.example' '$HOME/.config/secrets.env'"
    run "chmod 600 '$HOME/.config/secrets.env'"
    warn "已创建 ~/.config/secrets.env（权限 600），里面还是占位值 —— 记得填真实内容。"
  else
    ok "~/.config/secrets.env 已存在，保持不动"
  fi
fi

# ── 3. iTerm2 偏好设置 + 动态 Profile ─────────────────────
if (( DO_ITERM )); then
  say "恢复 iTerm2 偏好设置与 3 套主题 Profile"
  if pgrep -x iTerm2 >/dev/null 2>&1; then
    warn "iTerm2 正在运行 —— 它会用内存里的旧配置覆盖你导入的设置。"
    read -r -p "  现在退出 iTerm2 并继续？[y/N] " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || die "请先完全退出 iTerm2（⌘Q），再重跑 $0 --only-iterm"
    run "osascript -e 'quit app \"iTerm\"' && sleep 3"
  fi

  # 动态 Profile（纯文件，随时可放）
  run "mkdir -p '$ITERM_SUPPORT/DynamicProfiles'"
  run "cp '$BUNDLE_DIR/iterm2/DynamicProfiles/codex-themes.json' '$ITERM_SUPPORT/DynamicProfiles/'"
  ok "已放入 codex-themes.json（Catppuccin Mocha / Gruvbox Dark / Everforest Dark Med）"

  # 偏好 plist：重写绝对路径 → defaults import（走 cfprefsd，避免缓存问题）
  local_tmp="$(mktemp -d)"
  sed -e "s|$SRC_PLACEHOLDER|$HOME|g" "$BUNDLE_DIR/iterm2/com.googlecode.iterm2.plist" \
    > "$local_tmp/iterm2.plist"
  grep -q "$SRC_PLACEHOLDER" "$local_tmp/iterm2.plist" && warn "占位符没被完全替换，请手动检查 plist"
  if (( DRY )); then
    echo "  [dry-run] defaults import com.googlecode.iterm2 <重写路径后的 plist>"
  else
    bak "$ITERM_PLIST"
    defaults import com.googlecode.iterm2 "$local_tmp/iterm2.plist"
    rm -rf "$local_tmp"
    ok "已导入 com.googlecode.iterm2 偏好设置"
  fi
fi

# ── 4. 可选：SwiftBar 菜单栏脚本 ──────────────────────────
if (( DO_EXTRAS )); then
  say "（可选）安装 SwiftBar 菜单栏脚本"
  run "mkdir -p '$HOME/SwiftBarPlugins'"
  run "cp '$BUNDLE_DIR'/extras/swiftbar/*.sh '$HOME/SwiftBarPlugins/' && chmod +x '$HOME/SwiftBarPlugins'/*.sh"
  echo "  打开 SwiftBar → 选择插件目录为 ~/SwiftBarPlugins（只需设一次）"
fi

# ── 完成 ─────────────────────────────────────────────────
echo
ok "全部完成。"
if [[ -d "$BACKUP_DIR" ]]; then echo "   备份目录： $BACKUP_DIR"; fi
cat <<'NEXT'

下一步：
  1. 打开 iTerm2 → 应该已经是原来的样子（MesloLGS NF 13pt + 状态栏）
  2. 切主题：Profiles（⌘O）→ Catppuccin Mocha / Gruvbox Dark / Everforest Dark Med
     想开机默认某个主题：Settings → Profiles → Other Actions → Set as Default
  3. 新开一个 shell，若提示符图标是方块 → 说明字体没装好：
       brew install --cask font-meslo-for-powerlevel10k
     或跑 `p10k configure` 重新生成 ~/.p10k.zsh
  4. fzf 快捷键：Ctrl-R 搜历史 / Ctrl-T 找文件 / Alt-C 跳目录
NEXT
