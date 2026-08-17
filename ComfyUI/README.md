# ComfyUI on Docker

EC2 인스턴스에서 ComfyUI를 GPU로 돌리는 구성.

```
setup.sh              호스트 폴더 생성 + 권한
docker-compose.yml    볼륨 마운트 정의
Dockerfile            이미지 빌드
entrypoint.sh         시작 시 커스텀 노드 의존성 복구
requirements.extra.txt 수동 복구용 패키지 스냅샷
```

## ⚠️ 재빌드 전 반드시 확인할 것

**컨테이너를 재생성하면 마운트되지 않은 경로의 데이터는 전부 사라진다.**

`docker compose up -d --build`, `--force-recreate`, `docker rm` 은 모두 컨테이너
쓰기 레이어를 폐기한다. 마운트되지 않은 곳에 모델이 쌓여 있으면 그대로 날아간다.

재생성하기 전에 항상 이걸 먼저 확인한다:

```bash
# 쓰기 레이어에 뭐가 얼마나 쌓였는지
sudo docker system df
UP=$(sudo docker inspect comfyui --format '{{.GraphDriver.Data.UpperDir}}')
sudo du -xh --max-depth=4 "$UP" | sort -h | tail -15
```

수백 MB 이상 나오는 경로가 있으면, 컨테이너를 **정지**(재생성 아님)한 뒤
해당 파일을 호스트 폴더로 옮기고 나서 재생성한다.

```bash
sudo docker stop comfyui
sudo mv "$UP/app/ComfyUI/models/<폴더>/"* /app/comfyui/models/<폴더>/
```

`docker cp` 대신 `mv` 를 쓴다. 같은 파일시스템 안 이동이라 즉시 끝나고
추가 디스크 공간을 쓰지 않는다. 디스크가 빠듯할 때 `cp` 는 실패한다.

### 2026-08-17에 실제로 겪은 일

PC의 `docker-compose.yml` 에는 `diffusion_models` 마운트를 추가해뒀지만,
**인스턴스로 파일을 옮기지 않아** 실제 컨테이너는 그 마운트 없이 만들어져 있었다.
그래서 civitai에서 받은 모델 24GB가 호스트 폴더에는 보이지 않고 컨테이너 쓰기
레이어에만 쌓여서 "모델 폴더는 비었는데 디스크만 줄어드는" 상태가 됐다.

교훈 두 가지.

1. **PC에서 compose를 고쳤으면 인스턴스로 복사해야 한다.** 이 폴더는 인스턴스의
   `/home/ubuntu/StableDiffusionDocker/ComfyUI` 와 같아야 한다.
2. **복사한 뒤에도 컨테이너를 재생성해야 반영된다.** 마운트는 컨테이너 생성
   시점에 고정된다.

지금 마운트가 실제로 어떻게 걸려 있는지는 파일이 아니라 컨테이너에게 물어야 한다:

```bash
sudo docker inspect comfyui --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'
```

## 마운트 구조

모델은 두 층으로 마운트한다.

1. `/app/comfyui/models` → `/app/ComfyUI/models` 를 **통째로** 깐다.
   ComfyUI가 업데이트되며 새 카테고리(`text_encoders`, `detection`,
   `audio_encoders` …)가 계속 생기는데, 하나씩 마운트하면 빠뜨린 게 쓰기 레이어에
   쌓인다. 통짜로 깔면 새 카테고리도 자동으로 호스트에 남는다.

2. 그 위에 SD WebUI와 공유하는 폴더들을 덮는다.
   도커가 마운트 지점을 경로 깊이 순으로 적용하므로 아래 항목이 나중에 적용된다.

| 호스트 | 컨테이너 |
| --- | --- |
| `/app/models/Stable-diffusion` | `models/checkpoints` |
| `/app/models/unet` | `models/unet` |
| `/app/models/diffusion_models` | `models/diffusion_models` |
| `/app/models/Lora` | `models/loras` |
| `/app/models/VAE` | `models/vae` |
| `/app/embeddings` | `models/embeddings` |
| (그 외 전부) | `/app/comfyui/models/<이름>` |

### checkpoints 와 diffusion_models 는 다르다

- **checkpoints** — UNet + CLIP + VAE가 한 파일에 든 통짜 모델. Load Checkpoint 노드.
- **diffusion_models** — 확산 가중치만 든 파일. CLIP과 VAE를 따로 물려야 한다.
  Load Diffusion Model 노드.

ComfyUI는 `models/unet` 과 `models/diffusion_models` **둘 다** diffusion_models
카테고리로 스캔한다(`folder_paths.py`). 어느 쪽에 넣어도 같은 드롭다운에 뜬다.

civitai 다운로더가 파일을 항상 맞는 폴더에 넣지는 않는다. 어느 쪽인지는 파일
안을 보면 확실하다 — `text_encoders`/`vae` 키가 있으면 checkpoints 다.

