# Home Server Setup Guide

Installing and configuring the Home Server machine.

## 1. Operating System

This guide is designed for **Debian 13 (Trixie)**, though the Home Server project is compatible with any Linux distribution that supports Docker and Docker Compose. You can find the official installation instructions for Debian [here](https://www.debian.org/releases/stable/debian-installer/index.html).

---

## 2. Post-Installation Linux Operating System Setup

### 2.1. Configure `sudo`

If `sudo` isn't working for your user, you'll need to install it and grant your user permissions.

#### 2.1.1.  **Switch to the root user and install `sudo`**:
```bash
su - # Use 'su -' to get the full root environment
apt update && apt install sudo -y
```

#### 2.1.2 **Add your user to the `sudo` group**:
```bash
usermod -aG sudo <your_user_name>
```
    After this, **log out and log back in** for the changes to take effect.

#### 2.1.3 **Verify `sudo` is working**:
```bash
sudo ls # Enter your user's password, not the root password
```

### 2.2. Install Docker & Docker Compose

For the most up-to-date instructions, refer to the official [Docker documentation](https://docs.docker.com/engine/install/debian/).

Here's a summary of the installation steps:

#### 2.2.1 **Add Docker's official GPG key and repository**:

```bash
# Add GPG key
sudo apt update
sudo apt install ca-certificates curl gnupg lsb-release -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL [https://download.docker.com/linux/debian/gpg](https://download.docker.com/linux/debian/gpg) | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository
echo \
   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] [https://download.docker.com/linux/debian](https://download.docker.com/linux/debian) \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
```

#### 2.2.2 **Install Docker packages**:
```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

#### 2.2.3 **Verify the Docker service**:
```bash
sudo systemctl status docker
```
The Docker service should start automatically after installation. If it's not running, you can start it manually:

```bash
sudo systemctl start docker
```

### 2.3. Install another Home Server project dependencies

#### 2.3.1. rsync

```bash
sudo apt-get install rsync
```

### 2.4. Useful Shell Tools

Enhance your terminal experience by installing these helpful tools.

#### 2.4.1 **`Oh My Bash`**:
```bash
sudo apt install curl -y
bash -c "$(curl -fsSL [https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh](https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh))"
```

#### 2.4.2 **`fzf`**: A command-line fuzzy finder.
```bash
sudo apt install fzf -y
```

#### 2.4.3  **`bash-completion`**: Tab completion for common commands.
```bash
sudo apt install bash-completion -y
```

#### 2.4.4 **`bat`**: A `cat` clone with syntax highlighting and Git integration.
```bash
sudo apt install bat -y
```

#### 2.4.5  **`lsd`**: An `ls` command with more colors and an icon view.
```bash
sudo apt install lsd -y
```
