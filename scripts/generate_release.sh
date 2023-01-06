#!/usr/bin/env bash
docker run --name=teiserver -it --name=teiserver teiserver:latest
docker cp teiserver:/opt/build/rel/artifacts/teiserver.tar.gz rel/artifacts/teiserver.tar.gz
docker rm -f teiserver
