FROM elixir:1.13.2
ARG env=dev
ENV LANG=en_US.UTF-8 \
  TERM=xterm \
  MIX_ENV=$env
WORKDIR /opt/build
ADD ./scripts/build.sh ./bin/build.sh
CMD ["bin/build.sh"]
