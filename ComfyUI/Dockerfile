FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04

# 1. 시스템 패키지 + Python 3.13 설치
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    software-properties-common \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
    git \
    wget \
    curl \
    ffmpeg \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y \
    python3.13 \
    python3.13-venv \
    python3.13-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. pip 설치
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13

# 3. 사용자 생성 및 권한 설정
WORKDIR /app
RUN useradd -m -s /bin/bash comfyuser && \
    chown -R comfyuser:comfyuser /app

USER comfyuser

# 4. Git 보안 설정
RUN git config --global --add safe.directory '*'

# 5. ComfyUI 클론
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /app/ComfyUI

# 6. 가상환경 및 라이브러리 설치
# PyTorch + CUDA 12.8 (cu128) — 호스트 드라이버 CUDA ≥ 12.8 필요
RUN python3.13 -m venv venv && \
    ./venv/bin/pip install --no-cache-dir --upgrade pip && \
    ./venv/bin/pip install --no-cache-dir \
        torch \
        torchvision \
        torchaudio \
        --index-url https://download.pytorch.org/whl/cu128 && \
    ./venv/bin/pip install --no-cache-dir -r requirements.txt

# 7. ComfyUI-Manager 설치 (선택사항이지만 권장)
RUN cd custom_nodes && \
    git clone https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    ../../venv/bin/pip install --no-cache-dir -r requirements.txt

# 8. 환경 변수
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4

# 9. 엔트리포인트
# 재빌드로 venv가 초기화되면 커스텀 노드 의존성을 다시 깔아준다.
USER root
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown comfyuser:comfyuser /app/entrypoint.sh
USER comfyuser

EXPOSE 8188

# --listen: 외부 접속 허용
# --enable-cors-header: CORS 허용 (API 사용 시 필요)
ENTRYPOINT ["/app/entrypoint.sh"]
