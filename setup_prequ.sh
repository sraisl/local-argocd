#!/usr/bin/env bash

# Function to check installation
check_install() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 is not installed."
        read -p "Would you like to install $1? (y/n) " choice
        case "$choice" in
            y|Y ) install_tool $1 ;;
            * ) echo "$1 will not be installed." ;;
        esac
    else
        echo "$1 is already installed."
    fi
}

# Function to install Homebrew
install_homebrew() {
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
}

# Function to install tools
install_tool() {
    case $1 in
        brew)
            install_homebrew
            ;;
        docker)
            echo "Please install Docker Desktop for Mac from https://www.docker.com/products/docker-desktop"
            ;;
        kind)
            brew install kind
            ;;
        kubectl)
            brew install kubectl
            ;;
        helm)
            brew install helm
            ;;
        just)
            brew install just
            ;;
    esac
}

# Main program
echo "Checking installation of required tools..."

check_install brew
check_install docker
check_install kind
check_install kubectl
check_install helm
check_install just

echo "Check completed."