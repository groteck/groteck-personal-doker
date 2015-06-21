FROM ubuntu:14.04

#############################
## Install ubuntu packages ##
#############################

## Update apt-sources.list ##
## Mongo source
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
RUN echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/mongodb.list
## PG source
RUN apt-get install -y wget
RUN sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
RUN wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -

# Update apt cache
RUN apt-get update

# Install system packages
RUN apt-get install -y curl zsh git sudo openssh-server vim-nox tmux  \
                       mongodb-org-server postgresql-common postgresql-9.3 \
                       libpq-dev

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

##########
## SSH ##
##########

# config dssh
RUN mkdir /var/run/sshd
EXPOSE 22

##################
## Machine name ##
##################

# Change machine name
RUN echo '$USERNAME-docker' > /etc/hostname

##############################
## Sudo user configurations ##
##############################

USER $USERNAME
WORKDIR /home/$USERNAME

######################
## Personal config  ##
######################

## Create projects directory
RUN mkdir projects

## Install Oh My Zsh
RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true
RUN sudo chsh -s $(which zsh) $USERNAME
## Custom zsh config
RUN rm ~/.zshrc
RUN curl -o ~/.zshrc https://gist.githubusercontent.com/groteck/24151cc9f33a6fa33d36/raw/210ba5975bbf75af7f28d266fc73ba0c3eb4ea18/.zshrc

## Add ssh config for github
RUN mkdir ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts

## Install my personal vim config
RUN mkdir .vim .vim/bundle .vim/backup .vim/swap .vim/cache .vim/undo
RUN curl -o ~/.vimrc https://gist.githubusercontent.com/groteck/9535996/raw/055d1e58270e67c60a1df7aaff8a4dee16d859d9/vimrc
### Install vim plugins
RUN curl -o ~/.vim/bundles.vim https://gist.githubusercontent.com/groteck/9535996/raw/66abc3ea76b26e1dde000a38e4152911781d9936/bundles.vim
RUN git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
RUN vim -u ~/.vim/bundles.vim +PluginInstall +qall

# Install tmux
RUN curl -o ~/.tmux.conf https://gist.githubusercontent.com/groteck/3341700/raw/559cd4746dc9de6a5d7c2d1efe59b01a9d78b5d4/.tmux.conf
RUN curl -o ~/.tmux.powerline https://gist.githubusercontent.com/groteck/3341700/raw/b8a07517ef7a15f68277af8ee65bea8d76e47a8d/.tmux.powerline
RUN mkdir -p ~/.solarized/tmux-colors-solarized
Run curl ~/.solarized/tmux-colors-solarized/tmuxcolors-256.conf https://gist.githubusercontent.com/groteck/3341700/raw/eb7ede440843455f06c2df0ec317a01f52350886/tmuxcolors-256.conf
RUN echo 'alias tmux="TERM=screen-256color-bce tmux"' >> ~/.zshrc

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

#############
## MongoDB ##
#############

# Config Mongo
RUN sudo mkdir -p /data/db
RUN sudo sed 's/^bind_ip/#bind_ip/' -i /etc/mongod.conf
RUN sudo chown -R mongodb:mongodb /var/lib/mongodb

##############
## Postgres ##
##############

# Congig PG User
USER postgres

RUN /etc/init.d/postgresql start &&\
  psql --command "CREATE USER $USERNAME WITH SUPERUSER PASSWORD '$USERPASSWORD';"

#####################
## Docker services ##
#####################

USER root

# Ubuntu docker machine has not /etc/init.d, so I build my own init services file
RUN echo "sudo su postgres -c '/usr/lib/postgresql/9.3/bin/postgres -D /var/lib/postgresql/9.3/main -c config_file=/etc/postgresql/9.3/main/postgresql.conf &'" >> /boot_script.sh
Run echo "exec sudo -u mongodb -H /usr/bin/mongod --config /etc/mongod.conf --httpinterface --rest &"
RUN echo "/usr/sbin/sshd -D -e" >> /boot_script.sh
CMD sh /boot_script.sh
