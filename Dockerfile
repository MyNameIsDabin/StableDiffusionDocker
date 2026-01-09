FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

# 1. 시스템 패키지 설치
# [수정] libcairo2-dev, pkg-config 추가 (이게 없어서 svglib/pycairo 설치가 터짐)
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

# 4. Git 보안 예외 설정
RUN git config --global --add safe.directory '*'

# 5. 사용자 생성
RUN useradd -m -s /bin/bash sduser

# 6. PIP 제약 조건 (Numpy 2.0 방지)
RUN echo "numpy<2" > /app/constraints.txt
ENV PIP_CONSTRAINT="/app/constraints.txt"

# 7. 레포지토리 클론
RUN git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

WORKDIR /app/stable-diffusion-webui

# 8. venv 생성 및 라이브러리 설치 (단계 분리)
# [수정] 
# 1. venv 생성
# 2. numpy 고정
# 3. svglib 설치 (이제 시스템 헤더가 있어서 성공함)
# 4. basicsr, mediapipe는 webui.sh가 실행될 때 설치하도록 둠 (미리 설치하면 torch 의존성 때문에 더 꼬임)
RUN python3.11 -m venv venv && \
    ./venv/bin/pip install "numpy<2" && \
    ./venv/bin/pip install svglib

# 9. 권한 일괄 수정
RUN chown -R sduser:sduser /app

# 10. 환경 변수 설정
ENV python_cmd="python3.11"
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
ENV COMMANDLINE_ARGS="--listen --enable-insecure-extension-access --xformers --api"

EXPOSE 7860

# 11. 실행 유저 전환
USER sduser
RUN chmod +x webui.sh

ENTRYPOINT [ "bash", "webui.sh" ]