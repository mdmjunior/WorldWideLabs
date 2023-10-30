#!/bin/bash

#############################################################################
# AutoM8 - Automated Linux Install Tool
# https://autom8.worldwidelabs.com.br
# Author         : Marcio Moreira Junior
# Email          : mdmjunior@gmail.com
# Date           : 2023/10/29
# Version        : 1.0    
#############################################################################

#!/bin/bash

installRecipes() {
    echo "Não implementado";
    exit();
}

firstExec() {
    # Passo 0
    if [ -f .autom8install ]; then
        firstLine=$(head -n 1 .autom8install)
        if [ "$firstLine" -eq 1 ]; then
            installRecipes
            return
        fi
    fi

    # Passo 1
    RUN_USER=$(whoami)
    USER_HOME=$(eval echo "~$RUN_USER")

    # Passo 2
    current_datetime=$(date +"%Y-%m-%d %H:%M:%S")
    echo "A data e hora atual do sistema são: $current_datetime"
    read -p "A informação está correta? (s/n): " confirm
    if [ "$confirm" != "s" ]; then
        read -p "Informe o timezone correto: " TIMEZONE
        sudo timedatectl set-timezone "$TIMEZONE"
    fi
    DATE_1stRUN=$(date +"%Y-%m-%d")
    TIME_1stRUN=$(date +"%H:%M:%S")

    # Passo 3
    if ! ping -c 1 google.com &> /dev/null; then
        echo "Para a execução do script, acesso à internet é necessário."
        exit 1
    fi

    # Passo 4
    echo "Atualizando os repositórios..."
    sudo apt-get update &> /dev/null

    # Passo 5
    echo "Atualizando os pacotes..."
    sudo apt-get upgrade -y &> /dev/null

    # Passo 6
    packages=(
        net-tools
        git
        nmap
        tcpdump
        wget
        curl
        openssh-server
        ntpdate
        zfsutils-linux
        gcc
        sshpass
        iptables
        iptables-persistent
        netfilter-persistent
        netdata
    )
    for package in "${packages[@]}"; do
        echo "Instalando $package..."
        sudo apt-get install -y "$package" &> /dev/null
    done

    # Passo 7
    echo "Desabilitando e removendo o ufw..."
    sudo ufw disable &> /dev/null
    sudo apt-get purge ufw -y &> /dev/null

    # Passo 8
    echo "1" > .autom8install

    # Passo 9
    installRecipes
}

# Chamada da função firstExec
firstExec

