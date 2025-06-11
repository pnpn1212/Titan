#!/bin/bash

# ======================
# 🔧 AZTEC PROVER - MENU
# ======================

IMAGE="aztecprotocol/aztec:0.87.8"
NETWORK="alpha-testnet"
DEFAULT_DATA_DIR="/root/aztec-prover"
DEFAULT_P2P_PORT="40400"
DEFAULT_API_PORT="8080"

install_dependencies() {
  echo "🔧 Đang cài đặt các gói cần thiết..."
  apt-get update && apt-get upgrade -y
  apt install -y screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf \
    tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip fzf

  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
  npm install -g yarn
}

compose_cmd() {
  if command -v docker compose &>/dev/null; then
    echo "docker compose"
  elif command -v docker-compose &>/dev/null; then
    echo "docker-compose"
  else
    return 1
  fi
}

check_and_install_docker() {
  if ! compose_cmd &>/dev/null; then
    echo "🔧 Docker Compose chưa có. Đang cài đặt..."
    source <(curl -s https://raw.githubusercontent.com/vnbnode/binaries/main/docker-install.sh)
  else
    echo "✅ Docker Compose đã sẵn sàng."
  fi
}

load_env_or_prompt() {
  # Tự động cài fzf nếu chưa có
  command -v fzf >/dev/null 2>&1 || {
    echo "📦 Đang cài đặt fzf..."
    apt update -y && apt install fzf -y
  }

  ENV_FILE="$DEFAULT_DATA_DIR/.env"
  WAN_IP=$(curl -s ifconfig.me)

  # Biểu tượng cho từng biến
  declare -A ICONS=(
    ["WAN_IP"]="🌐"
    ["P2P_PORT"]="🔌"
    ["API_PORT"]="🧩"
    ["RPC_SEPOLIA"]="🛰️"
    ["BEACON_SEPOLIA"]="📡"
    ["PRIVATE_KEY"]="🔐"
    ["PROVER_ID"]="🪪"
    ["AGENT_COUNT"]="👷"
    ["DATA_DIR"]="📂"
  )

  if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"

    # Gán theo thứ tự cố định
    env_lines=(
      "WAN_IP=$WAN_IP"
      "P2P_PORT=$P2P_PORT"
      "API_PORT=$API_PORT"
      "RPC_SEPOLIA=$RPC_SEPOLIA"
      "BEACON_SEPOLIA=$BEACON_SEPOLIA"
      "PRIVATE_KEY=$PRIVATE_KEY"
      "PROVER_ID=$PROVER_ID"
      "AGENT_COUNT=$AGENT_COUNT"
      "DATA_DIR=$DATA_DIR"
    )

    echo "🔄 .env hiện tại:"
    for i in "${!env_lines[@]}"; do
      key="${env_lines[$i]%%=*}"
      val="${env_lines[$i]#*=}"
      [[ "$key" == "PRIVATE_KEY" ]] && val="********"
      printf "%2d. %s %s=%s\n" "$((i+1))" "${ICONS[$key]}" "$key" "$val"
    done

    echo ""
    read -p "🔁 Bạn có muốn chỉnh sửa các biến môi trường? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      while true; do
        echo ""
        echo "🔯 Chọn biến cần thay đổi:"

        # Hiển thị biến với icon và ẩn PRIVATE_KEY
        display_lines=()
        for line in "${env_lines[@]}"; do
          key="${line%%=*}"
          val="${line#*=}"
          [[ "$key" == "PRIVATE_KEY" ]] && val="********"
          display_lines+=("${ICONS[$key]} $key=$val")
        done

        # fzf với icon + --reverse
        selected=$(printf "%s\n" "${display_lines[@]}" "💾 Lưu và tiếp tục" | fzf --prompt="🔧 Chọn biến: " --height=40% --reverse)

        if [[ "$selected" == "💾 Lưu và tiếp tục" ]]; then
          break
        elif [[ -n "$selected" ]]; then
          key=$(echo "$selected" | awk '{print $2}' | cut -d'=' -f1)
          for i in "${!env_lines[@]}"; do
            if [[ "${env_lines[$i]%%=*}" == "$key" ]]; then
              old_val="${env_lines[$i]#*=}"
              break
            fi
          done
          read -p "🔧 Nhập giá trị mới cho $key (hiện tại: $old_val): " new_val
          new_val="${new_val:-$old_val}"
          for i in "${!env_lines[@]}"; do
            [[ "${env_lines[$i]%%=*}" == "$key" ]] && env_lines[$i]="$key=$new_val"
          done
        else
          echo "❌ Bạn chưa chọn gì cả!"
        fi
      done
    fi

  else
    echo "📄 Tạo file .env mới..."
    read -p "🔍 Nhập Sepolia RPC URL: " RPC_SEPOLIA
    read -p "🔍 Nhập Beacon API URL: " BEACON_SEPOLIA
    read -s -p "🔐 Nhập Publisher Private Key: " PRIVATE_KEY
    echo ""
    read -p "💼 Nhập Prover ID: " PROVER_ID
    read -p "🔢 Nhập số agent (mặc định: 1): " AGENT_COUNT
    AGENT_COUNT=${AGENT_COUNT:-1}
    read -p "🏠 Nhập P2P Port [mặc định: $DEFAULT_P2P_PORT]: " P2P_PORT
    P2P_PORT=${P2P_PORT:-$DEFAULT_P2P_PORT}
    read -p "🏠 Nhập API Port [mặc định: $DEFAULT_API_PORT]: " API_PORT
    API_PORT=${API_PORT:-$DEFAULT_API_PORT}
    read -p "📂 Nhập thư mục lưu dữ liệu [mặc định: $DEFAULT_DATA_DIR]: " INPUT_DIR
    DATA_DIR=${INPUT_DIR:-$DEFAULT_DATA_DIR}
    mkdir -p "$DATA_DIR"

    env_lines=(
      "WAN_IP=$WAN_IP"
      "P2P_PORT=$P2P_PORT"
      "API_PORT=$API_PORT"
      "RPC_SEPOLIA=$RPC_SEPOLIA"
      "BEACON_SEPOLIA=$BEACON_SEPOLIA"
      "PRIVATE_KEY=$PRIVATE_KEY"
      "PROVER_ID=$PROVER_ID"
      "AGENT_COUNT=$AGENT_COUNT"
      "DATA_DIR=$DATA_DIR"
    )
  fi

  echo ""
  echo "💾 Đang ghi tệp .env..."
  printf "%s\n" "${env_lines[@]}" > "$ENV_FILE"
  source "$ENV_FILE"
}

generate_compose() {
  COMPOSE_FILE="$DATA_DIR/docker-compose.yml"

  cat > "$COMPOSE_FILE" <<EOF
version: '3.8'
services:
  prover_node:
    image: $IMAGE
    container_name: prover_node
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start
      --prover-node --archiver --network $NETWORK'
    depends_on:
      broker:
        condition: service_started
    env_file:
      - .env
    environment:
      P2P_IP: "\${WAN_IP}"
      P2P_ANNOUNCE_ADDRESSES: "/ip4/\${WAN_IP}/tcp/\${P2P_PORT}"
      ETHEREUM_HOSTS: "\${RPC_SEPOLIA}"
      L1_CONSENSUS_HOST_URLS: "\${BEACON_SEPOLIA}"
      PROVER_PUBLISHER_PRIVATE_KEY: "\${PRIVATE_KEY}"
      PROVER_ENABLED: "true"
      P2P_ENABLED: "true"
      P2P_TCP_PORT: "\${P2P_PORT}"
      P2P_UDP_PORT: "\${P2P_PORT}"
      DATA_STORE_MAP_SIZE_KB: "134217728"
      LOG_LEVEL: "debug"
      PROVER_BROKER_HOST: "http://broker:\${API_PORT}"
    ports:
      - "\${API_PORT}:\${API_PORT}"
      - "\${P2P_PORT}:\${P2P_PORT}"
      - "\${P2P_PORT}:\${P2P_PORT}/udp"
    volumes:
      - \${DATA_DIR}/node:/data

  broker:
    image: $IMAGE
    container_name: broker
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start
      --prover-broker --network $NETWORK'
    env_file:
      - .env
    environment:
      DATA_DIRECTORY: /data
      ETHEREUM_HOSTS: "\${RPC_SEPOLIA}"
      LOG_LEVEL: "debug"
    volumes:
      - \${DATA_DIR}/broker:/data
EOF

  for i in $(seq 1 "$AGENT_COUNT"); do
    cat >> "$COMPOSE_FILE" <<EOF

  agent_$i:
    image: $IMAGE
    container_name: agent_$i
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start
      --prover-agent --network $NETWORK'
    env_file:
      - .env
    environment:
      PROVER_ID: "\${PROVER_ID}"
      PROVER_BROKER_HOST: "http://broker:\${API_PORT}"
      PROVER_AGENT_POLL_INTERVAL_MS: "10000"
    depends_on:
      - broker
    restart: unless-stopped
EOF
  done
}

install_prover() {
  load_env_or_prompt
  install_dependencies
  check_and_install_docker
  generate_compose

  echo ""
  echo "🚀 Khởi động container..."
  cd "$DATA_DIR"
  $(compose_cmd) up -d

  echo ""
  echo "🎉 Hoàn tất triển khai tại: $DATA_DIR"
}

delete_prover() {
  source "$DEFAULT_DATA_DIR/.env" 2>/dev/null
  DATA_DIR=${DATA_DIR:-$DEFAULT_DATA_DIR}
  cd "$DATA_DIR" && $(compose_cmd) down -v
}

view_logs() {
  echo "📜 Running Aztec Prover Logs..."

  # Load .env để lấy DATA_DIR nếu chưa có
  [ -f "$DEFAULT_DATA_DIR/.env" ] && source "$DEFAULT_DATA_DIR/.env"

  if [ -z "$DATA_DIR" ] || [ ! -d "$DATA_DIR" ]; then
    echo "❌ Không tìm thấy thư mục DATA_DIR: $DATA_DIR"
    return
  fi

  cd "$DATA_DIR" || { echo "❌ Không thể cd vào $DATA_DIR"; return; }

  # Lấy danh sách container
  CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "^(prover_node|broker|agent_[0-9]+)$" || true)

  if [ -z "$CONTAINERS" ]; then
    echo "❌ Không có container nào đang chạy!"
  else
    # Thêm biểu tượng 🐳
    OPTIONS=$(echo "$CONTAINERS" | sed 's/^/🐳 /')
    OPTIONS=$(echo -e "$OPTIONS\n🧾 View all logs")

    SELECTED=$(echo "$OPTIONS" | fzf --height=12 --border --prompt="🔍 Chọn container hoặc xem toàn bộ logs: " --reverse)

    # Xác định lệnh docker compose phù hợp
    if command -v docker-compose &>/dev/null; then
      CMD="docker-compose"
    else
      CMD="docker compose"
    fi

    if [[ "$SELECTED" == "🧾 View all logs" ]]; then
      $CMD -f "$DATA_DIR/docker-compose.yml" logs -f
    elif [[ "$SELECTED" == 🐳* ]]; then
      CONTAINER_NAME="${SELECTED#🐳 }"
      docker logs -f "$CONTAINER_NAME" || echo "❌ Không thể xem log của container $CONTAINER_NAME"
    else
      echo "❌ Bạn chưa chọn gì cả!"
    fi
  fi

  read -rp "🔁 Nhấn Enter để quay lại menu..."
}

# ---------- Menu ----------
while true; do
  echo ""
  echo "=============================="
  echo "🛠 AZTEC PROVER DEPLOYMENT TOOL"
  echo "=============================="

  OPTION=$(printf "1️⃣  Cài đặt Prover\n2️⃣  Gỡ Prover\n3️⃣  Xem Logs\n4️⃣  Thoát" | \
    fzf --height=10 --border --prompt="👉 Chọn tùy chọn: " --ansi --reverse)

  case "$OPTION" in
    "1️⃣  Cài đặt Prover") install_prover ;;
    "2️⃣  Gỡ Prover") delete_prover ;;
    "3️⃣  Xem Logs") view_logs ;;
    "4️⃣  Thoát") echo "👋 Tạm biệt!"; exit 0 ;;
    *) echo "❌ Tùy chọn không hợp lệ!" ;;
  esac
done


