AWS로 생성한 인스턴스에 NVIDIA 드라이버와 CUDA가 설치되어 있는지 확인 필요
```
ubuntu@ip-xxx-xx-xx-xxx:~$ nvidia-smi
Sun Mar  2 12:19:48 2025
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 570.86.15              Driver Version: 570.86.15      CUDA Version: 12.8     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  Tesla T4                       On  |   00000000:00:1E.0 Off |                    0 |
| N/A   20C    P8             13W /   70W |       1MiB /  15360MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

만약 Dockerfile이 변경되었다면 이미지 다시 빌드
```
docker build -t stable-diffusion-webui .
```

```
docker rm -f sd-webui
docker run --restart always --gpus all -d -p 7860:7860 \
    -v /app/models/Stable-diffusion:/app/stable-diffusion-webui/models/Stable-diffusion \
    -v /app/models/Lora:/app/stable-diffusion-webui/models/Lora \
    -v /app/extensions:/app/stable-diffusion-webui/extensions \
    -v /app/embeddings:/app/stable-diffusion-webui/embeddings \
    -e COMMANDLINE_ARGS="--xformers --reinstall-xformers --listen --enable-insecure-extension-access" \
    --name sd-webui stable-diffusion-webui
```

### Fix : AssertionError: extension access disabled because of command line flags (확장프로그램 설치시)

/app/stable-diffusion-webui/extensions

컨테이너의 마운트 정보 조회 (제대로 호스트 폴더에 볼륨이 마운트 됐는지 확인)
```
docker inspect sd-webui
docker exec -it sd-webui ls /app/stable-diffusion-webui/models/Stable-diffusion
```

모든 컨테이너 한 번에 중지하고 제거하기
```
docker stop $(docker ps -aq) && docker rm $(docker ps -aq)
docker ps -a
```

로그 실시간 확인
```
docker logs -f --tail 100 sd-webui
```
