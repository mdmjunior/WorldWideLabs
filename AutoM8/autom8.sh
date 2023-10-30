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
    exit
}

firstExec() {

    clear

    echo -e "AutoM8 - Automated Linux Server Configuration Tool\n" 
    echo -e "by Marcio Moreira Jr\n"

    echo -e "Iniciando a ferramenta...\n"
    sleep 2;

    clear

    # Este laço verifica se o arquivo que indica que o autom8 foi instalado existe. 
    echo -e "Verificando instalação existente\n"

    if [ -f .autom8install ]; then
        firstLine=$(head -n 1 .autom8install)
        if [ "$firstLine" -eq 1 ]; then
            echo -e "AutoM8 já executado anteriormente, abrindo recipes\n"
            sleep 2
            installRecipes
            return
        fi
    fi

    echo -e "Primeira execução, iniciando...\n"
    sleep 2

    RUN_USER=$(whoami)
    echo -e "Usuário atual: $RUN_USER\n"

    current_hostname=$(hostname)
    echo "O hostname atual é: $current_hostname"

    read -p "O hostname está correto? (s/n): " response

    if [ "$response" == "s" ]; then
        LOCAL_HOSTNAME="$current_hostname"
    else
        read -p "Digite o novo hostname desejado: " new_hostname
        sudo hostnamectl set-hostname "$new_hostname"
        LOCAL_HOSTNAME="$new_hostname"
    fi

    current_datetime=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "A data e hora atual do sistema são: $current_datetime\n"
    read -p "A informação está correta? (s/n): " confirm
    if [ "$confirm" != "s" ]; then
        read -p "Informe o timezone correto: " TIMEZONE
        sudo timedatectl set-timezone "$TIMEZONE"
    fi
    DATE_1stRUN=$(date +"%Y-%m-%d")
    TIME_1stRUN=$(date +"%H:%M:%S")

    # Verifica conexão com a internet
    if ! ping -c 1 google.com &> /dev/null; then
        echo "Para a execução do script, acesso à internet é necessário."
        exit 1
    fi

    # Atualização do SO
    echo "Atualizando os repositórios..."
    sudo apt-get update &> /dev/null
    echo "Atualizando os pacotes..."
    sudo apt-get upgrade -y &> /dev/null

    # Instalação de pacotes necessários na primeira execução
    packages=(
        net-tools
        git
        nmap
        tcpdump
        wget
        curl
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

    # Desabilita e remove o UFW
    echo "Desabilitando e removendo o ufw..."
    sudo ufw disable &> /dev/null
    sudo apt-get purge ufw -y &> /dev/null

    # Altera o editor padrão para vim
    update-alternatives --set editor /usr/bin/vim.tiny

    # Gera o arquivo de instalação
    echo "1" > .autom8install

    clear 
  
}

usersAndGroups() {
    # Verifica se os grupos devops e sysops existem, senão cria
    if ! getent group devops &>/dev/null; then
        sudo groupadd devops
    fi

    if ! getent group sysops &>/dev/null; then
        sudo groupadd sysops
    fi

    # Permite que os grupos devops e sysops executem comandos como root sem senha
    if ! sudo grep -qE '^(%devops|%sysops)' /etc/sudoers; then
        echo '%devops ALL=(ALL:ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers
        echo '%sysops ALL=(ALL:ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers
    fi

    # Loop para processar cada linha do arquivo users.txt
    while IFS= read -r line; do
        read -p "O nome do usuário é $line? [S/n] " response

        if [[ $response == "n" || $response == "N" ]]; then
            echo "Por favor, corrija o nome e execute o script novamente."
            exit 1
        fi

        password=$(< /dev/urandom tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c10)

        echo "$line:$password" >> AutoM8/config/createdUsers.txt

        if id "$line" &>/dev/null; then
            echo "O usuário $line já existe."
        else
            sudo useradd -m -G devops,sysops "$line"
            echo "$line:$password" | sudo chpasswd
            chage -d 0 $line
            echo -e "Usuário $line criado com sucesso. Verifique o arquivo users.txt\n"
            echo -e "A senha deve ser trocada no primeiro login do usuário\n"
            if [ -f "AutoM8/config/keys/$username.pub" ]; then
                 mkdir -p "/home/$username/.ssh"
                 cat "AutoM8/config/keys/$username.pub" >> "/home/$username/.ssh/authorized_keys"
                 chown -R "$username:$username" "/home/$username/.ssh"
            fi
        fi

    done < AutoM8/config/users.txt
}

# Chamada das funções

firstExec
usersAndGroups
