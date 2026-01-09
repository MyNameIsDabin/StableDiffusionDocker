FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

# 1. 시스템 패키지 설치 (Root 권한 필요)
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    software-properties-common \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
    libcairo2-dev \
    pkg-config \
    git \
    wget \
    curl \
    bc \
    libprotobuf-dev \
    protobuf-compiler \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update

# 2. Python 3.11 설치
RUN apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3.11-distutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. Python 기본 버전 설정 & pip 설치
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# 4. 사용자 생성 및 작업 폴더 권한 설정
# 여기서 /app 폴더를 미리 만들고 sduser에게 줍니다.
WORKDIR /app
RUN useradd -m -s /bin/bash sduser && \
    chown -R sduser:sduser /app

# ==========================================================
# [중요] 이제부터 모든 작업은 sduser 권한으로 실행합니다.
# 이렇게 하면 나중에 chown을 할 필요도 없고, Permission Error가 원천 봉쇄됩니다.
# ==========================================================
USER sduser

# 5. Git 설정 (sduser)
RUN git config --global --add safe.directory '*'

# 6. PIP 제약 조건 설정 (Numpy 2.0 방지)
RUN echo "numpy<2" > /app/constraints.txt
ENV PIP_CONSTRAINT="/app/constraints.txt"

# 7. 레포지토리 클론 (sduser가 직접 하므로 권한 문제 없음)
RUN git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

WORKDIR /app/stable-diffusion-webui

# 8. venv 생성 및 핵심 라이브러리 "강제" 설치 (버전 고정)
# - PyTorch 2.1.2 + CUDA 12.1 (가장 안정적)
# - Xformers 0.0.23.5 (위 토치 버전과 짝꿍)
# - Mediapipe, Protobuf 버전 고정 (AttributeError 해결)
RUN python3.11 -m venv venv && \
    ./venv/bin/pip install --upgrade pip && \
    ./venv/bin/pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu121 && \
    ./venv/bin/pip install xformers==0.0.23.5 && \
    ./venv/bin/pip install "numpy<2" svglib basicsr "mediapipe>=0.10.9,<0.10.15" "protobuf==3.20.3"

# 9. 환경 변수 설정
# TORCH_COMMAND를 비워두거나 echo로 설정하면 webui.sh가 토치 설치를 건너뜁니다(이미 했으니까).
ENV python_cmd="python3.11"
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
ENV COMMANDLINE_ARGS="--listen --enable-insecure-extension-access --xformers --api --skip-torch-cuda-test"

EXPOSE 7860

# webui.sh 실행 권한 (sduser 소유이므로 chmod 가능)
RUN chmod +x webui.sh

ENTRYPOINT [ "bash", "webui.sh" ]