# Dockerfile may have two Arguments: tag, branch
# tag - tag for the Base image, (e.g. 1.14.0-py3 for tensorflow)
# branch - user repository branch to clone (default: main, other option: test)

ARG tag=1.14.0-py3

# Base image, e.g. tensorflow/tensorflow:1.14.0-py3
FROM tensorflow/tensorflow:${tag}

LABEL maintainer='Ignacio Heredia (CSIC)'
LABEL version='0.1'
# An audio classifier with Deep Neural Networks

# What user branch to clone (!)
ARG branch=main
ARG tag

# 2024: need to re-add GPG keys for Nvidia repos but only in the case of GPU images
# Note for GPU build: see https://askubuntu.com/questions/1444943/nvidia-gpg-error-the-following-signatures-couldnt-be-verified-because-the-publi
RUN if [[ "$tag" =~ "-gpu" ]]; then \
    apt-key del 7fa2af80 ; \
    curl https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub | apt-key add - ; \
    curl https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - ; fi

# Install ubuntu updates and python related stuff
# link python3 to python, pip3 to pip, if needed
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
         git \
         curl \
         wget \
         psmisc \
         unzip \
         python3-setuptools \
         python3-pip \
         python3-wheel && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    python --version && \
    pip --version

# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone
RUN curl https://rclone.org/install.sh | bash

# Initialization scripts
# deep-start can install JupyterLab or VSCode if requested
RUN git clone https://github.com/ai4os/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER yes

ENV SHELL /bin/bash

# Install audio packages (libmagic1 seems missing in GPU tensorflow image)
RUN apt-get update && \
    apt-get install -y ffmpeg libavcodec-extra libmagic1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*


# Install user app
RUN git clone -b $branch https://github.com/ai4os-hub/ai4os-audio-classification-tf && \
    cd  ai4os-audio-classification-tf && \
    pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..

# Download network weights: compressing with tar.xz gives decompression errors (corrupt data)
ENV SWIFT_CONTAINER https://api.cloud.ifca.es:8080/swift/v1/audio-classification-tf/
ENV MODEL_TAR default.tar.gz

RUN curl --insecure -o ./ai4os-audio-classification-tf/models/${MODEL_TAR} \
    ${SWIFT_CONTAINER}${MODEL_TAR}

RUN cd ai4os-audio-classification-tf/models && \
    tar -zxvf ${MODEL_TAR}  && \
    rm ${MODEL_TAR}

# Open ports (deepaas, monitoring, ide)
EXPOSE 5000 6006 8888

# Launch deepaas
CMD ["deepaas-run", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]
