FROM nixos/nix:latest
RUN nix-channel --update
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
WORKDIR /config
COPY . /config
