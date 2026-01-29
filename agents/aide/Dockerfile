FROM mlebench-env

# where to put submission.csv, will be extracted
ARG SUBMISSION_DIR
ENV SUBMISSION_DIR=${SUBMISSION_DIR}
# where to put any logs, will be extracted
ARG LOGS_DIR
ENV LOGS_DIR=${LOGS_DIR}
# where to put any code, will be extracted
ARG CODE_DIR
ENV CODE_DIR=${CODE_DIR}
# where to put any other agent-specific files, will not be necessarily extracted
ARG AGENT_DIR
ENV AGENT_DIR=${AGENT_DIR}

RUN mkdir ${LOGS_DIR} ${CODE_DIR} ${AGENT_DIR}

ARG CONDA_ENV_NAME=agent
ARG REQUIREMENTS=${AGENT_DIR}/requirements.txt

# copy just the requirements file, so that we can cache conda separately from the agent files
COPY requirements.txt ${AGENT_DIR}/requirements.txt

# === 【新增这一行】 ===
# 必须先把它拷进去，pip 才能安装它！
COPY aideml_fixed ${AGENT_DIR}/aideml_fixed
# ===================

# Requirements for opencv
RUN apt-get update && apt-get install ffmpeg libsm6 libxext6  -y

# create conda environment and install the requirements to it
#RUN conda run -n ${CONDA_ENV_NAME} pip install -r ${AGENT_DIR}/requirements.txt && \
#    conda clean -afy
# 1. 设置工作目录，确保操作都在正确的路径下
WORKDIR ${AGENT_DIR}

# 2. 安装依赖：
#    先运行 requirements.txt (虽然现在是空的，但保留逻辑以防万一)
#    然后显式安装 aideml_fixed (使用 -e 模式和绝对路径)
RUN conda run -n ${CONDA_ENV_NAME} pip install -r ${AGENT_DIR}/requirements.txt || true && \
    conda run -n ${CONDA_ENV_NAME} pip uninstall -y openai && \
    conda run -n ${CONDA_ENV_NAME} pip install "openai==1.66.3" && \
    echo "=== CHECKING OPENAI VERSION ===" && \
    conda run -n ${CONDA_ENV_NAME} pip show openai && \
    echo "=============================" && \
    conda run -n ${CONDA_ENV_NAME} pip install -e ${AGENT_DIR}/aideml_fixed && \
    conda clean -afy

# put all the agent files in the expected location
COPY . ${AGENT_DIR}
