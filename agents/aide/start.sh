#!/bin/bash
set -x # Print commands and their arguments as they are executed

cd ${AGENT_DIR}

eval "$(conda shell.bash hook)" # make conda available to the shell
conda activate agent

# determine hardware available
if command -v nvidia-smi &> /dev/null && nvidia-smi --query-gpu=name --format=csv,noheader &> /dev/null; then
  HARDWARE=$(nvidia-smi --query-gpu=name --format=csv,noheader \
    | sed 's/^[ \t]*//' \
    | sed 's/[ \t]*$//' \
    | sort \
    | uniq -c \
    | sed 's/^ *\([0-9]*\) *\(.*\)$/\1 \2/' \
    | paste -sd ', ' -)
else
  HARDWARE="a CPU"
fi
export HARDWARE
# check that we can use the GPU in PyTorch
python -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'WARNING: No GPU')"
# check that we can use the GPU in TensorFlow
python -c "import tensorflow as tf; print('GPUs Available: ', tf.config.list_physical_devices('GPU'))"

# convert $TIME_LIMIT_SECS to more readable format for prompt
format_time() {
  local time_in_sec=$1
  local hours=$((time_in_sec / 3600))
  local minutes=$(((time_in_sec % 3600) / 60))
  local seconds=$((time_in_sec % 60))
  echo "${hours}hrs ${minutes}mins ${seconds}secs"
}
export TIME_LIMIT=$(format_time $TIME_LIMIT_SECS)

# overwrite instructions.txt with instructions_obfuscated.txt if $OBFUSCATE is set
if [ "$OBFUSCATE" = "true" ]; then
  if [ ! -w /home/data/ ]; then
    echo "Obfuscation not implemented for read-only mounts"
    exit 1
  fi
  mv /home/instructions_obfuscated.txt /home/instructions.txt
fi

# start a new file to store the full instructions, starting with general instructions
cp /home/instructions.txt ${AGENT_DIR}/full_instructions.txt

# Update instructions for agent-specific details: replace `/home/` paths to make paths relative
# (since the agent will have its own copies of these files in its workspace).
# e.g. /home/submission/submission.csv -> submission/submission.csv
sed -i 's|/home/||g' ${AGENT_DIR}/full_instructions.txt
# we'll take care of moving things to home/submission/ ourselves

# move on to agent-specific instructions, with a linebreak in between
# substitute env variables into additional_notes.txt and append result to full_instructions.txt
echo "" >> ${AGENT_DIR}/full_instructions.txt
envsubst < ${AGENT_DIR}/additional_notes.txt >> ${AGENT_DIR}/full_instructions.txt
# finally, append the comp instructions, with a linebreak in between
printf "\nCOMPETITION INSTRUCTIONS\n------\n\n" >> ${AGENT_DIR}/full_instructions.txt

# overwrite description.md with description_obfuscated.md if $OBFUSCATE is set
if [ "$OBFUSCATE" = "true" ]; then
  if [ ! -w /home/data/ ]; then
    echo "Obfuscation not implemented for read-only mounts"
    exit 1
  fi
  mv /home/data/description_obfuscated.md /home/data/description.md
fi
cat /home/data/description.md >> ${AGENT_DIR}/full_instructions.txt

# symbolic linking
# agent will write to AGENT_DIR/workspaces/exp/ and AGENT_DIR/logs/exp
# we will mirror the contents of these to CODE_DIR, LOGS_DIR, and SUBMISSION_DIR

# these need to pre-exist for the symbolic links to work
mkdir -p ${AGENT_DIR}/workspaces
mkdir -p ${AGENT_DIR}/logs

# run with timeout, and print if timeout occurs
timeout $TIME_LIMIT_SECS aide data_dir="/home/data/" desc_file="${AGENT_DIR}/full_instructions.txt" \
  exp_name="exp" \
  $@ # forward the bash arguments to aide

EXIT_CODE=$?

# ==========================================
# 7. 收尾搬运工作 (Code)
# ==========================================

TASK_LOG_DIR=$(find ${AGENT_DIR}/logs -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -n "$TASK_LOG_DIR" ]; then
    echo "Found task log directory: $TASK_LOG_DIR"
    
    # 1.1 搬运所有日志文件 (report.md, journal.json, config.yaml 等) 到宿主机 logs 目录
    # 使用 cp -r 将内容平铺过去，这样你在外面打开 logs 就能直接看到 report.md，不用再进一层文件夹
    echo "Copying all log files to ${LOGS_DIR}..."
    cp -r "$TASK_LOG_DIR/"* "${LOGS_DIR}/"
    
    # 1.2 特别照顾：搬运代码文件
    if [ -f "$TASK_LOG_DIR/best_solution.py" ]; then
        echo "Found best_solution.py, copying to code directory..."
        cp "$TASK_LOG_DIR/best_solution.py" "${CODE_DIR}/best_solution.py"
    else
        echo "WARNING: best_solution.py not found in log dir."
    fi
else
    echo "WARNING: No log directory found in ${AGENT_DIR}/logs. AIDE might have failed to start."
fi

FOUND_SUB=$(find ${AGENT_DIR}/workspaces -name "submission.csv" | head -n 1)

if [ -f "$FOUND_SUB" ]; then
    echo "Found submission at $FOUND_SUB, copying to ${SUBMISSION_DIR}/submission.csv"
    cp "$FOUND_SUB" "${SUBMISSION_DIR}/submission.csv"
else
    echo "WARNING: Could not find submission.csv anywhere in workspaces."
fi

# 只有当提交文件存在时才评分
if [ -f "${SUBMISSION_DIR}/submission.csv" ]; then
    echo "=== Running Internal Grading Server ==="
    
    # 评分结果会输出到 stdout (也就是 run.log 中)
    # 同时也会生成 grade.json 到 logs 目录
    bash /home/validate_submission.sh "${SUBMISSION_DIR}/submission.csv"
    
    echo "=== Grading Completed ==="
else
    echo "WARNING: Skipping grading because submission.csv is missing."
fi


# 处理超时退出码
if [ $EXIT_CODE -eq 124 ]; then
  echo "Timed out after $TIME_LIMIT"
fi

exit $EXIT_CODE
