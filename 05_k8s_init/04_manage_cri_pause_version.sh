#!/usr/bin/env bash
set -euo pipefail

echo "===== Manage cri-dockerd pause image ====="

SERVICE_NAME="cri-docker.service"
DROPIN_DIR="/etc/systemd/system/${SERVICE_NAME}.d"
CONF_FILE="${DROPIN_DIR}/10-pause.conf"

#-------------------------------------------------
# 检测 cri-dockerd binary
#-------------------------------------------------
CRI_BIN="$(command -v cri-dockerd || true)"
if [[ -z "$CRI_BIN" ]]; then
  echo "[FAIL] 未找到 cri-dockerd 可执行文件"
  exit 1
fi
echo "[INFO] cri-dockerd binary: $CRI_BIN"

#-------------------------------------------------
# 检测 systemd service
#-------------------------------------------------
if ! systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "[FAIL] systemd 未识别 ${SERVICE_NAME}"
  exit 1
fi

#-------------------------------------------------
# 操作模式选择
#-------------------------------------------------
echo
echo "请选择操作："
echo "  1) 设置 / 修改 pause 镜像版本"
echo "  2) 删除 pause drop-in（回退为 cri-dockerd 默认行为）"
echo
read -p "请输入选择 [1/2]: " ACTION

#-------------------------------------------------
# 模式 2：删除 drop-in
#-------------------------------------------------
if [[ "$ACTION" == "2" ]]; then
  echo
  echo "[INFO] 将删除 pause drop-in 配置："
  echo "  $CONF_FILE"
  read -p "确认删除并回滚？(yes/no): " CONFIRM

  if [[ "$CONFIRM" != "yes" ]]; then
    echo "[ABORT] 用户取消操作"
    exit 0
  fi

  if [[ -f "$CONF_FILE" ]]; then
    sudo rm -f "$CONF_FILE"
    echo "[OK] 已删除 drop-in 文件"
  else
    echo "[INFO] drop-in 文件不存在，无需删除"
  fi

  echo
  read -p "即将重载并重启 cri-dockerd，按 Enter 继续..."

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl restart "$SERVICE_NAME"

  echo "[OK] cri-dockerd 已回滚为默认 pause 行为"
  exit 0
fi

#-------------------------------------------------
# 模式 1：设置 / 修改 pause 版本
#-------------------------------------------------
echo
echo "请选择 pause 镜像版本："
echo "  1) pause:3.9   （Kubernetes 1.28 推荐）"
echo "  2) pause:3.10  （Kubernetes 1.29 / 1.30）"
echo "  3) pause:3.10.1（Kubernetes 1.35）"
echo "  4) 自定义 pause 镜像"
echo
read -p "请输入选择 [1-4]: " PAUSE_CHOICE

case "$PAUSE_CHOICE" in
  1)
    PAUSE_IMAGE="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech/pause:3.9"
    ;;
  2)
    PAUSE_IMAGE="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech/pause:3.10"
    ;;
  3)
    PAUSE_IMAGE="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech/pause:3.10.1"
    ;;
  4)
    read -p "请输入完整 pause 镜像地址: " PAUSE_IMAGE
    ;;
  *)
    echo "[FAIL] 无效选择"
    exit 1
    ;;
esac

echo
echo "[INFO] 选定 pause 镜像为："
echo "  $PAUSE_IMAGE"
read -p "确认使用该 pause 镜像？(yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "[ABORT] 用户取消操作"
  exit 0
fi

#-------------------------------------------------
# 构造期望的 drop-in 内容
#-------------------------------------------------
EXPECTED_CONF=$(cat <<EOF
[Service]
ExecStart=
ExecStart=$CRI_BIN \\
  --container-runtime-endpoint fd:// \\
  --pod-infra-container-image=${PAUSE_IMAGE}
EOF
)

#-------------------------------------------------
# 幂等判断
#-------------------------------------------------
if [[ -f "$CONF_FILE" ]]; then
  if diff -u <(sed '/^[[:space:]]*$/d' "$CONF_FILE") \
            <(sed '/^[[:space:]]*$/d' <<<"$EXPECTED_CONF") \
            >/dev/null; then
    echo "[OK] pause image 已正确配置，无需修改"
    exit 0
  else
    echo "[INFO] 发现旧 pause 配置，将更新"
  fi
else
  echo "[INFO] 未发现 pause 配置，将创建"
fi

#-------------------------------------------------
# 写入 drop-in
#-------------------------------------------------
sudo mkdir -p "$DROPIN_DIR"

sudo tee "$CONF_FILE" > /dev/null <<EOF
$EXPECTED_CONF
EOF

echo "[INFO] 已写入 $CONF_FILE"

#-------------------------------------------------
# 重载并重启
#-------------------------------------------------
echo
read -p "即将重载并重启 cri-dockerd，按 Enter 继续..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_NAME"

echo "[OK] cri-dockerd pause image 配置完成"

