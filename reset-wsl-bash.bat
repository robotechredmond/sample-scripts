# from Admin cmd prompt, reinstall WSL by running:

lxrun /uninstall /full /y
lxrun /install

# launch WSL bash shell
bash

# sudo to root
sudo -H -s

# confirm Ubuntu release in WSL
lsb_release -a

# install dependencies 
apt-get update
apt-get install python3-pip python3-pyparsing python-dev python-pyparsing build-essential libffi-dev libssl-dev

# install Azure CLI 2.0
curl -L https://aka.ms/InstallAzureCli | bash

# install Azure SDKs for python3
pip3 install --upgrade pip
pip3 install --pre azure
pip3 uninstall azure-storage
pip3 install azure-storage

# exit sudo and relaunch shell
exit
exec -l $SHELL