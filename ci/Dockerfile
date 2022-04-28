ARG base_image=ubuntu:bionic
FROM ${base_image}

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libssl1.0-dev \
    libreadline-dev \
    lsb-release \
    locales \
    python \
    zip \
    zlib1g-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 \
 && /usr/sbin/update-locale LANG=en_US.UTF-8 \
 && dpkg-reconfigure -f noninteractive locales

RUN git clone https://github.com/rbenv/rbenv.git $HOME/.rbenv \
 && cd $HOME/.rbenv \
 && src/configure \
 && make -C src \
 && ln -s $HOME/.rbenv/bin/rbenv /usr/local/bin

RUN eval "$(rbenv init -)" \
 && git clone https://github.com/rbenv/ruby-build.git $(rbenv root)/plugins/ruby-build

RUN eval "$(rbenv init -)" \
 && git clone https://github.com/sstephenson/rbenv-default-gems.git $(rbenv root)/plugins/rbenv-default-gems \
 && echo 'bundler' >> $(rbenv root)/default-gems

RUN eval "$(rbenv init -)" \
 && rbenv install 2.5.9

RUN eval "$(rbenv init -)" \
 && rbenv install 2.7.6

RUN eval "$(rbenv init -)" \
 && rbenv install 3.0.4
