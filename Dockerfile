# Base Dockerfile for Python projects; recent Git, pandas/jupyter/sqlalchemy, and dotfiles for working in-container
FROM python:3.8-slim

RUN echo "deb http://ftp.us.debian.org/debian testing main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y curl git && \
    apt-get clean all && \
    rm -rf /var/lib/apt/lists

RUN pip install --upgrade --no-cache pip wheel jupyter pandas sqlalchemy

WORKDIR /root
RUN curl -L https://j.mp/_rc > _rc && chmod u+x _rc && ./_rc runsascoded/.rc

WORKDIR /

ENTRYPOINT [ "jupyter", "notebook", "--allow-root", "--ip", "0.0.0.0", "--port" ]
CMD [ "8899" ]
