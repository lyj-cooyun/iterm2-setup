# iterm2-setup

一台 Mac 上调好的 **iTerm2 + zsh + Powerlevel10k** 环境，用一条命令复刻到另一台。
配置全在 git 里，改完 `push`，新机器 `pull` 一下再跑 `./install.sh` 就同步了。

- 源环境：iTerm2 3.7.4 · macOS (Apple Silicon) · zsh + oh-my-zsh + Powerlevel10k
- 仓库体积：约 300 KB（字体和命令行工具由 `install.sh` 联网装，不入库）

---

## 新机器：安装

```bash
git clone https://github.com/lyj-cooyun/iterm2-setup.git
cd iterm2-setup
./install.sh --dry-run    # 先看会动哪些文件（推荐）
./install.sh              # 正式安装
```

> 一行版（懒人用）：
> ```bash
> git clone https://github.com/lyj-cooyun/iterm2-setup.git ~/Developer/iterm2-setup && ~/Developer/iterm2-setup/install.sh
> ```

> ⚠️ 跑之前**先完全退出 iTerm2**（⌘Q），否则它会用内存里的旧配置覆盖你刚导入的设置。
> 脚本检测到 iTerm2 在运行时会提醒你，并可以帮你退出。

装完打开 iTerm2，应该直接就是：MesloLGS NF 13pt、Powerlevel10k 提示符、
底部状态栏（目录 / Git / CPU / 内存 / 网络 / 电池 / 时钟）。

首次使用还要手动填一次密钥（仓库里没有）：

```bash
cp dotfiles/secrets.env.example ~/.config/secrets.env
chmod 600 ~/.config/secrets.env
$EDITOR ~/.config/secrets.env      # 填入真实值
```

---

## 老机器：改了配置怎么同步

```bash
./scripts/export-refresh.sh ~/path/to/iterm2-setup    # 重新抓取本机配置写进仓库目录
cd ~/path/to/iterm2-setup
./scripts/privacy-scan.sh                             # 推送前自检（有命中会返回 1）
git add -A && git commit -m "update: 换了 Gruvbox 配色" && git push
```

`export-refresh.sh` 会自动完成脱敏：抹掉 `.zshrc` 里所有 `*_KEY` / `*_TOKEN` / `*_SECRET` /
`*_PASSWORD` 形式的硬编码值，把 plist 里的 home 路径替换成 `@@SRC_HOME@@` 占位符，
并剥离机器状态 key（安装 ID、窗口位置、系统版本等）。

---

## 仓库内容

```
iterm2-setup/
├── install.sh                     一键安装（幂等，可反复跑）
├── Brewfile                       Homebrew 包 + 字体清单
├── MANIFEST.txt                   详细清单，含所有插件的精确 commit
├── .gitignore                     挡住 secrets.env / 备份 / .DS_Store
├── iterm2/
│   ├── com.googlecode.iterm2.plist    iTerm2 全局偏好（XML，可 diff）
│   └── DynamicProfiles/
│       └── codex-themes.json          3 套主题 Profile，含状态栏布局
├── dotfiles/
│   ├── zshrc                      oh-my-zsh + 插件配置
│   ├── p10k.zsh                   Powerlevel10k 配置（提示符样式的核心）
│   ├── zprofile                   brew shellenv + OrbStack init
│   └── secrets.env.example        敏感变量模板（真实值不入库）
├── extras/swiftbar/               可选：SwiftBar 菜单栏脚本
└── scripts/
    ├── export-refresh.sh          从本机重新导出（自动脱敏）
    └── privacy-scan.sh            推送前的密钥 / 个人信息自检
```

### 三套主题

都是 iTerm2 **动态 Profile**，切换不影响全局设置：

| Profile | 风格 |
|---|---|
| Catppuccin Mocha | 柔和低对比，蓝紫调 |
| Gruvbox Dark | 复古暖色，棕黄调 |
| Everforest Dark Med | 森林绿，护眼 |

切换：`⌘O` → 选一个。设为默认：Settings → Profiles → Other Actions → Set as Default。

### 用到的东西

- **字体**：MesloLGS NF（profile 实际引用）、JetBrainsMono Nerd Font
- **oh-my-zsh 插件**：`zsh-autosuggestions`（灰色历史建议）、`zsh-completions`、`zsh-syntax-highlighting`
- **主题**：Powerlevel10k
- **命令行工具**：`bat`（cat）、`eza`（ls/tree）、`fzf`（Ctrl-R/Ctrl-T/Alt-C）、`gh`、`uv`、`ffmpeg`
- **补全增强**：大小写不敏感 + 方向键选菜单；历史 10 万条、跨窗口共享

---

## install.sh 做了什么

按顺序执行，每步都是「有就跳过 / 覆盖前先备份」，备份落在 `~/iterm2-restore-backup-<时间戳>/`：

1. **Homebrew 包与字体** — `brew bundle install --file=Brewfile`
2. **oh-my-zsh** — 没装就装（`RUNZSH=no CHSH=no`，不改默认 shell），
   再 clone `powerlevel10k`、`zsh-autosuggestions`、`zsh-completions`、`zsh-syntax-highlighting`
