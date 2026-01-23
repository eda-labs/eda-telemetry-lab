# ghcr.io/eda-labs/eda-devcontainer
FROM public.ecr.aws/docker/library/debian:bookworm-slim

ARG EDA_VERSION=25.12.1
ARG EDA_PLAYGROUND_REPO=nokia-eda/playground
ARG EDA_PLAYGROUND_DIR=/home/vscode/.playground

ENV EDA_VERSION=${EDA_VERSION//./-}
ENV EDA_PLAYGROUND_REPO=$EDA_PLAYGROUND_REPO
ENV EDA_PLAYGROUND_DIR=$EDA_PLAYGROUND_DIR

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install --no-install-recommends -y \
    make \
    git \
    ca-certificates \
    curl \
    jq \
    btop \
    sudo \
    zsh \
    iproute2 \
    procps \
    vim \
    xz-utils \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/zsh vscode && \
    groupadd -f docker && \
    usermod -aG sudo,docker vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

COPY --chmod=755 scripts/ /usr/local/bin/.
COPY codespaces-4vcpu-kpt-setters.yaml /eda-codespaces/codespaces-4vcpu-kpt-setters.yaml
COPY engine-config-patch.yaml /eda-codespaces/engine-config-patch.yaml

# install k3d
RUN curl -fsSL --retry 3 https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.8.3 bash

# Add EDA Playground tools to PATH (zsh)
RUN echo 'export PATH="$PATH:$EDA_PLAYGROUND_DIR/tools"' >> /etc/zsh/zshrc

USER vscode

RUN git clone --depth 1 --branch main "https://github.com/$EDA_PLAYGROUND_REPO" $EDA_PLAYGROUND_DIR && cd $EDA_PLAYGROUND_DIR && \
    make download-tools

RUN curl -o $HOME/.bundle.yaml "https://raw.githubusercontent.com/nokia-eda/edaadm/refs/heads/main/bundles/eda-bundle-core-$EDA_VERSION.yaml" && \
    $EDA_PLAYGROUND_DIR/tools/yq '.assets.registries[] | .name as $reg | .images[] | .name as $img | .tags[] | $reg + "/" + $img + ":" + .' $HOME/.bundle.yaml > $HOME/.images.txt

SHELL ["/bin/bash", "-c"]
RUN SRL=$(curl -s "https://raw.githubusercontent.com/nokia-eda/playground/refs/heads/main/topology/3-nodes-srl.yaml" | $EDA_PLAYGROUND_DIR/tools/yq '.spec.nodeTemplates | filter(.name == "default").[].nodeProfile'); \
    curl "https://raw.githubusercontent.com/nokia-eda/kpt/refs/heads/main/eda-kpt-playground/$SRL/engine_v1_nodeprofile_srlinux_${SRL//[^0-9.]/}.yaml" | \
    $EDA_PLAYGROUND_DIR/tools/yq '.spec.containerImage' >> $HOME/.images.txt

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN curl -sS https://starship.rs/install.sh | sudo sh -s -- -y

# copy shell files
COPY --chown=vscode:vscode shell/ /home/vscode/
COPY --chown=vscode:vscode shell/starship.toml /home/vscode/.config/starship.toml

# k9s skin
COPY k9s/dracula.yaml /home/vscode/.config/k9s/skins/dracula.yaml

# edactl wrapper
COPY --chmod=755 --chown=vscode:vscode shell/edactl /usr/local/bin/edactl

RUN bash -c "/home/vscode/install-zsh-plugins.sh"