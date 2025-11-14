# in runner provisioning or pre-job hook
CACHE=/home/runner/pytorch-data/git-cache/pytorch.git
WORKDIR=/home/runner/_work/pytorch/pytorch

if [ ! -d "$WORKDIR" ]; then
  mkdir -p "$WORKDIR"
  git clone --shared --no-checkout "$CACHE" "$WORKDIR"
  # This creates .git and links to local objects immediately
  cd $WORKDIR
  git remote remove origin 2>/dev/null || true
  git remote add origin https://github.com/pytorch/pytorch
  git checkout main
  git submodule sync --recursive
  git -c protocol.version=2 submodule update --init --recursive --jobs 8
  : > ~/.gitconfig
fi
