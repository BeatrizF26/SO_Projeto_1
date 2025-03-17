#!/bin/bash

# Função para exibir mensagem de erro e terminar o programa
function error_exit {
   echo "$1"
   exit 1
}

#Função para verificar se há permissões ler a diretoria original ou para escrever na diretoria de backup
function verificar_permissoes {
    if [ "$C_ATIVADO" = true ]; then
        return
    fi

    diretorio="$1"                          #O primeiro argumento passado na função é a diretoria a analisar
    tipo="$2"                               #O segundo argumento indica se é para ler ou escrever na diretoria em questão

    if [ "$tipo" = "leitura" ]; then
        if [ ! -r "$diretorio" ]; then      #Se a diretoria não tiver permissão de leitura, invoca-se a função error_exit() com a mensagem de erro
            error_exit "Erro: Não há permissão de leitura no diretório de origem: $diretorio"
        fi
    elif [ "$tipo" = "escrita" ]; then
        if [ ! -w "$diretorio" ]; then      #Se a diretoria não tiver permissão de escrita, invoca-se a função error_exit() com a mensagem de erro
            error_exit "Erro: Não há permissão de escrita no diretório de backup: $diretorio"
        fi
    fi
}

# Função para verificar se um diretório existe
function verificar_diretorio {
    if [ ! -d "$1" ]; then              #Se a diretoria não existir, invoca-se a função error_exit() com a mensagem de erro
        error_exit "O diretório que queres dar backup não existe."
    fi

    verificar_permissoes "$1" "leitura"         #Verifica se a diretoria que se está analisar tem permissão de leitura
}

# Função para configurar as variáveis necessárias para realizar o backup
function verificar_backup {
    if [ "$#" -eq 3 ]; then             #Se o número de argumentos fornecidos forem três,
        if [ "$1" != '-c' ]; then       #Verifica se o primeiro é a flag -c e assume que a diretoria original é o segundo e a diretoria de backup é o terceiro
            error_exit "Como segundo argumento só é aceite o parâmetro -c"
        fi
        C_ATIVADO=true
        DIRETORIO_BACKUP="$3"
        DIRETORIO_ORIGEM="$2"
    elif [ "$#" -eq 2 ]; then           
        DIRETORIO_BACKUP="$2"
        DIRETORIO_ORIGEM="$1"
    else                                #Caso sejam fornecidos menos do que dois ou mais do que três argumentos, invoca-se a função de error_exit() com a mensagem de erro
        error_exit "Tens de fornecer entre 2 a 3 argumentos"
    fi

    verificar_diretorio "$DIRETORIO_ORIGEM"           #Verifica se a diretoria original pode ser utilizada

    if [[ "$DIRETORIO_BACKUP" == "$DIRETORIO_ORIGEM"* ]]; then              #Caso a diretoria de backup seja igual à diretoria de origem, surge um erro
        error_exit "Erro: A pasta de backup ($DIRETORIO_BACKUP) não pode ser a pasta de origem ($DIRETORIO_ORIGEM)."
    fi

    if [ ! -d "$DIRETORIO_BACKUP" ]; then         #Caso a diretoria de backup não exista, cria a diretoria com o nome fornecido quando se chamou o programa
        if [ "$C_ATIVADO" = true ]; then
            echo "mkdir -p $DIRETORIO_BACKUP"
        else
            echo "mkdir -p $DIRETORIO_BACKUP"
            mkdir -p "$DIRETORIO_BACKUP"
        fi
    fi

    verificar_permissoes "$DIRETORIO_BACKUP" "escrita"        #Verifica se existe permissão para escrever na diretoria de backup
}


# Função para verificar subdiretorias na diretoria original
function verificar_subdiretorios {
    for item in "$DIRETORIO_ORIGEM"/*; do               #Verifica todos os itens que estão na diretoria original
        if [ -d "$item" ]; then                         #Verifica se o item é uma diretoria e, caso seja, exibe uma mensagem de erro
            error_exit "A diretoria que pretende fazer backup contém subdiretórios"
        fi
    done
}

# Função para realizar o backup da diretoria original
function backup {
    if [ ! -d "$DIRETORIO_ORIGEM" ] || [ -z "$(ls -A "$DIRETORIO_ORIGEM")" ]; then
        return      
    fi

    for file in "$DIRETORIO_ORIGEM"/*; do
        if [ -f "$DIRETORIO_BACKUP/$(basename "$file")" ]; then                 #Se o ficheiro estiver no backup, vai buscar a data de modificação e a data em que foi para o backup
            LAST_DATE=$(stat -c %Y "$file")                                     
            LAST_BACKUP=$(stat -c %Y "$DIRETORIO_BACKUP/$(basename "$file")")

            if [ "$LAST_DATE" -gt "$LAST_BACKUP" ]; then                     #Se as datas forem diferentes, verifica se foi utilizado o -c
                if [ "$C_ATIVADO" = true ]; then
                    echo "cp -a $file $DIRETORIO_BACKUP/$(basename "$file")"
                else
                    cp -a "$file" "$DIRETORIO_BACKUP"                               
                    echo "cp -a $file $DIRETORIO_BACKUP/$(basename "$file")"
                fi

            elif [ "$LAST_DATE" -lt "$LAST_BACKUP" ]; then
                echo "WARNING: Backup entry $backup_file is newer than source $file; this should not happen"
            fi
        else                                    #Se o ficheiro ainda não estiver no backup, verifica se foi usado o -c para ver se tem de se copiar o ficheiro para o backup
            if [ "$C_ATIVADO" = true ]; then                
                echo "cp -a $file $DIRETORIO_BACKUP/$(basename "$file")"
            else
                cp -a "$file" "$DIRETORIO_BACKUP"
                echo "cp -a $file $DIRETORIO_BACKUP/$(basename "$file")"
            fi
        fi
    done
}

# Função para apagar backups que entretanto deixaram de estar na diretoria original
function apagar_backups {
    for file in "$DIRETORIO_BACKUP"/*; do                               #Verifica se cada ficheiro do backup, também está na diretoria original
        if [ ! -f "$DIRETORIO_ORIGEM/$(basename "$file")" ]; then                        
            if [ "$C_ATIVADO" = true ]; then                            #Caso seja utilizado o -c, mostra só qual seria o comando a executar
                echo "rm $file"
            else
                rm "$file"
                echo "rm $file"
            fi
        fi
    done
}

# Main script
C_ATIVADO=false                                         #Assume-se que inicialmente o -c não é utilizado, só verificamos a sua utilização na função verificar_backup() 
verificar_backup "$@"                                   #Chama-se a função verificar_backup() com todos os argumentos utilizados pelo utilizador ($@)
verificar_subdiretorios                                 #Invoca-se a função verificar_subdiretorios() para garantir que apenas existem ficheiros 
backup                                                  #Realiza o backup
apagar_backups                                          #Chama a função apagar_backups() para verificar se entretanto foi apagado algum ficheiro na diretoria original
