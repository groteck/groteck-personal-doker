FROM ubuntu:14.04
MAINTAINER Juan Fraire <groteck@gmail.com>

#############################
## Install ubuntu packages ##
#############################

# Update apt-sources.list ##
# Mongo source
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
RUN echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/mongodb.list
# PG source
RUN apt-get install -y wget
RUN sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
RUN wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -

# Update apt cache
RUN apt-get update

# Install system packages
RUN apt-get install -y \
  binutils \
  bison \
  build-essential\
  curl \
  gcc \
  git \
  libpq-dev \
  libxml2-dev \
  libxslt-dev \
  make \
  mercurial \
  mongodb-org-server \
  openssh-server \
  postgresql-9.3 \
  postgresql-common \
  sudo \
  tmux \
  vim-nox \
  zsh \
;

######################
## Create sudo user ##
######################

# SSH user
ENV USERNAME groteck
ENV USERPASSWORD groteck
# Create and configure user
RUN useradd -ms /bin/bash $USERNAME
# User with empty password
RUN echo "$USERNAME:$USERPASSWORD" | chpasswd
# Enable passwordless sudo for user
RUN mkdir -p /etc/sudoers.d && \
             echo "$USERNAME ALL= NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME && \
             chmod 0440 /etc/sudoers.d/$USERNAME
# Use zsh like main shell
RUN sudo chsh -s $(which zsh) $USERNAME

##########
## SSH ##
##########

# config sshd
RUN mkdir /var/run/sshd
EXPOSE 22

##############################
## Sudo user configurations ##
##############################

USER $USERNAME
WORKDIR /home/$USERNAME

#########################
## Add ssh known hosts ##
#########################

# Create the needed directory and assign permissions
RUN mkdir /home/$USERNAME/.ssh
RUN chmod 700 /home/$USERNAME/.ssh
# Add github and bitbucket hosts
RUN ssh-keyscan -H github.com >> /home/$USERNAME/.ssh/known_hosts
RUN ssh-keyscan -H bitbucket.com >> /home/$USERNAME/.ssh/known_hosts

#############
## Locales ##
#############

ENV LOCALES es_ES.UTF-8
# generate locales
Run sudo locale-gen $LOCALES
Run sudo dpkg-reconfigure locales

##########
## Ruby ##
##########

## Install RVM
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN \curl -sSL https://get.rvm.io | bash -s stable
RUN echo "source ~/.rvm/scripts/rvm" >> ~/.zshrc
### Install ruby
RUN /bin/bash -l -c "rvm install 2.2"
RUN echo "gem: --no-ri --no-rdoc" > ~/.gemrc

#############
## Node.js ##
#############

## Install NVM
RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.24.1/install.sh | bash
## Install node
RUN /bin/bash -l -c "source ~/.nvm/nvm.sh && nvm install 0.10"
RUN echo "source ~/.nvm/nvm.sh; nvm use 0.10" >> ~/.zshrc

########
## Go ##
########

## Install GVM
RUN /bin/bash -l -c "zsh < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)"
## Install Go
RUN zsh -c "source ~/.gvm/scripts/gvm; gvm install go1.4.2"
RUN zsh -c "source ~/.gvm/scripts/gvm; gvm use go1.4.2 --default"

######################
## Personal config  ##
######################

ENV GITHUB_USER https://raw.githubusercontent.com/groteck

RUN wget -O - $GITHUB_USER/tmux-conf/master/install.sh | zsh
RUN wget -O - $GITHUB_USER/vim-config/master/install.sh | zsh
RUN wget -O - $GITHUB_USER/zsh-config/master/install.sh | zsh

#############
## MongoDB ##
#############

USER root

# Config Mongo
RUN mkdir -p /data/db
RUN sed 's/^bind_ip/#bind_ip/' -i /etc/mongod.conf
RUN chown -R mongodb:mongodb /var/lib/mongodb

##############
## Postgres ##
##############

# Add PG User
USER postgres

RUN /etc/init.d/postgresql start &&\
  psql --command "CREATE USER $USERNAME WITH SUPERUSER PASSWORD '$USERPASSWORD';"

#####################
## Docker services ##
#####################

USER root

# Ubuntu docker machine has not /etc/init.d, so I build my own init services file
RUN echo "sudo su postgres -c '/usr/lib/postgresql/9.3/bin/postgres -D /var/lib/postgresql/9.3/main -c config_file=/etc/postgresql/9.3/main/postgresql.conf &'" >> /boot_script.sh
Run echo "exec sudo -u mongodb -H /usr/bin/mongod --config /etc/mongod.conf --httpinterface --rest &" >> /boot_script.sh
RUN echo "/usr/sbin/sshd -D -e" >> /boot_script.sh
CMD sh /boot_script.sh
