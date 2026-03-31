#!/bin/bash
# 该脚本已升级为通用安装脚本 setup_env.sh
# 为了保持兼容性，此脚本将调用新的 setup_env.sh

if [ -f "./setup_env.sh" ]; then
    bash ./setup_env.sh "$@"
else
    echo "未找到 setup_env.sh，请确保脚本在同一目录下"
    exit 1
fi
