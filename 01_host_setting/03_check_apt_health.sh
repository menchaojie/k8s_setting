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
# 2. Ubuntu 源是否存在（兼容 22.04 sources.list / 24.04 ubuntu.sources）
# -------------------------------------------------
echo
echo ">>> [2/6] Ubuntu 源文件检查"

HAS_DEB822=0
HAS_TRADITIONAL=0

if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  HAS_DEB822=1
fi

if [ -f /etc/apt/sources.list ] && grep -Eqs '^[[:space:]]*deb[[:space:]]' /etc/apt/sources.list; then
  HAS_TRADITIONAL=1
fi

# 有些环境 Ubuntu 源也可能在 sources.list.d/*.list
if grep -REqs '^[[:space:]]*deb[[:space:]].*(ubuntu|mirrors\.)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  HAS_TRADITIONAL=1
fi

if [ "$HAS_DEB822" -eq 1 ] || [ "$HAS_TRADITIONAL" -eq 1 ]; then
  ok "已检测到 Ubuntu APT 源配置"
  [ "$HAS_DEB822" -eq 1 ] && echo "  - Deb822: ubuntu.sources"
  [ "$HAS_TRADITIONAL" -eq 1 ] && echo "  - traditional: sources.list / *.list"
else
  fail "未找到可用的 Ubuntu APT 源配置"
fi

# -------------------------------------------------
# 3. universe 是否启用
# -------------------------------------------------
echo
echo ">>> [3/6] Universe 仓库检查"

if grep -Rqs "universe" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  ok "universe 已启用"
else
  fail "universe 未启用（很多常用包会消失）"
fi

# -------------------------------------------------
# 4. 源域名可达性（只抽取真正的 http(s) URL）
# -------------------------------------------------
echo
echo ">>> [4/6] 软件源连通性检测"

SOURCE_URLS=$(
  {
    # traditional: deb ... https://...
    grep -RhoE 'https?://[^[:space:]]+' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
    # Deb822: URIs: https://...
    grep -RhoE '^URIs:[[:space:]]+https?://[^[:space:]]+' /etc/apt/sources.list.d 2>/dev/null \
      | awk '{print $2}' || true
  } | sed -E 's|/$||' \
    | sed -E 's#/(ubuntu|docker-ce)/.*##' \
    | sort -u
)

if [ -z "$SOURCE_URLS" ]; then
  warn "未解析到任何软件源 URL"
else
  for url in $SOURCE_URLS; do
    if curl -Is --connect-timeout 5 "$url" >/dev/null 2>&1; then
      ok "可访问: $url"
    else
      warn "无法访问: $url"
    fi
  done
fi

# -------------------------------------------------
# 5. apt update 健康检查
# -------------------------------------------------
echo
echo ">>> [5/6] apt update 健康度"
echo "（输出写入 /tmp/apt_check.log，可能需要一两分钟…）"

set +e
sudo apt update 2>&1 | tee /tmp/apt_check.log >/dev/null
APT_RC=${PIPESTATUS[0]}
set -e

if [ "$APT_RC" -eq 0 ]; then
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
