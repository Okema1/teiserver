#!/usr/bin/env bash
touch lib/central_web/views/admin/general_view.ex

if [ ! -f config/prod.secret.exs ]
then
	cp documents/prod_files/example_prod_secret.exs config/prod.secret.exs
fi

chmod +x scripts/build.sh
mkdir -p rel/artifacts

sh scripts/build_container.sh
sh scripts/generate_release.sh

scp -i ~/.ssh/id_rsa rel/artifacts/teiserver.tar.gz deploy@yourdomain.com:/releases/teiserver.tar.gz

mix phx.digest.clean --all

echo "ssh into your server and run dodeploy"