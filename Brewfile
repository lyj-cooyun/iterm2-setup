# 复刻原机环境所需的 Homebrew 包
# 用法： brew bundle install --file=Brewfile
# 说明： 顺序无关；已装的会自动跳过

# ── 终端本体 ──────────────────────────────
cask "iterm2"                                # 原机版本 3.7.4

# ── 字体（Powerlevel10k 图标 + Nerd Font 图标）──
cask "font-meslo-for-powerlevel10k"          # MesloLGS NF —— iTerm2 profile 实际使用的字体
cask "font-jetbrains-mono-nerd-font"         # 备用 Nerd Font

# ── .zshrc 里用到的命令行工具 ─────────────
brew "bat"                                   # cat 替代 + fzf 预览
brew "eza"                                   # ls / tree 替代
brew "fzf"                                   # Ctrl-R / Ctrl-T / Alt-C
brew "gh"                                    # GitHub CLI
brew "uv"                                    # Python 包管理
brew "ffmpeg"                                # 音视频处理（可选，体积较大）

# ── 可选：菜单栏小组件（不属于 iTerm2）────
cask "swiftbar"
