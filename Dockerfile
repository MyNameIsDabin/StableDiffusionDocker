FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

# 1. 시스템 패키지 설치
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    software-properties-common \
    git \
    wget \
    curl \
    bc \
    libgl1 \
    libglib2.0-0 \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
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

# 3. Python 기본 버전 설정
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

WORKDIR /app

# 4. 사용자 생성
RUN useradd -m -s /bin/bash sduser && \
    chown -R sduser:sduser /app

USER sduser

# 5. 레포지토리 클론
RUN git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

WORKDIR /app/stable-diffusion-webui

# ========================================================
# [중요] Numpy 호환성 에러 수정 파트
# webui.sh가 실행되기 전에 venv를 먼저 만들고, 
# 호환되는 numpy(<2)를 강제로 설치하여 2.0 설치를 막습니다.
# ========================================================
RUN python3.11 -m venv venv && \
    ./venv/bin/pip install "numpy<2"

# 6. 환경 변수 설정
ENV python_cmd="python3.11"
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
ENV COMMANDLINE_ARGS="--listen --enable-insecure-extension-access --xformers --api"

EXPOSE 7860

USER root
RUN chmod +x webui.sh
USER sduser

ENTRYPOINT [ "bash", "webui.sh" ]