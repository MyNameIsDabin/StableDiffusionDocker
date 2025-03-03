#!/bin/bash

# wget 으로 구글 드라이브의 파일을 다운로드 받는 방법

# 스크립트 사용법 출력 함수
usage() {
    echo "Usage: $0 FILEID FILENAME"
    echo "Example: $0 1a2B3cD4EfGh5Ij6KlM myfile.zip"
    exit 1
}

# 매개변수 체크
if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    usage
fi

FILEID="$1"
FILENAME="$2"

# 임시 쿠키 파일 생성
COOKIE_FILE=$(mktemp)

# 첫 번째 요청을 통해 보안 토큰 획득
CONFIRM=$(wget --no-check-certificate --quiet --show-progress \
    --save-cookies "$COOKIE_FILE" --keep-session-cookies \
    "https://docs.google.com/uc?export=download&id=${FILEID}" -O- \
    | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p')

# 보안 토큰을 사용하여 파일 다운로드
wget --no-check-certificate --quiet --show-progress \
    --load-cookies "$COOKIE_FILE" \
    "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${FILEID}" \
    -O "${FILENAME}"

# 임시 쿠키 파일 삭제
rm -f "$COOKIE_FILE"

echo "Download finished: ${FILENAME}"