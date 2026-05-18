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

  rm -f "$pid_file"
  echo "$service_name stopped."
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
