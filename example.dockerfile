# Example: install py-helpers on Ubuntu
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt-get install -y git wget
WORKDIR /root

# In interactive shells, `. <(curl -L https://j.mp/_rc) ryan-williams/py-helpers` is my preferred one-liner, but below
# is an equivalent formulation that works in a Docker build.
RUN wget -qO- https://j.mp/_rc | bash -s ryan-williams/py-helpers
SHELL ["bash", "-ic"]

# As an example, invoke some Bash functions defined/exported in .py-rc
RUN install_pyenv  # Install pyenv and required Python dependencies
RUN pyenv install 3.11.8 && pyenv global 3.11.8  # Install Python 3.11.8, set as default
RUN pci sys stderr  # Verify that `python -c 'from sys import stderr'` works
RUN py 2+2  # 4; short for `python -c 'print(2+2)'`
