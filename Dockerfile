# Use the official Ubuntu 22.04 LTS base image
FROM ubuntu:22.04

# Set non-interactive mode for APT and define default variables
ARG DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR /usr/local/nvm
ENV PYTHON_VERSION=2.7.5
ENV C9SDK_PASSWORD=password

# Update and install essential packages
RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  git \
  libssl-dev \
  wget \
  vim \
  nano \
  locales-all \
  sudo \
  cron \
  zip \
  ruby-full \
  gnupg \
  imagemagick \
  ffmpeg \
  nodejs \
  npm \
  mc && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Ruby gems
RUN gem install bundler

# Install Google Chrome dependencies
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
  sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' && \
  apt-get update && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 --no-install-recommends && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /root

# Clone Cloud9 SDK repository
RUN git clone https://github.com/c9/core.git c9sdk

# Install Cloud9 SDK
WORKDIR /root/c9sdk
RUN scripts/install-sdk.sh

# Build Python from source
WORKDIR /tmp
RUN wget https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz && \
  tar -xf Python-$PYTHON_VERSION.tgz && \
  cd Python-$PYTHON_VERSION && \
  ./configure --enable-optimizations --prefix=/usr/local && \
  make && make install && \
  cd .. && rm -rf Python-$PYTHON_VERSION*

# Install NVM and Node.js
RUN mkdir -p "$NVM_DIR" && \
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh" | bash && \
  . $NVM_DIR/nvm.sh && \
  nvm install 12 && \
  nvm alias default 12 && \
  nvm use default && \
  npm install -g pm2 yarn

# Install additional dependencies
RUN apt-get update && apt-get install -y supervisor gettext-base

# Copy custom configurations
COPY ./nginx/project.conf /etc/nginx/sites-enabled/
COPY supervisord.conf.template /etc/supervisor/conf.d/supervisord.conf
COPY .bashrc /tmp/.bashrc
RUN cat /tmp/.bashrc >> /root/.bashrc
COPY .profile /tmp/.profile
RUN cat /tmp/.profile >> /root/.profile

# Copy initial command and PM2 server managers
COPY initial_command.sh /root/initial_command.sh
COPY pm2-server-managers /root/pm2-server-managers
RUN chmod +x /root/initial_command.sh /root/pm2-server-managers/detect-git-repo-deployment.sh

# Export environment variables at build time
RUN printenv | awk -F= '{print "export " $1"="$2}' > /env.sh
RUN chmod +x /env.sh

# Define default command
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Expose necessary ports
EXPOSE 8080 3399