## 커스텀 노드 의존성

`custom_nodes` 는 마운트되어 살아남지만, 의존 패키지는 컨테이너 안 venv에 깔린다.
재빌드하면 **노드 코드는 있는데 임포트만 실패하는** 상태가 된다.

`entrypoint.sh` 가 이걸 처리한다. 컨테이너가 새로 만들어졌을 때만
각 노드의 `requirements.txt` 를 다시 설치하고, 표식 파일을 남겨 이후 재시작에서는
건너뛴다. 표식은 마운트되지 않은 경로(`/app/ComfyUI/.node-deps-installed`)에 둬야
재빌드 시 다시 설치된다.

첫 기동이 몇 분 걸릴 수 있다. 건너뛰려면 compose에서 `SKIP_NODE_DEPS=1`.

`requirements.txt` 가 없는 노드 때문에 뭔가 깨지면 `requirements.extra.txt` 로 복구한다.

## 사용법

### 새 인스턴스에 처음 올릴 때

이 저장소를 받아서 그대로 실행하면 된다.

```bash
./setup.sh
docker compose up -d --build
docker system prune -f
```

접속: `http://<서버IP>:8188`

### ⚠️ 이미 돌아가고 있는 인스턴스에서는 그대로 하면 안 된다

위 명령을 기존 인스턴스에서 실행하면 **이미지를 다시 빌드하고 컨테이너를 재생성**하므로
쓰기 레이어가 폐기된다. 아래 '다음 재생성 전에 할 일'을 먼저 끝내고 나서 실행할 것.

## 현재 운영 중인 인스턴스 상태 (2026-08-17 기준)

컨테이너를 재생성하지 않고 데이터만 밖으로 빼둔 상태다.
아직 마운트가 아니라 **심볼릭 링크**로 연결되어 있다.

| 컨테이너 안 | → | 호스트 실제 위치 |
| --- | --- | --- |
| `~/.cache/huggingface` | 링크 | `/app/comfyui/user/hf-cache` (11GB) |
| `models/LLM` | 링크 | `/app/comfyui/user/models/LLM` |
| `models/RMBG` | 링크 | `/app/comfyui/user/models/RMBG` |

링크가 `user` 아래를 가리키는 이유는, 재생성 없이 쓸 수 있는 마운트가
`/app/ComfyUI/user` 뿐이었기 때문이다. 링크 자체는 쓰기 레이어에 있으므로
재생성하면 사라지고, 그때는 정식 마운트가 대신한다.

모델 두 개는 이미 정식 마운트 폴더로 옮겨져 있다.

- `zImageTurboBaseAIO...safetensors` → `/app/models/Stable-diffusion` (통짜 체크포인트)
- `anima_preview3Base.safetensors` → `/app/models/unet` (확산 가중치)

이 작업 후 쓰기 레이어는 40.3GB → 2.2GB. 남은 2.2GB는 venv(설치된 패키지)뿐이고,
그건 `entrypoint.sh` 가 재생성 시 자동으로 복구한다.

## 다음 재생성 전에 할 일

`docker compose up -d --build` 또는 `--force-recreate` 를 하기 직전에 딱 한 가지만 하면 된다.

```bash
# LLM/RMBG 를 통짜 models 마운트 자리로 옮긴다.
# 재생성하면 /app/comfyui/models 가 models 전체를 덮으므로,
# user 아래에 있으면 ComfyUI가 찾지 못한다.
sudo mkdir -p /app/comfyui/models
sudo mv /app/comfyui/user/models/LLM  /app/comfyui/models/
sudo mv /app/comfyui/user/models/RMBG /app/comfyui/models/
sudo rmdir /app/comfyui/user/models
```

허깅페이스 캐시는 옮길 필요 없다. `docker-compose.yml` 이 지금 위치
(`/app/comfyui/user/hf-cache`)를 그대로 마운트하도록 되어 있다.

그다음 항상 하던 대로 쓰기 레이어를 확인하고 진행한다.

```bash
UP=$(sudo docker inspect comfyui --format '{{.GraphDriver.Data.UpperDir}}')
sudo du -xh --max-depth=4 "$UP" | sort -h | tail -15   # venv 말고 큰 게 있으면 먼저 빼낼 것
./setup.sh
docker compose up -d --build
```

첫 기동 때 `entrypoint.sh` 가 커스텀 노드 의존성을 다시 설치하므로 몇 분 걸린다.

## 디스크 점검

```bash
df -h /
sudo docker system df                 # Containers 항목이 크면 위험 신호
sudo du -xh --max-depth=1 /app/comfyui/models | sort -h | tail
```

`docker system df` 의 **Containers** 크기는 쓰기 레이어다. 여기가 수 GB로 커졌다면
마운트가 빠진 경로에 데이터가 쌓이고 있다는 뜻이다.
