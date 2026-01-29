该requirement的openai版本！

```shell
docker build --platform=linux/amd64 -t mlebench-env -f environment/Dockerfile .                               
```

```shell
# 设置构建所需的临时环境变量（这些路径是镜像内部的，不需要改）
export SUBMISSION_DIR=/home/submission
export LOGS_DIR=/home/logs
export CODE_DIR=/home/code
export AGENT_DIR=/home/agent

# 构建 dummy 镜像
docker build --platform=linux/amd64 -t dummy agents/dummy/ \
  --build-arg SUBMISSION_DIR=$SUBMISSION_DIR \
  --build-arg LOGS_DIR=$LOGS_DIR \
  --build-arg CODE_DIR=$CODE_DIR \
  --build-arg AGENT_DIR=$AGENT_DIR
```

```shell
python run_agent.py --agent-id dummy --competition-set experiments/splits/spaceship-titanic.txt
```

```shell
export SUBMISSION_DIR=/home/submission
export LOGS_DIR=/home/logs
export CODE_DIR=/home/code
export AGENT_DIR=/home/agent

docker build --platform=linux/amd64 -t aide agents/aide/ \
  --build-arg SUBMISSION_DIR=$SUBMISSION_DIR \
  --build-arg LOGS_DIR=$LOGS_DIR \
  --build-arg CODE_DIR=$CODE_DIR \
  --build-arg AGENT_DIR=$AGENT_DIR
```

```shell
python run_agent.py --agent-id aide/deepseek --competition-set experiments/splits/spaceship-titanic.txt
```



```shell
python -m mlebench.grade \
  --competition spaceship-titanic \
  --submission runs/2026-01-27T02-58-58-GMT_run-group_aide/spaceship-titanic_ee8ed0f7-7feb-4169-b2f4-43bd9338fe39/submission/submission.csv \
  --output-dir runs/2026-01-27T02-58-58-GMT_run-group_aide/spaceship-titanic_ee8ed0f7-7feb-4169-b2f4-43bd9338fe39
```
