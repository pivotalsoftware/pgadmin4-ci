#!/usr/bin/env bash
set -e

########
# Ensure that you are logged in to Pivotal Cloud Foundry before running the script
# cf login -a api.run.pivotal.io -u <username> -o 'Data R&D' -s plumadmin
#
########

# Get the current branch of pgadmin4
pushd ~/workspace/pgadmin4
  branch_name=`git branch|grep '\*' |awk '{print $2}'`
popd

# Exit script if branchname can't be found
if [[ "$branch_name" =~ \ |\' ]]    #  slightly more readable: if [[ "$string" =~ ( |\') ]]
then
    echo "Not deploying because couldn't find the branch name in the git message: '$branch_name'"
    exit 0
fi

# Copy files needed for pcf to run pgAdmin4
mv ~/workspace/pgadmin4/web/config_local.py ~/workspace/pgadmin4/web/config_local.py~
cp config_local_cf.py ~/workspace/pgadmin4/web/config_local.py
cp .cfignore ~/workspace/pgadmin4/web/
cp manifest.yml ~/workspace/pgadmin4/
cp ~/workspace/pgadmin4/requirements.txt ~/workspace/pgadmin4/web/
mkdir ~/workspace/pgadmin4/web/.pgadmin
cp database/pgadmin4-desktop.db ~/workspace/pgadmin4/web/.pgadmin/

error=false

pushd ~/workspace/pgadmin4
  # Webpack all the things
  pushd web
    yarn install || error=true
    yarn run bundle || error=true
  popd

  # Upload app to cloud foundry
  if [ $error == false ] ; then
      cf push plumadmin-$branch_name -f manifest.yml || error=true
  fi
popd

# Clean up after uploading
rm ~/workspace/pgadmin4/web/config_local.py
mv ~/workspace/pgadmin4/web/config_local.py~ ~/workspace/pgadmin4/web/config_local.py
rm ~/workspace/pgadmin4/web/.cfignore
rm ~/workspace/pgadmin4/manifest.yml
rm ~/workspace/pgadmin4/web/requirements.txt
rm -Rf ~/workspace/pgadmin4/web/.pgadmin

if [ $error == true ] ; then
    exit -1
fi

exit 0
