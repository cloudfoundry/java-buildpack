ARG base_image=ubuntu:jammy
FROM ${base_image}

RUN apt-get update && apt-get install -y wget gnupg

RUN wget -q -O - https://download.bell-sw.com/pki/GPG-KEY-bellsoft | apt-key add -
RUN echo "deb [arch=amd64] https://apt.bell-sw.com/ stable main" | tee /etc/apt/sources.list.d/bellsoft.list

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libffi-dev \
    libssl-dev \
    libreadline-dev \
    libyaml-dev \
    lsb-release \
    locales \
    python3 \
    zip \
    zlib1g-dev \
    bellsoft-java17 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 \
 && /usr/sbin/update-locale LANG=en_US.UTF-8 \
 && dpkg-reconfigure -f noninteractive locales

RUN git clone https://github.com/rbenv/rbenv.git $HOME/.rbenv && ln -s $HOME/.rbenv/libexec/rbenv /usr/local/bin

RUN eval "$(rbenv init -)" \
 && git clone https://github.com/rbenv/ruby-build.git $(rbenv root)/plugins/ruby-build

RUN eval "$(rbenv init -)" \
 && git clone https://github.com/sstephenson/rbenv-default-gems.git $(rbenv root)/plugins/rbenv-default-gems \
 && echo 'bundler 2.3.12' >> $(rbenv root)/default-gems

RUN eval "$(rbenv init -)" \
 && rbenv install 3.4.7 \
 && rbenv global 3.4.7
