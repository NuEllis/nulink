# Build NuLink with SGX
FROM smartcontract/builder:1.0.25 as builder

# Have to reintroduce ENV vars from builder image
ENV PATH /root/.cargo/bin:/go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/sgxsdk/bin:/opt/sgxsdk/bin/x64
ENV LD_LIBRARY_PATH /opt/sgxsdk/sdk_libs
ENV SGX_SDK /opt/sgxsdk

WORKDIR /nulink
COPY GNUmakefile VERSION ./
COPY tools/bin/ldflags ./tools/bin/

# Install yarn dependencies
COPY yarn.lock package.json ./
COPY operator_ui/package.json ./operator_ui/
COPY styleguide/package.json ./styleguide/
COPY tools/json-api-client/package.json ./tools/json-api-client/
COPY tools/local-storage/package.json ./tools/local-storage/
COPY tools/redux/package.json ./tools/redux/
COPY tools/ts-test-helpers/package.json ./tools/ts-test-helpers/
COPY belt/package.json ./belt/
COPY belt/bin ./belt/bin
COPY evm-test-helpers/package.json ./evm-test-helpers/
COPY evm-contracts/package.json ./evm-contracts/
RUN make yarndep

# Do go mod download in a cacheable step
ADD go.mod go.sum ./
RUN go mod download

# Env vars needed for nulink sgx build
ARG COMMIT_SHA
ARG ENVIRONMENT
ENV SGX_ENABLED yes
ARG SGX_SIMULATION

# Install nulink
COPY tsconfig.cjs.json tsconfig.es6.json ./
COPY operator_ui ./operator_ui
COPY styleguide ./styleguide
COPY tools/json-api-client ./tools/json-api-client
COPY tools/local-storage ./tools/local-storage
COPY tools/redux ./tools/redux
COPY tools/ts-test-helpers ./tools/ts-test-helpers
COPY belt ./belt
COPY belt/bin ./belt/bin
COPY evm-test-helpers ./evm-test-helpers
COPY evm-contracts ./evm-contracts
COPY core core
COPY packr packr

RUN make install-nulink

# Final layer: ubuntu with aesm and nulink binaries (executable + enclave)
FROM ubuntu:18.04

# Install AESM
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
  apt-get install -y \
    ca-certificates \
    curl \
    kmod \
    libcurl4-openssl-dev \
    libprotobuf-c0-dev \
    libprotobuf-dev \
    libssl-dev \
    libssl1.0.0 \
    libxml2-dev

RUN /usr/sbin/useradd aesmd 2>/dev/null

RUN mkdir -p /var/opt/aesmd && chown aesmd.aesmd /var/opt/aesmd
RUN mkdir -p /var/run/aesmd && chown aesmd.aesmd /var/run/aesmd

COPY --from=builder /opt/sgxsdk/lib64/libsgx*.so /usr/lib/
COPY --from=builder /opt/intel/ /opt/intel/

# Copy nulink enclave+stub from build image
ARG ENVIRONMENT
COPY --from=builder /go/bin/nulink /usr/local/bin/
COPY --from=builder \
  /nulink/core/sgx/target/$ENVIRONMENT/libadapters.so \
  /usr/lib/
COPY --from=builder \
  /nulink/core/sgx/target/$ENVIRONMENT/enclave.signed.so \
  /root/

# Launch nulink via a small script that watches AESM + NuLink
ARG SGX_SIMULATION
ENV SGX_SIMULATION $SGX_SIMULATION
WORKDIR /root
COPY core/nulink-launcher-sgx.sh .
RUN chmod +x ./nulink-launcher-sgx.sh

EXPOSE 6688
ENTRYPOINT ["./nulink-launcher-sgx.sh"]
CMD ["local", "node"]
