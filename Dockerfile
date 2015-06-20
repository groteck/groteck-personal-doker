FROM ubuntu:14.04

# Update apt cache
RUN apt-get update
# Update apt-sources.list
## Mongo source
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
RUN echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/mongodb.list
## PG source
RUN apt-get install -y wget
RUN sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
RUN wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -

# Update apt cache
RUN apt-get update

# SSH user
ENV USERNAME groteck
ENV USERPASSWORD groteck
# Create and configure user
RUN useradd -ms /bin/bash $USERNAME
# User with empty password
RUN echo "$USERNAME:$USERPASSWORD" | chpasswd
# Enable passwordless sudo for user
RUN apt-get install -y sudo
RUN mkdir -p /etc/sudoers.d && echo "$USERNAME ALL= NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME && chmod 0440 /etc/sudoers.d/$USERNAME

# Install ssh server
RUN apt-get install -y openssh-server
RUN mkdir /var/run/sshd
EXPOSE 22

# Single user install
USER $USERNAME
WORKDIR /home/$USERNAME

## Personal config
## Create projects directory
RUN mkdir projects

## Install Zsh
RUN sudo apt-get install -y curl zsh
## Install Oh My Zsh
RUN curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh

## Install Vim
RUN sudo apt-get install -y vim-nox git
## Install my personal vim config
RUN curl -o ~/.vimrc https://gist.githubusercontent.com/groteck/9535996/raw/055d1e58270e67c60a1df7aaff8a4dee16d859d9/vimrc
# Install Vundle vim packages
RUN mkdir .vim .vim/bundle .vim/backup .vim/swap .vim/cache .vim/undo
RUN curl -o ~/.vim/bundles.vim https://gist.githubusercontent.com/groteck/9535996/raw/01215a07c0703df297910c47c19fe687aa0b6128/bundles.vim
RUN git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
RUN vim -u ~/.vim/bundles.vim +PluginInstall +qall

# Install tmux
RUN sudo apt-get install -y tmux
RUN curl -o ~/.tmux.config https://gist.githubusercontent.com/groteck/3341700/raw/559cd4746dc9de6a5d7c2d1efe59b01a9d78b5d4/.tmux.conf
RUN curl -o ~/.tmux.powerline https://gist.githubusercontent.com/groteck/3341700/raw/b8a07517ef7a15f68277af8ee65bea8d76e47a8d/.tmux.powerline
RUN mkdir -p ~/.solarized/tmux-colors-solarized
Run curl ~/.solarized/tmux-colors-solarized/tmuxcolors-256.conf https://gist.githubusercontent.com/groteck/3341700/raw/eb7ede440843455f06c2df0ec317a01f52350886/tmuxcolors-256.conf
RUN echo 'alias tmux="TERM=screen-256color-bce tmux"' >> ~/.zshrc

## Install RVM
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN \curl -sSL https://get.rvm.io | bash -s stable
RUN echo "source ~/.rvm/scripts/rvm" >> ~/.zshrc
## Install ruby
RUN /bin/bash -l -c "rvm install 2.2"
RUN echo "gem: --no-ri --no-rdoc" > ~/.gemrc

## Install NVM
RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.24.1/install.sh | bash
## Install node
RUN /bin/bash -l -c "source ~/.nvm/nvm.sh && nvm install 0.10"
RUN echo "source ~/.nvm/nvm.sh; nvm use 0.10" >> ~/.zshrc

# Install Mongo
Run sudo apt-get install -y mongodb-org-server
RUN sudo mkdir -p /data/db
RUN sudo sed 's/^bind_ip/#bind_ip/' -i /etc/mongod.conf
RUN sudo chown -R mongodb:mongodb /var/lib/mongodb

# Install PG
RUN sudo apt-get install postgresql-common postgresql-9.3 libpq-dev -y

# Create PG User
USER postgres

RUN /etc/init.d/postgresql start &&\
  psql --command "CREATE USER $USERNAME WITH SUPERUSER PASSWORD '$USERPASSWORD';"

# Start server services
USER root

# Ubuntu docker machine has not /etc/init.d, so I build my own init services file
RUN echo "sudo su postgres -c '/usr/lib/postgresql/9.3/bin/postgres -D /var/lib/postgresql/9.3/main -c config_file=/etc/postgresql/9.3/main/postgresql.conf &'" >> /boot_script.sh
Run echo "exec sudo -u mongodb -H /usr/bin/mongod --config /etc/mongod.conf --httpinterface --rest &"
RUN echo "/usr/sbin/sshd -D -e" >> /boot_script.sh
CMD sh /boot_script.sh
