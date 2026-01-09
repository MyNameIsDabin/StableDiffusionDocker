FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

# 1. 시스템 패키지 설치 및 PPA 추가
# README의 Debian-based 필수 패키지: wget git python3 python3-venv libgl1 libglib2.0-0
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

# 2. Python 3.11 설치 (README: "Only for 3.11" 섹션 대응)
RUN apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3.11-distutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. Python 기본 버전을 3.11로 변경 (편의성)
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# 4. pip 설치 (Python 3.11용)
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# 5. 작업 디렉토리 설정
WORKDIR /app

# 6. 일반 사용자 생성 (README: "normal, non-administrator, user" 권장 대응)
RUN useradd -m -s /bin/bash sduser && \
    chown -R sduser:sduser /app

# 7. 사용자로 전환
USER sduser

# 8. Stable Diffusion Web-ui 클론 (dev 브랜치)
RUN git clone -b dev https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

# 9. 작업 디렉토리 변경
WORKDIR /app/stable-diffusion-webui

# 10. 환경 변수 설정
# README: "Then set up env variable in launch script... export python_cmd='python3.11'"
ENV python_cmd="python3.11"
# TCMalloc 설정 (성능 최적화, README의 openSUSE 섹션 등에서 권장되는 사항)
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
# 외부 접속 허용 및 xformers 사용
ENV COMMANDLINE_ARGS="--listen --enable-insecure-extension-access --xformers --api"

# 11. 포트 노출
EXPOSE 7860

# 12. webui.sh 실행 권한 확인 (User root로 잠시 전환)
USER root
RUN chmod +x webui.sh
USER sduser

# 13. 실행
ENTRYPOINT [ "bash", "webui.sh" ]