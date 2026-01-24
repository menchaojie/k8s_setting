#!/bin/bash
set -euo pipefail

echo "===== Fix cri-dockerd pause image ====="

#------------------------------
#可配置参数
#------------------------------
PAUSE_IMAGE="crpi-ckw9ia686aku4y4w.cn-shanghai.personal.cr.aliyuncs.com/tgtech/pause:3.10.1"
SERVICE_NAME="cri-docker.service"
DROPIN_DIR="/etc/systemd/system/${SERVICE_NAME}.d"
CONF_FILE="${DROPIN_DIR}/10-pause.conf"

#------------------------------
#检测 cri-dockerd binary
#------------------------------
CRI_BIN="$(command -v cri-dockerd || true)"
if [[ -z "$CRI_BIN" ]]; then
  echo "[FAIL] 未找到 cri-dockerd 可执行文件"
  exit 1
fi
echo "[INFO] cri-dockerd binary: $CRI_BIN"

#------------------------------
#检测 systemd service（正确方式）
#------------------------------
if ! systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "[FAIL] systemd 未识别 ${SERVICE_NAME}"
  exit 1
fi

#------------------------------
#期望的 drop-in 内容（唯一真值）
#------------------------------
EXPECTED_CONF=$(cat <<EOF
[Service]
ExecStart=
ExecStart=$CRI_BIN \\
  --container-runtime-endpoint fd:// \\
  --pod-infra-container-image=${PAUSE_IMAGE}
EOF
)

#------------------------------
#幂等判断
#------------------------------
if [[ -f "$CONF_FILE" ]]; then
  if diff -u <(sed '/^[[:space:]]*$/d' "$CONF_FILE") \
            <(sed '/^[[:space:]]*$/d' <<<"$EXPECTED_CONF") \
            >/dev/null; then
    echo "[OK] pause image 已正确配置，无需修改"
    exit 0
  else
    echo "[INFO] 发现旧配置，将更新 pause image"
  fi
else
  echo "[INFO] 未发现 pause 配置，将创建"
fi

#------------------------------
#写入 drop-in
#------------------------------
sudo mkdir -p "$DROPIN_DIR"
#the erro is '>' not sudo 
#sudo cat > "$CONF_FILE" <<EOF
sudo tee "$CONF_FILE" > /dev/null <<EOF
$EXPECTED_CONF
EOF


echo "[INFO] 写入 $CONF_FILE"

#------------------------------
#重载并重启
#------------------------------
sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_NAME"

echo "[OK] cri-dockerd pause image 修复完成"

