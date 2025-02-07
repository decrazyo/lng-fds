#
# docker build -t cc65 .
#
# Local use
# docker run --rm -it -w /app -v $(pwd):/app cc65 bash
# docker run --rm -it -w /app -v $(pwd):/app cc65 make all
# docker run --rm -it -w /app -v $(pwd):/app cc65 make clean
#

FROM debian:latest

RUN mkdir /app
WORKDIR /app

RUN apt-get update && apt-get install -y curl build-essential

# Add cc65 repository
RUN echo 'deb http://download.opensuse.org/repositories/home:/strik/Raspbian_9.0/ /' | tee /etc/apt/sources.list.d/home:strik.list \
    && curl -fsSL https://download.opensuse.org/repositories/home:strik/Raspbian_9.0/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/home_strik.gpg > /dev/null \
    && apt-get update \
    && apt-get install -y cc65

RUN rm -rf /var/lib/apt/lists/* \
    && apt-get clean

COPY . .

RUN make all
