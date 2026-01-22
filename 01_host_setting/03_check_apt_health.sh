#!/usr/bin/env bash
set -e

echo "===== APT 源健康自检 ====="

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

fail() {
  echo -e "${RED}✘ $1${NC}"
}

ok() {
  echo -e "${GREEN}✔ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# -------------------------------------------------
# 1. DNS 基础检测
# -------------------------------------------------
echo ">>> [1/6] DNS 解析检测"

TEST_DOMAINS=(
  archive.ubuntu.com
  security.ubuntu.com
  mirrors.aliyun.com
)

DNS_FAIL=0
for d in "${TEST_DOMAINS[@]}"; do
  if getent hosts "$d" >/dev/null 2>&1; then
    ok "DNS 可解析: $d"
  else
    fail "DNS 无法解析: $d"
    DNS_FAIL=1
  fi
done

# -------------------------------------------------
# 2. Ubuntu 源是否存在
# -------------------------------------------------
echo
echo ">>> [2/6] Ubuntu 源文件检查"

if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  ok "存在 ubuntu.sources"
else
  fail "缺少 ubuntu.sources"
fi

# -------------------------------------------------
# 3. universe 是否启用
# -------------------------------------------------
echo
echo ">>> [3/6] Universe 仓库检查"

if grep -R "universe" /etc/apt/sources.list* /etc/apt/sources.list.d/*.sources >/dev/null 2>&1; then
  ok "universe 已启用"
else
  fail "universe 未启用（很多常用包会消失）"
fi

# -------------------------------------------------
# 4. 源域名可达性（HTTP HEAD）
# -------------------------------------------------
echo
echo ">>> [4/6] 软件源连通性检测"

SOURCE_URLS=$(grep -R "^URIs:\|^deb " /etc/apt/sources.list* /etc/apt/sources.list.d/* \
  | awk '{print $2}' \
  | sed 's|/ubuntu.*||' \
  | sort -u)

for url in $SOURCE_URLS; do
  if curl -Is --connect-timeout 5 "$url" >/dev/null 2>&1; then
    ok "可访问: $url"
  else
    warn "无法访问: $url"
  fi
done

# -------------------------------------------------
# 5. apt update 健康检查
# -------------------------------------------------
echo
echo ">>> [5/6] apt update 健康度"

if sudo apt update >/tmp/apt_check.log 2>&1; then
  ok "apt update 执行成功"
else
  warn "apt update 有错误（见 /tmp/apt_check.log）"
fi

if grep -E "Err:|Failed to fetch|NO_PUBKEY" /tmp/apt_check.log >/dev/null; then
  fail "发现 apt 错误条目"
else
  ok "未发现 apt 错误条目"
fi

# -------------------------------------------------
# 6. 常用包可见性测试
# -------------------------------------------------
echo
echo ">>> [6/6] 常用包可见性"

TEST_PKGS=(tree curl gnupg)

for p in "${TEST_PKGS[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    ok "包可见: $p"
  else
    fail "包不可见: $p"
  fi
done

echo
echo "===== APT 自检完成 ====="

if [ "$DNS_FAIL" -eq 1 ]; then
  echo -e "${RED}⚠ DNS 不正常，强烈不建议继续安装 Docker / K8s${NC}"
fi

