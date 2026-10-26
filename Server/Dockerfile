# Build context: repository root (the server depends on Packages/SettleCore).
#   docker build -f Server/Dockerfile -t settle-api .
FROM docker.io/library/swift:6.4.1-noble AS build
WORKDIR /build
COPY Packages/SettleCore Packages/SettleCore
COPY Server/Package.swift Server/Package.resolved Server/
RUN cd Server && swift package resolve
COPY Server Server
RUN cd Server \
    && swift build -c release --static-swift-stdlib --product SettleServer \
    && cp "$(swift build -c release --show-bin-path)/SettleServer" /build/settle-server

FROM docker.io/library/ubuntu:noble
RUN useradd --system --uid 10001 --no-create-home settle
COPY --from=build /build/settle-server /usr/local/bin/settle-server
USER 10001
ENV HOST=0.0.0.0 PORT=8080
EXPOSE 8080
ENTRYPOINT ["settle-server"]
