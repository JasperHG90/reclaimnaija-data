#!/usr/bin/env bash

### Provisioning the virtual machine

sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10

# Update
sudo apt-get update

# Install base packages
echo "Installing base packages..."
sudo apt-get install zlib1g-dev
sudo apt-get install git <<-EOF
yes
EOF
sudo apt-get install g++ <<-EOF
yes
EOF
sudo apt-get install default-jre <<-EOF
yes
EOF
sudo apt-get install zip
sudo apt-get install unzip
sudo apt-get install libxml2-dev <<-EOF
yes
EOF
sudo apt-get install libxslt1-dev <<-EOF
yes
EOF
echo 'Installing python and pip...'
sudo apt-get install python-dev <<-EOF
yes
EOF
sudo apt-get install python-pip <<-EOF
yes
EOF
echo "Installing htop..."
sudo apt-get install htop <<-EOF
yes
EOF
echo "Installing libjpeg-dev..."
sudo apt-get install libjpeg-dev <<-EOF
yes
EOF

echo "Configuring libjpeg..."
sudo ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib/
sudo ln -s /usr/lib/x86_64-linux-gnu/libfreetype.so.6 /usr/lib/
sudo ln -s /usr/lib/x86_64-linux-gnu/libz.so /usr/lib/

echo "Creating Folders..."
mkdir Documents
cd Documents && mkdir Python_Scripts && R_Scripts
cd -
mkdir Downloads
mkdir temp

echo "Installing Python dependencies..."
sudo pip install -r /vagrant/Python_requirements.txt

# Update
sudo apt-get update <<-EOF
yes
EOF

echo "Installing R-base..."
# Add cran to list of sources (to get the last version of R)
sudo echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list
# Add public keys
gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
gpg -a --export E084DAB9 | sudo apt-key add -
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install r-base <<-EOF
yes
EOF

echo "Installing R-studio server..."
sudo apt-get install libjpeg62 <<-EOF
yes
EOF
cd temp
sudo apt-get install gdebi-core <<-EOF
yes
EOF
sudo apt-get install libapparmor1 <<-EOF
yes
EOF
wget http://download2.rstudio.org/rstudio-server-0.98.1091-amd64.deb
sudo gdebi rstudio-server-0.98.1091-amd64.deb <<-EOF
yes
EOF

echo "Installing R packages..."
sudo R CMD BATCH /vagrant/InstallRpackages.R

echo "Installing rJava..."
apt-get install r-cran-rjava

echo "Installing Ipython Notebook..."
sudo apt-get install ipython-notebook <<-EOF
yes
EOF

echo "Setting up crontab..."
sudo crontab /vagrant/crontab.txt

echo "Updating..."
sudo apt-get update
