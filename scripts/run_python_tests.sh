#!/usr/bin/env bash

apt-get update

# TODO: Remove this
apt-get -y install vim


apt-get -y install curl
apt-get -y install unzip

# Install postgres
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | apt-key add -
apt-get -y install postgresql postgresql-contrib

# Configure our instance of postgres
sed -i s/md5/trust/ /etc/postgresql/9.5/main/pg_hba.conf
/etc/init.d/postgresql restart

# Pass in the config file
cp pipeline-ci/config_local.py pivotal-source/web/config_local.py
cp pipeline-ci/test_config.json pivotal-source/web/regression/test_config.json

# Replace the first line of the file with the missing import
sed -i '/__future__/a from selenium.webdriver.common.desired_capabilities import DesiredCapabilities' pivotal-source/web/regression/runtests.py
sed -i "s/Chrome()/Remote\(command_executor='http:\/\/127.0.0.1:4444\/wd\/hub', desired_capabilities=DesiredCapabilities.CHROME\)/)/" ./pivotal-source/web/regression/runtests.py


/opt/bin/start_selenium.sh &

source ~/.bash_profile

pyenv activate pgadmin

# Install project requirements
pip install -r pivotal-source/requirements.txt
pip install -r pivotal-source/web/regression/requirements.txt

function runTests {
    # Run all python tests. Includes feature tests.
    python ./pivotal-source/web/regression/runtests.py
    status=$?

    branch_name=`cd pivotal-source && git branch | grep \* | cut -d ' ' -f2`

    sed -i "s/changemetobranchname/plumadmin-master/" ./pipeline-ci/manifest.yml

    mkdir -p output
    cp -r ./pivotal-source/web output
    cp ./pipeline-ci/config_local_cf.py output/web/config_local.py
    cp ./pipeline-ci/.cfignore output/web/
    cp ./pipeline-ci/manifest.yml output/
    cp ./pivotal-source/requirements.txt output/web/

    mkdir -p output/web/.pgadmin/
    cp ./pipeline-ci/database/pgadmin4-desktop.db output/web/.pgadmin/

    return $status
}

runTests