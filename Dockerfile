
FROM nvidia/cuda:12.6.0-cudnn-runtime-ubuntu22.04

RUN apt-get update
RUN apt-get install software-properties-common -y
RUN add-apt-repository ppa:deadsnakes/ppa

# 파이썬, GIT, wget
RUN apt install python3.10 python3.10-venv python3.10-dev python3-pip git wget -y
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# Fix Issue : "Cannot locate TCMalloc.."
RUN apt-get install libgoogle-perftools4 libtcmalloc-minimal4 -y
# Fix Issue : "bc: command not found.."
RUN apt-get install bc
# Fix Issue : "ImportError: libGL.so.1: cannot open shared object file: No such file or directory"
RUN apt-get update && apt-get install ffmpeg libsm6 libxext6  -y

WORKDIR /app

# Stable Diffusion Web-ui 클론
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

WORKDIR /app/stable-diffusion-webui

EXPOSE 7860

RUN chmod +x webui.sh

ENTRYPOINT [ "bash", "webui.sh", "-f" ]