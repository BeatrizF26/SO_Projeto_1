
#!/bin/bash

#Função para exibir mensagem de erro e sair
function error_exit {
    echo "$1" >&2       #Redireciona a mensagem para o stderr (torna-se mais adequado)
    exit 1
}

#Função para verificar se um diretório existe
function verificar_diretorio {
    if [ ! -d "$1" ]; then
        error_exit "O diretório que queres comparar (o original) não existe: $1"
    fi
    if [ ! -d "$2" ]; then
        error_exit "O diretório que queres comparar (o de backup) não existe: $2"
    fi
}

#Função para configurar variáveis de backup e verificar se as diretorias existem
function configurar_backup {
    DIRETORIO_ORIGEM="$1"
    DIRETORIO_BACKUP="$2"
    verificar_diretorio "$DIRETORIO_ORIGEM" "$DIRETORIO_BACKUP"
}

#Função para verificar diferenças
function verificar_diferencas {
    local DIRETORIO_ORIGEM="$1"     #O primeiro argumento passado na função é considerado a diretoria de origem
    local DIRETORIO_BACKUP="$2"     #O segundo argumento passado na função é considerado a diretoria de backup

    #Verifica se cada item da diretoria de origem está na diretoria de backup
    for item in "$DIRETORIO_ORIGEM"/*; do
        nome_item=$(basename "$item")
        item_backup="$DIRETORIO_BACKUP/$nome_item"      #Cria o caminho que o item devia ter no backup

        #Caso o item seja uma diretoria, invoca novamente a função para ver o interior da diretoria
        if [ -d "$item" ]; then
            if [ -d "$item_backup" ]; then
                verificar_diferencas "$item" "$item_backup"
            #Se o caminho criado não existir no backup, surge uma mensagem de erro
            else
                echo "Diretório no backup não encontrado: $item_backup"
            fi
        elif [ -f "$item" ]; then
            #Verifica se o arquivo existe no backup
            if [ -f "$item_backup" ]; then
                #Calcula o md5sum de ambos os arquivos
                md5_origem=$(md5sum "$item" | awk '{ print $1 }')
                md5_backup=$(md5sum "$item_backup" | awk '{ print $1 }')

                #Se o valor for diferente, surge a mensagem de erro indicada no enunciado
                if [ "$md5_origem" != "$md5_backup" ]; then
                    echo "$item $item_backup differ."
                fi
            #Se o caminho criado não existir no backup, surge uma mensagem de erro
            else
                echo "Arquivo no backup não encontrado: $item_backup"
            fi
        fi
    done

    for item_backup in "$DIRETORIO_BACKUP"/*; do
        nome_item=$(basename "$item_backup")
        item_origem="$DIRETORIO_ORIGEM/$nome_item"

        if [ ! -e "$item_origem" ]; then
            echo "Item apagado do diretório original: $item_origem"
        fi
    done

     
}

# Main script
#Verifica se são introduzidos dois argumentos
if [ "$#" -ne 2 ]; then
    error_exit "Uso incorreto do script. Parâmetros aceitos: <origem> <backup>"
fi

# Configura os diretórios de origem e backup
configurar_backup "$1" "$2"

# Chama a função para verificar as diferenças com as variáveis configuradas
verificar_diferencas "$DIRETORIO_ORIGEM" "$DIRETORIO_BACKUP"

