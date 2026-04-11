FROM archlinux:base-devel
# sudo
RUN pacman -Sy --noconfirm sudo

# dev utils - generic
RUN pacman -Sy --noconfirm vim htop tmux
# dev utils - networking
RUN pacman -Sy --noconfirm curl wget ca-certificates ca-certificates-mozilla ca-certificates-utils tcpdump bind iputils net-tools
# dev utils - versioning
RUN pacman -Sy --noconfirm git
# dev utils - archives
RUN pacman -Sy --noconfirm unzip gzip

# opencode deps
RUN pacman -Sy --noconfirm nodejs npm bun

COPY root/. /

VOLUME [ "/home/coder" ]

RUN useradd -d /home/coder -M -s /usr/bin/bash coder
RUN echo 'coder ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers

USER coder

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

