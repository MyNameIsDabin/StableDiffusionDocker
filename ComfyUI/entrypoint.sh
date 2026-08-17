#!/bin/bash
# 이미지를 다시 빌드하면 venv가 초기화되면서 ComfyUI-Manager로 설치했던
# 커스텀 노드 의존성이 전부 사라진다. custom_nodes 폴더 자체는 마운트되어
# 살아남기 때문에, 노드 코드는 있는데 임포트만 실패하는 상태가 된다.
#
# 그래서 컨테이너가 새로 만들어졌을 때만 각 노드의 requirements.txt를 다시 설치한다.
# 표식 파일을 마운트되지 않은 경로에 두는 게 핵심이다. 마운트된 곳에 두면
# 재빌드 후에도 표식이 남아 있어 설치를 건너뛴다.

set -u

PIP=/app/ComfyUI/venv/bin/pip
STAMP=/app/ComfyUI/.node-deps-installed

# ---------------------------------------------------------------
# 마운트 점검
#
# 마운트되지 않은 경로에 모델을 받으면 컨테이너 안에만 쌓인다.
# 호스트 폴더는 비어 보이는데 디스크만 줄고, 컨테이너를 재생성하면 통째로 날아간다.
# 2026-08-17에 이걸로 24GB를 잃을 뻔했다. 조용히 넘어가지 않도록 시작할 때 확인한다.
# ---------------------------------------------------------------

is_mount() {
    awk -v target="$1" '$5 == target { found = 1 } END { exit !found }' /proc/self/mountinfo
}

check_mounts() {
    missing=""
    # models 를 통째로 마운트하면 그 아래 어떤 카테고리가 새로 생겨도 호스트에 남는다.
    for dir in /app/ComfyUI/models /app/ComfyUI/custom_nodes /app/ComfyUI/user \
               /app/ComfyUI/output /app/ComfyUI/input /home/comfyuser/.cache/huggingface; do
        is_mount "$dir" || missing="$missing $dir"
    done

    if [ -n "$missing" ]; then
        echo "==============================================================="
        echo " 경고: 아래 경로가 호스트에 마운트되어 있지 않습니다."
        for dir in $missing; do echo "   - $dir"; done
        echo ""
        echo " 여기에 쌓이는 파일은 컨테이너를 재생성하면 사라집니다."
        echo " docker-compose.yml 을 인스턴스로 복사했는지, 복사한 뒤"
        echo " 컨테이너를 재생성했는지 확인하세요. 마운트는 생성 시점에 고정됩니다."
        echo "   docker inspect comfyui --format '{{range .Mounts}}{{.Destination}}{{println}}{{end}}'"
        echo "==============================================================="
    else
        echo "[mount] 주요 경로가 모두 호스트에 연결되어 있습니다."
    fi
}

check_mounts

install_node_deps() {
    local found=0
    for req in /app/ComfyUI/custom_nodes/*/requirements.txt; do
        [ -f "$req" ] || continue
        found=1
        echo "[deps] $(dirname "$req" | xargs basename)"
        # 노드 하나가 실패해도 ComfyUI 자체는 뜨는 게 낫다
        "$PIP" install --no-cache-dir -r "$req" || echo "[deps] 실패(무시): $req"
    done
    [ "$found" = "1" ] || echo "[deps] requirements.txt 를 가진 노드가 없습니다"
}

if [ "${SKIP_NODE_DEPS:-0}" = "1" ]; then
    echo "[deps] SKIP_NODE_DEPS=1 이라 건너뜁니다"
elif [ -f "$STAMP" ]; then
    echo "[deps] 이미 설치된 컨테이너입니다 (건너뜀)"
else
    echo "[deps] 새 컨테이너입니다. 커스텀 노드 의존성을 설치합니다..."
    install_node_deps
    date -u +%FT%TZ > "$STAMP"
    echo "[deps] 완료"
fi

exec /app/ComfyUI/venv/bin/python main.py --listen 0.0.0.0 --enable-cors-header "$@"
