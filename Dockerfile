FROM alpine:3.20.1

ARG TARGETARCH

ARG KUSTOMIZE_VERSION=5.4.3
ARG GH_CLI_VERSION=2.53.0

RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    openssl

RUN curl -sSL https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/gh_${GH_CLI_VERSION}_linux_${TARGETARCH}.tar.gz | tar -xz -C /usr/local --strip-components=1 gh_${GH_CLI_VERSION}_linux_${TARGETARCH}/bin/gh

RUN curl -sSL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz | tar -xz -C /usr/local/bin

COPY plugin.sh /drone/

ENTRYPOINT ["/drone/plugin.sh"]
