FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git python3 python3-json5 sudo \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tester \
 && echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester

CMD ["bash"]
