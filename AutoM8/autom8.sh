#!/bin/bash

#############################################################################
# AutoM8 - Automated Linux Install Tool
# Author         : Marcio Moreira Junior (marcio.moreira@teladapters.com)
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
    sleep 2;
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
    sleep 2

    current_hostname=$(hostname)
    echo "O hostname atual é: $current_hostname"

    read -p "O hostname está correto? (s/n): " response

    if [[ $response == "s" || $response == "S" ]]; then
        LOCAL_HOSTNAME="$current_hostname"
    else
        read -p "Digite o novo hostname desejado: " new_hostname
        sudo hostnamectl set-hostname "$new_hostname"
        LOCAL_HOSTNAME="$new_hostname"
    fi

    current_datetime=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "A data e hora atual do sistema são: $current_datetime\n"
    read -p "A informação está correta? (s/n): " confirm
    if [[ $confirm != "s" || $confirm != "S" ]]; then
        read -p "Informe o timezone correto: " TIMEZONE
        sudo timedatectl set-timezone "$TIMEZONE"
        TIMEZN=$(sudo timedatectl | grep Local)
        echo "Timezone atualizado com sucesso: $TIMEZN"
    fi
    DATE_1stRUN=$(date +"%Y-%m-%d")
    TIME_1stRUN=$(date +"%H:%M:%S")

    # Verifica conexão com a internet
    if ! ping -c 1 google.com &> /dev/null; then
        echo "Para a execução do script, acesso à internet é necessário."
        exit 1
    fi

    # Atualização do SO
    echo "Atualizando os repositórios do sistema operacional"
    sudo apt-get update &> /dev/null
    sleep 2
    read -p "Deseja visualizar os pacotes disponiveis para atualização? (s/n): " upgradeask
    if [[ $upgradeask == "s" || $upgradeask == "S" ]]; then
        echo -e "Lista de pacotes disponiveis para atualização: \n"
        sudo apt list --upgradable
    fi
    echo "Atualizando os pacotes do sistema operacional"
    sudo apt-get upgrade -y &> /dev/null

    # Instalação de pacotes necessários na primeira execução
    packages=(
        net-tools
        git
        nmap
        vim
        tcpdump
        wget
        curl
        ntpdate
        zfsutils-linux
        openssh-server
        sshpass
        iptables
        netdata
    )
    for package in "${packages[@]}"; do
        echo "Instalando $package..."
        sudo apt-get install -y "$package" > /dev/null 2>&1 &
        pid=$!
        while ps -p $pid > /dev/null; do
            echo -n "."
            sleep 1
        done
        echo " [OK]"
    done

    # Desabilita e remove o UFW
    echo "Desabilitando e removendo o ufw..."
    sudo ufw disable &> /dev/null
    sudo apt-get purge ufw -y &> /dev/null

    # Altera o editor padrão para vim
    echo "Alterando editor padrão para o VIM"
    sudo update-alternatives --set editor /usr/bin/vim.tiny

    # Executa alterações no SSHD para permitir login com chave
    echo "Alterando SSHD para permitir login com chave"
    sudo sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
    sudo sed -i "s/#AuthorizedKeysFile/AuthorizedKeysFile/" /etc/ssh/sshd_config
    sudo systemctl restart sshd 

    # Gera o arquivo de instalação
    echo "1" > .autom8install
    echo "Primeiros ajustes executado com sucesso"
    sleep 2
    clear 
  
}

usersAndGroups() {
    # Verifica se os grupos devops e sysops existem, senão cria
    echo "Criando grupos no sistema"
    if ! getent group devops &>/dev/null; then
        sudo groupadd devops
    fi

    if ! getent group sysops &>/dev/null; then
        sudo groupadd sysops
    fi

    # Permite que os grupos devops e sysops executem comandos como root sem senha
    if ! sudo grep -qE '^(%devops|%sysops)' /etc/sudoers; then
        echo '%devops ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers
        echo '%sysops ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers
    fi

    # Loop para processar cada linha do arquivo users.txt
    while IFS= read -r line; do
        read -p "O nome do usuário é $line? [S/n] " response

        if [[ $response == "n" || $response == "N" ]]; then
            echo "Por favor, corrija o nome e execute o script novamente."
            exit 1
        fi

        password=$(< /dev/urandom tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c10)
        echo "$line - $password" >> config/createdUsers.txt

        if id "$line" &>/dev/null; then
            echo "O usuário $line já existe."
        else
            sudo useradd -s /bin/bash -m -G devops,sysops "$line"
            echo "$line:$password" | sudo chpasswd
            sudo chage -d 0 $line
            echo -e "Usuário $line criado com sucesso. Verifique o arquivo users.txt\n"
            echo -e "A senha deve ser trocada no primeiro login do usuário\n"
            sleep 2
            clear
        fi

    done < config/users.txt
}

# Chamada das funções

firstExec
usersAndGroups
