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

# 3. Python 기본 버전 설정 & pip 설치
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

WORKDIR /app

# ========================================================
# [핵심 수정] PIP 제약 조건(Constraint) 설정
# 이 설정이 있으면, 실행 중에 어떤 확장기능이 설치되더라도
# pip가 numpy 2.0 이상을 설치하는 것을 시스템 레벨에서 거부합니다.
# ========================================================
RUN echo "numpy<2" > /app/constraints.txt
ENV PIP_CONSTRAINT="/app/constraints.txt"

# 4. 사용자 생성
RUN useradd -m -s /bin/bash sduser && \
    chown -R sduser:sduser /app

USER sduser

# 5. 레포지토리 클론
RUN git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

WORKDIR /app/stable-diffusion-webui

# 6. venv 생성 및 초기 패키지 설치
# (PIP_CONSTRAINT 덕분에 여기서도 안전하게 설치됨)
RUN python3.11 -m venv venv && \
    ./venv/bin/pip install "numpy<2"

# 7. 환경 변수 설정
ENV python_cmd="python3.11"
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
# 주의: --reinstall-xformers는 매번 빌드하므로 시간이 오래 걸립니다. 
# 초기 설치 후에는 제거하는 것이 좋습니다.
ENV COMMANDLINE_ARGS="--listen --enable-insecure-extension-access --xformers --api"

EXPOSE 7860

USER root
RUN chmod +x webui.sh
USER sduser

ENTRYPOINT [ "bash", "webui.sh" ]