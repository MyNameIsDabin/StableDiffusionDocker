#!/bin/bash
set -e

echo "========================================"
echo " ComfyUI 호스트 폴더 설정 시작"
echo "========================================"

# SD WebUI 와 공유하는 기존 폴더들
SHARED_DIRS=(
    /app/models/Stable-diffusion
    /app/models/Lora
    /app/models/VAE
    /app/models/VAE-approx
    /app/models/ControlNet
    /app/models/ESRGAN
    /app/models/clip
    /app/models/clip_vision
    /app/models/hypernetworks
    /app/models/unet
    /app/models/diffusion_models
    /app/embeddings
)

# ComfyUI 전용 폴더들.
# models 는 통짜로 마운트되므로 하위 폴더는 ComfyUI가 알아서 만든다.
COMFY_DIRS=(
    /app/comfyui/models
    /app/comfyui/custom_nodes
    /app/comfyui/user
    /app/comfyui/temp
    /app/comfyui/user/hf-cache
    /app/outputs
    /app/inputs
)

echo ""
for dir in "${SHARED_DIRS[@]}" "${COMFY_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "[skip] $dir (이미 존재)"
    else
        sudo mkdir -p "$dir"
        echo "[생성] $dir"
    fi
done

echo ""
echo "권한 설정 (chmod 777)..."
sudo chmod -R 777 /app/models
sudo chmod -R 777 /app/embeddings
sudo chmod -R 777 /app/comfyui
sudo chmod -R 777 /app/outputs
sudo chmod -R 777 /app/inputs

echo ""
echo "========================================"
echo " ComfyUI 호스트 폴더 설정 완료"
echo "========================================"
echo ""
echo "  다음 단계:"
echo "    docker compose up -d --build"
echo "    docker system prune -f          # 빌드 캐시 정리"
echo ""
echo "  접속:"
echo "    http://<서버IP>:8188"
echo ""
echo "  ※ 이미 돌아가던 컨테이너가 있다면 재생성 전에 README.md 의"
echo "     '재빌드 전 반드시 확인할 것' 을 먼저 읽으세요."
echo ""
