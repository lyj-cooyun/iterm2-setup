#!/bin/bash
# <xbar.title>系统信息</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>Codex</xbar.author>
# <xbar.desc>CPU / 内存 / 磁盘 / 电量 / 网络 一栏搞定</xbar.desc>
# <xbar.dependencies>top,df,pmset,ps,vm_stat</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

hr() { printf '%.1fG' "$(echo "$1 / 1073741824" | bc -l 2>/dev/null)" 2>/dev/null || echo "?"; }

# ---------- CPU ----------
cpu_line=$(top -l 2 -n 0 -s 1 2>/dev/null | grep 'CPU usage' | tail -1)
cpu_user=$(printf '%s' "$cpu_line" | awk '{gsub(/%/,"",$3); printf "%d", $3+0.5}')
cpu_sys=$(printf '%s'  "$cpu_line" | awk '{gsub(/%/,"",$5); printf "%d", $5+0.5}')
cpu_total=""
if [ -n "$cpu_line" ]; then
  cpu_total=$(( ${cpu_user:-0} + ${cpu_sys:-0} ))
fi

# ---------- 内存（top 优先，失败则用 vm_stat 兜底） ----------
mem_line=$(top -l 1 -n 0 2>/dev/null | grep 'PhysMem' | sed 's/^PhysMem: //; s/([0-9]*[MGK]*)//g')
if [ -z "$mem_line" ]; then
  ps_bytes=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
  total=$(sysctl -n hw.memsize 2>/dev/null)
  used=$(vm_stat 2>/dev/null | awk -v p="$ps_bytes" '
    /^Pages active:/      {a=$3} /^Pages wired down:/ {w=$4} /^Pages occupied by compressor:/ {c=$5}
    END {gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c); printf "%d", (a+w+c)*p}')
  if [ -n "$used" ] && [ -n "$total" ]; then
    mem_line="$(hr "$used") used / $(hr "$total")"
  fi
fi

# ---------- 磁盘 ----------
disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}')
disk_free=$(df -h / 2>/dev/null | awk 'NR==2 {print $4}')

# ---------- 电量 ----------
batt=$(pmset -g batt 2>/dev/null | grep -o '[0-9]\{1,3\}%' | head -1)
bstate=$(pmset -g batt 2>/dev/null | grep -oE 'charging|discharging|charged|finishing charge|AC Power|Battery Power' | head -1)

# ---------- IP ----------
ip=$(ipconfig getifaddr en0 2>/dev/null)
[ -z "$ip" ] && ip=$(ipconfig getifaddr en1 2>/dev/null)
if [ -z "$ip" ]; then
  ip=$(ifconfig 2>/dev/null | awk '/^[a-z]/{i=$1} /inet /{if (i!="lo0:") {print $2; exit}}')
fi

# ---------- Header ----------
if [ -n "$cpu_total" ]; then
  label="${cpu_total}%"
  sym="cpu.fill"
  col=""
  [ "$cpu_total" -ge 80 ] && col=" | color=red"
  [ "$cpu_total" -ge 50 ] && [ "$cpu_total" -lt 80 ] && col=" | color=orange"
else
  label="—"
  sym="cpu"
  col=""
fi
[ -n "$batt" ] && label="${label:+$label }$batt"
echo "$label | sfimage=$sym$col"
echo "---"

[ -n "$cpu_total" ] && echo "CPU  用户 ${cpu_user}%  系统 ${cpu_sys}% | font=Menlo size=12"
[ -n "$mem_line" ]  && echo "内存  ${mem_line} | font=Menlo size=12"
[ -n "$disk" ]      && echo "磁盘  已用 ${disk}  剩余 ${disk_free} | font=Menlo size=12"
if [ -n "$batt" ]; then
  case "$bstate" in
    charging*)       echo "电量  ${batt}  充电中 | sfimage=bolt.fill size=12" ;;
    discharging*|"Battery Power") echo "电量  ${batt}  使用电池 | sfimage=battery.75 size=12" ;;
    *)               echo "电量  ${batt}  接电源 | sfimage=powerplug.fill size=12" ;;
  esac
fi
echo "本机 IP  ${ip:-未知} | font=Menlo size=12"

# ---------- Top 进程 ----------
if procs=$(ps -Aceo pcpu,comm -r 2>/dev/null) && [ -n "$procs" ]; then
  echo "---"
  echo "CPU 占用 Top 5 | color=gray size=11 disabled=true"
  printf '%s\n' "$procs" | awk 'NR>1 && NR<=6 {n=$2; for(i=3;i<=NF;i++) n=n" "$i; printf "%5.1f%%  %s\n", $1, n}' | while read -r l; do
    echo "$l | font=Menlo size=11"
  done
fi

echo "---"
echo "打开活动监视器 | sfimage=chart.bar.xaxis bash=/usr/bin/open param1=-a param2='Activity Monitor' terminal=false"
echo "打开网络设置 | sfimage=network bash=/usr/bin/open param1='x-apple.systempreferences:com.apple.Network-Settings.extension' terminal=false"