3. **dotfiles** — 写入 `~/.zshrc`、`~/.p10k.zsh`；`~/.zprofile` 只在缺 `brew shellenv` 时追加一行，不整体覆盖；
   `~/.config/secrets.env` 只在不存在时从模板创建，**绝不覆盖已有文件**
4. **iTerm2** — 把 plist 里的 `@@SRC_HOME@@` 改写成新机器的 `$HOME`，
   再用 `defaults import com.googlecode.iterm2` 导入（走 cfprefsd，避免缓存不一致）；
   动态 Profile 的 json 拷到 `~/Library/Application Support/iTerm2/DynamicProfiles/`
5. **SwiftBar（可选）** — 脚本拷到 `~/SwiftBarPlugins`，第一次需在 SwiftBar 里选一次插件目录

### 参数

```bash
./install.sh --dry-run       # 只打印，不写入
./install.sh --only-iterm    # 只恢复 iTerm2 偏好 + 主题
./install.sh --only-shell    # 只恢复 zsh / p10k / 插件
./install.sh --no-brew       # 跳过 Homebrew（想手动装时用）
./install.sh --no-extras     # 不要 SwiftBar
./install.sh --help
```

---

## 隐私与安全

这个仓库是公开的，所以：

- **不含任何密钥**。`~/.zshrc` 通过 `[[ -f ~/.config/secrets.env ]] && source ...` 读取敏感变量，
  真实值只存在于本机 `~/.config/secrets.env`（权限 600），`.gitignore` 也已挡住它。
- **不含个人信息**。plist 里的绝对路径统一替换成 `@@SRC_HOME@@` 占位符；
  证书签名身份之类只在 `secrets.env.example` 里以 `Your Name (TEAMID1234)` 形式出现。
- **不含机器状态**。已剥离 iTerm2 的 21 个本地状态 key：安装 ID、窗口位置与尺寸、
  系统版本记录、启动次数、提示已读状态等。
- **不含运行态数据**：SavedState、chatdb.sqlite、socket、`iTermServer-*` 二进制一律不导出。
- **不含** `~/.zsh_history`、`~/.ssh`、gh 凭据、Keychain 内容。

推送前建议跑一次 `./scripts/privacy-scan.sh`，六类检查全过才返回 0：
密钥/token/私钥/带密码的连接串、真实用户绝对路径、证书签名身份、IP 地址、邮箱、敏感文件名。
可以挂成 pre-push hook：

```bash
ln -s ../../scripts/privacy-scan.sh .git/hooks/pre-push
```

要加自己的关键词：`PII_EXTRA='你的名字|你的主机名' ./scripts/privacy-scan.sh`

---

## 新机器上还需要自己做一次的

- `gh auth login`（GitHub CLI 登录）
- SSH key：`ssh-keygen` 后加到 GitHub
- `git config --global user.name/user.email`
- `~/.config/secrets.env` 填入真实值
- 如果新机器的 iTerm2 版本高很多，个别设置项可能被自动迁移，属正常

---

## 不想用脚本？手动步骤

```bash
# 1. 包与字体
brew bundle install --file=Brewfile

# 2. oh-my-zsh + 插件（已装 oh-my-zsh 可跳过第一条）
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
Z=~/.oh-my-zsh/custom
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git             $Z/themes/powerlevel10k
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git     $Z/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-completions.git         $Z/plugins/zsh-completions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git $Z/plugins/zsh-syntax-highlighting

# 3. dotfiles（先自己备份！）
cp dotfiles/zshrc    ~/.zshrc
cp dotfiles/p10k.zsh ~/.p10k.zsh

# 4. iTerm2 —— 必须先 ⌘Q 退出 iTerm2
mkdir -p ~/Library/Application\ Support/iTerm2/DynamicProfiles
cp iterm2/DynamicProfiles/codex-themes.json ~/Library/Application\ Support/iTerm2/DynamicProfiles/
sed "s|@@SRC_HOME@@|$HOME|g" iterm2/com.googlecode.iterm2.plist > /tmp/iterm2.plist
defaults import com.googlecode.iterm2 /tmp/iterm2.plist

# 5. 重开 iTerm2
exec zsh
```

> 另一种玩法：iTerm2 → Settings → General → Preferences → 勾上
> "Load preferences from a custom folder or URL"，指向本仓库的 `iterm2/` 目录，
> 之后偏好设置就随 git 自动同步，连 `defaults import` 都不用跑。

---

## 验证清单

- [ ] iTerm2 打开就是深色主题，字体不是等宽方块（MesloLGS NF 生效）
- [ ] 提示符是 Powerlevel10k 样式，带 git 分支和状态图标
- [ ] 底部状态栏：目录 / Git / CPU / 内存 / 网络 / 电池 / 时钟
- [ ] `⌘O` 能看到 Catppuccin Mocha / Gruvbox Dark / Everforest Dark Med
- [ ] 打命令时出现灰色历史建议 → `zsh-autosuggestions` ✓（按 → 补全）
- [ ] 命令有语法高亮 → `zsh-syntax-highlighting` ✓
- [ ] `Ctrl-R` 弹出模糊搜索 → `fzf` ✓
- [ ] `ls` 带图标和 git 状态 → `eza` ✓
- [ ] `cat README.md` 带高亮和行号 → `bat` ✓
- [ ] Tab 补全大小写不敏感、方向键选菜单 ✓
