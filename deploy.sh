#!/usr/bin/env bash
# ДЗ 2. Климов И. А., БИСТ-23-ПО-2, вариант 01.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${1:?укажите версию: bash deploy.sh 5.0}
PREFIX=klimov-01
PORT=8003
REGISTRY=localhost:6001
IMAGE=$REGISTRY/$PREFIX/probe:$VERSION

# 1. Включить Swarm, если он ещё выключен.
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" != active ]; then
  docker swarm init --advertise-addr eth0 > /dev/null
  docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'
fi

# 2. Создать реестр или запустить существующий остановленный контейнер.
if ! docker container inspect "$PREFIX-registry" > /dev/null 2>&1; then
  docker run -d --restart unless-stopped --name "$PREFIX-registry" \
    -p 6001:5000 -v "$PREFIX-registry:/var/lib/registry" registry:2
elif [ "$(docker inspect -f '{{.State.Running}}' "$PREFIX-registry")" != true ]; then
  docker start "$PREFIX-registry"
fi
SECONDS=0
until curl -sf -m 2 "$REGISTRY/v2/" > /dev/null; do
  if [ $SECONDS -ge 90 ]; then echo "реестр не ответил за 90 секунд" >&2; exit 1; fi
  sleep 1
done

# 3. Собрать образ нужной версии и отправить его в реестр.
docker build --build-arg VERSION="$VERSION" -t "$IMAGE" .
docker push "$IMAGE"

# 4. Передать VERSION в stack.yaml и дождаться развёртывания.
VERSION="$VERSION" docker stack deploy --detach=false -c stack.yaml "$PREFIX"

# 5. Дождаться ответа приложения, не дольше 90 секунд.
SECONDS=0
until curl -sf -m 2 "127.0.0.1:$PORT/notes" > /dev/null; do
  if [ $SECONDS -ge 90 ]; then echo "приложение не ответило за 90 секунд" >&2; exit 1; fi
  sleep 2
done
curl -s "127.0.0.1:$PORT/notes"; echo
