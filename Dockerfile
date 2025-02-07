#
# docker run --rm -it -v $(pwd):/app debian bash
#
#

FROM debian:latest

RUN mkdir /app
WORKDIR /app

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    vim \
    nano \
    git \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY . .

RUN make
