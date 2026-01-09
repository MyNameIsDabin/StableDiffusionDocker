#!/bin/bash

# Google Drive 파일을 wget으로 다운로드 받는 스크립트

# 사용법 출력 함수
usage() {
    echo "Usage: $0 FILEID FILENAME"
    echo "Example: $0 1a2B3cD4EfGh5Ij6KlM myfile.zip"
    exit 1
}

# 인자 개수 확인
if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    usage
fi

FILEID="$1"
FILENAME="$2"

# 임시 쿠키 파일 생성
COOKIE_FILE=$(mktemp)

# 첫 번째 요청으로 확인 토큰 추출
CONFIRM=$(wget --quiet --save-cookies "$COOKIE_FILE" --keep-session-cookies --no-check-certificate \
    "https://docs.google.com/uc?export=download&id=${FILEID}" -O- \
    | grep -o 'confirm=[0-9A-Za-z_]*' | sed 's/confirm=//')

# 확인 토큰이 없는 경우 스크립트 종료
if [ -z "$CONFIRM" ]; then
    echo "Error: Unable to retrieve confirmation token. 파일이 공개적으로 공유되었는지 확인하세요."
    rm -f "$COOKIE_FILE"
    exit 1
fi

# 확인 토큰을 사용하여 파일 다운로드
wget --no-check-certificate --load-cookies "$COOKIE_FILE" \
    "https://docs.google.com/uc?export=download&confirm=${CONFIRM}&id=${FILEID}" \
    -O "${FILENAME}"

# 임시 쿠키 파일 삭제
rm -f "$COOKIE_FILE"

echo "Download finished: ${FILENAME}"
