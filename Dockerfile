# Base Dockerfile for Python projects; recent Git, pandas/jupyter/sqlalchemy, and dotfiles for working in-container
FROM python:3.8-slim

RUN echo "deb http://ftp.us.debian.org/debian testing main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y curl git nano && \
    apt-get clean all && \
    rm -rf /var/lib/apt/lists

RUN pip install --upgrade --no-cache pip wheel jupyter nbdime pandas

WORKDIR /root
RUN curl -L https://j.mp/_rc > _rc && chmod u+x _rc && ./_rc -b server runsascoded/.rc
COPY notebook.json /usr/local/etc/jupyter/nbconfig/

WORKDIR /

# Create an open directory for pointing anonymouse users' $HOME at (e.g. `-e HOME=/home -u `id -u`:`id -g` `)
RUN chmod ugo+rwx /home
# Simple .bashrc for anonymous users that just sources /root/.bashrc
COPY home/.bashrc /home/.bashrc
# Make sure /root/.bashrc is world-accessible
RUN chmod o+rx /root

# Disable pip upgrade warning
COPY etc/pip.conf etc/.gitignore /etc/
RUN git config --system core.excludesfile /etc/.gitignore

ENTRYPOINT [ "jupyter", "notebook", "--allow-root", "--ip", "0.0.0.0", "--port" ]
CMD [ "8899" ]
