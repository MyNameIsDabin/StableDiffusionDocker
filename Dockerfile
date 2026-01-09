FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

# 1. 시스템 패키지 설치
# (이전 단계에서 pycairo 빌드 에러를 잡기 위해 넣었던 패키지들 유지)
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

# 4. 사용자 생성
RUN useradd -m -s /bin/bash sduser

# 5. [중요] Git 보안 설정 (Global)
# "dubious ownership" 에러를 원천 차단하기 위해 모든 디렉토리를 신뢰하도록 설정
RUN git config --global --add safe.directory '*'

# 6. PIP 제약 조건 (Numpy 2.0 방지)
RUN echo "numpy<2" > /app/constraints.txt
ENV PIP_CONSTRAINT="/app/constraints.txt"

# 7. 레포지토리 클론
RUN git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

WORKDIR /app/stable-diffusion-webui

# 8. venv 생성 및 라이브러리 강제 설치
# Root 권한으로 확실하게 설치한 뒤, 나중에 권한을 넘깁니다.
# 에러 떴던 basicsr, mediapipe를 여기서 강제로 꽂아넣습니다.
RUN python3.11 -m venv venv && \
    ./venv/bin/pip install "numpy<2" && \
    ./venv/bin/pip install svglib basicsr mediapipe

# 9. [핵심] 소유권 대통합 (Permission Denied 해결)
# /app 폴더 전체의 주인을 sduser로 변경합니다.
# 이 단계가 있어야 'temp' 폴더 생성이나 파일 쓰기 권한 에러가 사라집니다.
RUN chown -R sduser:sduser /app

# 10. 환경 변수 설정
ENV python_cmd="python3.11"
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
ENV COMMANDLINE_ARGS="--listen --enable-insecure-extension-access --xformers --api"

EXPOSE 7860

# 11. 실행 유저 전환
USER sduser

# [중요] 사용자 레벨에서도 Git 보안 설정 한 번 더 (확실하게 하기 위함)
RUN git config --global --add safe.directory '*'

# 실행 권한 부여 (이미 chown으로 sduser 소유라 chmod 안해도 되지만 안전하게)
RUN chmod +x webui.sh

ENTRYPOINT [ "bash", "webui.sh" ]