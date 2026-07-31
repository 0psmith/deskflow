#!/bin/bash
# 로컬 빌드 전용 코드서명 인증서를 login 키체인에 한 번만 만들어 둔다.
#
# ad-hoc 서명은 빌드마다 cdhash 가 바뀌어 macOS 가 매번 다른 앱으로 취급한다
# (= 손쉬운 사용·입력 모니터링 권한을 매번 다시 켜야 함). 고정된 인증서로 서명하면
# 서명 신원이 그대로 유지돼 권한이 재빌드 후에도 살아남는다.
#
# 키체인 신뢰 설정 변경 때문에 암호 입력 프롬프트가 한 번 뜬다.
set -euo pipefail

NAME="Deskflow Local Build"
DIR="$HOME/.config/deskflow-signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "이미 존재합니다:"
  security find-identity -v -p codesigning | grep "$NAME"
  exit 0
fi

mkdir -p "$DIR" && chmod 700 "$DIR"
cd "$DIR"

echo "==> 인증서 생성 ($NAME, 유효기간 10년)"
rm -f bundle.p12
cat > openssl.cnf <<'EOF'
[req]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[dn]
CN = Deskflow Local Build

[ext]
basicConstraints       = critical,CA:false
keyUsage               = critical,digitalSignature
extendedKeyUsage       = critical,codeSigning
subjectKeyIdentifier   = hash
EOF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout key.pem -out cert.pem -config openssl.cnf >/dev/null 2>&1

# `security import -f openssl` 은 traditional RSA 형식을 기대하는데 openssl req 는
# PKCS#8("BEGIN PRIVATE KEY")로 쓴다. 변환하지 않으면 "Unknown format in import".
openssl rsa -in key.pem -traditional -out key-trad.pem >/dev/null 2>&1
chmod 600 key.pem key-trad.pem

# PKCS#12 는 쓰지 않는다. OpenSSL 3 기본 암호화(AES-256 + PBKDF2-SHA256)를 Apple
# 키체인이 읽지 못해 "MAC verification failed" 로 실패한다. 키와 인증서를 따로 넣는다.
echo "==> login 키체인에 가져오기 (codesign 사용 허용)"
security import key-trad.pem -k "$KEYCHAIN" -t priv -f openssl -T /usr/bin/codesign -T /usr/bin/security
security import cert.pem     -k "$KEYCHAIN" -t cert -f openssl -T /usr/bin/codesign -T /usr/bin/security

echo "==> 코드서명 용도로 신뢰 설정 (암호 프롬프트가 뜹니다)"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" cert.pem

echo "==> 확인"
if security find-identity -v -p codesigning | grep -q "$NAME"; then
  security find-identity -v -p codesigning | grep "$NAME"
  echo
  echo "완료. 이제 ~/deskflow-deploy.sh 가 이 인증서로 서명합니다."
  echo "다음 배포 후 권한을 한 번만 다시 켜면, 그 이후 재빌드에서는 유지됩니다."
else
  echo "실패 — 인증서가 코드서명 신원으로 잡히지 않았습니다." >&2
  exit 1
fi
