#!/usr/bin/env bash
# 推送前扫一遍，确认仓库里没有密钥 / 个人信息。
#
#   ./scripts/privacy-scan.sh                     扫描当前仓库
#   PII_EXTRA='你的名字|你的主机名' ./scripts/privacy-scan.sh    追加个人关键词
#
#   退出码 0 = 干净，1 = 有命中（可直接挂到 pre-push hook 或 CI）
#
# 注意：本脚本自身被排除在扫描之外（否则规则字符串会自己命中自己）。
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"
EX=(--exclude-dir=.git --exclude=privacy-scan.sh)

SECRET_PAT='sk-[A-Za-z0-9_-]{10,}|sk-proj-[A-Za-z0-9_-]{10,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{8,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,}|ya29\.[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|hf_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{15,}|npm_[A-Za-z0-9]{20,}|ssh-rsa AAAA[A-Za-z0-9+/=]{20,}|ssh-ed25519 AAAA[A-Za-z0-9+/=]{20,}|postgres(ql)?://[^[:space:]]*:[^[:space:] ]*@|mongodb(\+srv)?://[^[:space:]]*:[^[:space:] ]*@|redis://[^[:space:]]*:[^[:space:] ]*@'

# 通用个人信息规则：任何真实用户绝对路径（占位符 @@SRC_HOME@@ 不算）
PII_PAT='/Users/[a-z]'
[[ -n "${PII_EXTRA:-}" ]] && PII_PAT="$PII_PAT|$PII_EXTRA"

fail=0
hit() { sed -E 's/(.{0,8}).*(.{0,4})$/\1***\2/' <<<"$1"; fail=1; }
echo "扫描目录： $ROOT"; echo

echo "① 密钥 / token / 私钥 / 带密码的连接串"
if out=$(grep -rnoIE "$SECRET_PAT" . "${EX[@]}" 2>/dev/null) && [[ -n "$out" ]]; then hit "$out"; else echo "   ✓ 无命中"; fi

echo "② 真实用户绝对路径 / 自定义个人关键词"
if out=$(grep -rnoIE "$PII_PAT" . "${EX[@]}" 2>/dev/null) && [[ -n "$out" ]]; then echo "$out" | sort -u; fail=1; else echo "   ✓ 无命中"; fi

echo "③ 证书签名身份（模板里的 \"Your Name (TEAMID1234)\" 是允许的）"
if out=$(grep -rnIE 'Developer ID Application|Apple Development|TEAMID' . "${EX[@]}" 2>/dev/null \
        | grep -vE 'Your Name \\(TEAMID1234\\)|<已脱敏>|TEAMID1234') && [[ -n "$out" ]]; then echo "$out"; fail=1; else echo "   ✓ 无命中"; fi

echo "④ 内网 / 公网 IP（放行 0.0.0.0、127.0.0.1、1.1.1.1、8.8.8.8）"
if out=$(grep -rnoIE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' . "${EX[@]}" 2>/dev/null | grep -vE '0\.0\.0\.0|127\.0\.0\.1|1\.1\.1\.1|8\.8\.8\.8') && [[ -n "$out" ]]; then echo "$out" | sort -u | head; fail=1; else echo "   ✓ 无命中"; fi

echo "⑤ 邮箱地址（放行上游示例与仓库链接）"
if out=$(grep -rnoIE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' . "${EX[@]}" 2>/dev/null | grep -viE 'x@y\.com|example\.(com|org)|githubusercontent|noreply') && [[ -n "$out" ]]; then echo "$out" | sort -u | head; fail=1; else echo "   ✓ 无命中"; fi

echo "⑥ 容易被误提交的敏感文件"
if out=$(find . -path ./.git -prune -o -type f \( -name 'secrets.env' -o -name '.env' -o -name '*.pem' -o -name 'id_rsa*' -o -name 'id_ed25519*' -o -name '*.bak-*' -o -name '*credentials*' \) -print 2>/dev/null) && [[ -n "$out" ]]; then echo "$out"; fail=1; else echo "   ✓ 无命中"; fi

echo
if (( fail )); then echo "✗ 有可疑内容，别推。处理掉再跑一次。"; exit 1
else echo "✓ 干净，可以 push。"; fi
