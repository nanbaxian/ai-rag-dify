#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RUNTIME_DIR="$ROOT_DIR/var/run"
LOG_DIR="$ROOT_DIR/var/log"

service_ensure_dirs() {
  mkdir -p "$RUNTIME_DIR" "$LOG_DIR"
}

service_pid_file() {
  local service_name="$1"
  echo "$RUNTIME_DIR/${service_name}.pid"
}

service_log_file() {
  local service_name="$1"
  echo "$LOG_DIR/${service_name}.log"
}

service_is_running() {
  local pid_file
  pid_file="$(service_pid_file "$1")"

  if [[ ! -f "$pid_file" ]]; then
    return 1
  fi

  local pid
  pid="$(cat "$pid_file")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

service_status() {
  local service_name="$1"
  local pid_file
  local log_file
  pid_file="$(service_pid_file "$service_name")"
  log_file="$(service_log_file "$service_name")"

  if service_is_running "$service_name"; then
    echo "$service_name is running (pid $(cat "$pid_file"))."
    echo "Log: $log_file"
  else
    echo "$service_name is not running."
    echo "Log: $log_file"
  fi
}

service_stop() {
  local service_name="$1"
  local pid_file
  pid_file="$(service_pid_file "$service_name")"

  if ! [[ -f "$pid_file" ]]; then
    echo "$service_name is not running."
    return 0
  fi

  local pid
  pid="$(cat "$pid_file")"
  if [[ -z "$pid" ]]; then
    rm -f "$pid_file"
    echo "$service_name pid file is empty; removed stale file."
    return 0
  fi

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    for _ in {1..30}; do
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done
  fi

  if kill -0 "$pid" 2>/dev/null; then
    echo "$service_name did not exit cleanly, sending SIGKILL."
    kill -9 "$pid" 2>/dev/null || true
  fi

  if [[ "$service_name" == "web" ]]; then
    service_kill_port 3002 || true
  fi

  rm -f "$pid_file"
  echo "$service_name stopped."
}

service_kill_port() {
  local port="$1"
  local listeners

  if ! command -v ss >/dev/null 2>&1; then
    echo "ss is not available; cannot inspect port $port."
    return 1
  fi

  listeners="$(
    ss -ltnp "sport = :$port" 2>/dev/null \
      | awk 'NR > 1 { if (match($0, /pid=([0-9]+)/, m)) print m[1] }' \
      | sort -u
  )"

  if [[ -z "$listeners" ]]; then
    return 0
  fi

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done <<< "$listeners"

  sleep 1

  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done <<< "$listeners"
}

service_load_env_file() {
  local env_file="$1"

  if [[ ! -f "$env_file" ]]; then
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" != *=* ]] && continue

    local key="${line%%=*}"
    local value="${line#*=}"

    key="${key%%[[:space:]]*}"
    key="${key##[[:space:]]*}"

    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      continue
    fi

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi

    export "$key=$value"
  done < "$env_file"
}

service_start_background_shell() {
  local service_name="$1"
  local workdir="$2"
  local command="$3"

  service_ensure_dirs

  local pid_file
  local log_file
  pid_file="$(service_pid_file "$service_name")"
  log_file="$(service_log_file "$service_name")"

  if service_is_running "$service_name"; then
    echo "$service_name is already running (pid $(cat "$pid_file"))."
    echo "Log: $log_file"
    return 0
  fi

  rm -f "$pid_file"

  (
    cd "$workdir"
    nohup bash -lc "$command" >>"$log_file" 2>&1 < /dev/null &
    printf '%s\n' "$!" > "$pid_file"
  )

  echo "$service_name started in background (pid $(cat "$pid_file"))."
  echo "Log: $log_file"
}

service_start_background_docker() {
  local service_name="$1"
  local container_name="$2"
  local run_command="$3"
  local log_file

  service_ensure_dirs
  log_file="$(service_log_file "$service_name")"

  if command -v docker >/dev/null 2>&1 && docker inspect "$container_name" >/dev/null 2>&1; then
    if docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q true; then
      echo "$service_name is already running (container $container_name)."
      echo "Log: $log_file"
      return 0
    fi
    docker rm -f "$container_name" >/dev/null 2>&1 || true
  fi

  mkdir -p "$LOG_DIR"
  (
    cd "$ROOT_DIR"
    nohup bash -lc "$run_command" >>"$log_file" 2>&1 < /dev/null &
    printf '%s\n' "$!" > "$RUNTIME_DIR/${service_name}.pid"
  )

  echo "$service_name started in background (pid $(cat "$RUNTIME_DIR/${service_name}.pid"))."
  echo "Log: $log_file"
}
