FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

# 1. 시스템 패키지 설치
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
    && apt-get update \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Python 3.11 설치
RUN apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3.11-distutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. pip 설치
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# 4. 사용자 생성 및 권한 설정
WORKDIR /app
RUN useradd -m -s /bin/bash sduser && \
    chown -R sduser:sduser /app

# 작업 유저 전환
USER sduser

# 5. Git 보안 설정
RUN git config --global --add safe.directory '*'

# 6. PIP 제약 조건 (Numpy 2.0 방지)
RUN echo "numpy<2" > /app/constraints.txt
ENV PIP_CONSTRAINT="/app/constraints.txt"

# 7. 레포지토리 클론
RUN git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

WORKDIR /app/stable-diffusion-webui

# 8. 라이브러리 설치 (수정됨)
# torch는 성공했으니 그대로 두고, xformers 버전만 로그에 있는 걸로 수정했습니다.
RUN python3.11 -m venv venv && \
    ./venv/bin/pip install --no-cache-dir --upgrade pip && \
    ./venv/bin/pip install --no-cache-dir torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu121 && \
    ./venv/bin/pip install --no-cache-dir xformers==0.0.23.post1 && \
    ./venv/bin/pip install --no-cache-dir "numpy<2" svglib basicsr "mediapipe>=0.10.9,<0.10.15" "protobuf==3.20.3"

# 9. 환경 변수 설정
ENV python_cmd="python3.11"
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
# --skip-torch-cuda-test: 설치 완료했으므로 스킵
ENV COMMANDLINE_ARGS="--listen --enable-insecure-extension-access --xformers --api --skip-torch-cuda-test"

EXPOSE 7860

# 실행 권한
RUN chmod +x webui.sh

ENTRYPOINT [ "bash", "webui.sh" ]