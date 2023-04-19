FROM alpine:latest
RUN apk update \
    #&& apk add post --no-cache  \
    && apk add socat --no-cache  \
    && apk add gzip --no-cache  \
    && apk add bash --no-cache  \
    && apk add gnupg --no-cache  \
    && apk add --no-cache postgresql-client \
    && apk add --update coreutils
RUN apk add --no-cache py-pip ca-certificates && pip install s3cmd
COPY entrypoint.sh /
COPY retention-policy.sh /
RUN chmod +x entrypoint.sh
RUN chmod +x retention-policy.sh
ENTRYPOINT ["./entrypoint.sh"]
