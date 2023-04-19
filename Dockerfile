FROM alpine:latest
ARG USER=backup
RUN apk update \
    && apk add socat \
        gzip \
        bash \
        gnupg \
        postgresql-client \
        coreutils \
        sudo \
        py-pip \
        ca-certificates \
        --update --no-cache

RUN pip install s3cmd

RUN adduser -D $USER \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER

RUN mkdir /app

RUN chown -R $USER:$USER /app

USER $USER
WORKDIR /app

COPY entrypoint.sh /app
COPY retention-policy.sh /app
RUN sudo chmod +x entrypoint.sh
RUN sudo chmod +x retention-policy.sh
ENTRYPOINT ["./entrypoint.sh"]
