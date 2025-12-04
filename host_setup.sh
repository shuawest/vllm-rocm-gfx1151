
sudo dnf install -y podman git
sudo usermod -aG video,render $USER

sudo /opt/rocm/bin/rocminfo || echo "Using TheRock user-space later"
dmesg | grep -i amdgpu | tail -n 30
