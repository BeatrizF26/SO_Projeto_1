#!/bin/bash

# Função para exibir mensagem de erro e sair
function error_exit {
    
    ERRORS=$((ERRORS + 1))
    echo "$1" >&2
    echo "While backuping $DIRETORIO_ATUAL: $ERRORS Errors; $WARNINGS Warnings; $UPDATES Updated; $COPIES Copied ("$TAMANHO_COPIES"B); $DELETED Deleted ("$TAMANHO_DELETED"B)"
    reset_contadores
    exit 1
}

function verificar_permissoes {
    local diretorio="$1"
    local tipo="$2"

    # Verifica permissões de leitura (para origem) ou escrita (para destino)
    if [ "$tipo" = "leitura" ]; then
        if [ ! -r "$diretorio" ]; then
            error_exit "Erro: Não há permissão de leitura no diretório de origem: $diretorio"
        fi
    elif [ "$tipo" = "escrita" ]; then
        if [ ! -w "$diretorio" ]; then
            error_exit "Erro: Não há permissão de escrita no diretório de backup: $diretorio"
        fi
    fi
}

# Função para verificar se um diretório existe
function verificar_diretorio {
    if [ ! -d "$1" ]; then
        error_exit "O diretório que queres dar backup não existe: $1"
    fi

    # Verifica permissões de leitura para o diretório de origem
    verificar_permissoes "$1" "leitura"

    # Verifica se o diretório de backup existe e se temos permissão de escrita
    if [ ! -d "$DIRETORIO_BACKUP" ]; then
        if [ "$C_ATIVADO" = true ]; then
            echo "mkdir -p $DIRETORIO_BACKUP"
            return          #Como a flag -c está ativada, se a diretoria não existir, não é preciso verificar as permissões
        else
            mkdir -p "$DIRETORIO_BACKUP"
            echo "mkdir -p $DIRETORIO_BACKUP"
        fi
    fi

    # Verifica permissões de escrita para o diretório de backup
    verificar_permissoes "$DIRETORIO_BACKUP" "escrita"

    # Verifica se o diretório de backup não está dentro da origem
    if [[ "$DIRETORIO_BACKUP" == "$DIRETORIO_ORIGEM"* ]]; then
        error_exit "Erro: A pasta de backup ($DIRETORIO_BACKUP) não pode ser a pasta de origem ($DIRETORIO_ORIGEM)."
    fi
}

# Função para configurar variáveis de backup
function configurar_backup {
    while getopts ":cb:r:" opt; do
        case ${opt} in
            c )
                C_ATIVADO=true
                ;;
            b )                
                EXCLUIR_FICHEIRO="$OPTARG"
                ;;
            r )
                REGEXPR="$OPTARG"
                ;;
            \? )
                error_exit "Uso incorreto do script. Parâmetros aceitos: [-c] [-b tfile] [-r regexpr] <origem> <backup>"
                ;;
        esac
    done
    shift $((OPTIND -1))

    # Verifica se os diretórios foram fornecidos
    if [ "$#" -ne 2 ]; then
        error_exit "Uso incorreto do script. Parâmetros aceitos: [-c] [-b tfile] [-r regexpr] <origem> <backup>"
    fi

    DIRETORIO_ORIGEM="$1"
    DIRETORIO_BACKUP="$2"
    verificar_diretorio "$DIRETORIO_ORIGEM"
}

# Função para verificar se o item está na lista de exclusão
function lista_exclusao {
    local item="$1"
    for excluido in "${excluir_array[@]}"; do
        if [[ "$excluido" == "$item" ]]; then
            return 0
        fi
    done
    return 1
}

function reset_contadores {
    ERRORS=0
    UPDATES=0
    COPIES=0
    TAMANHO_COPIES=0
    DELETED=0
    TAMANHO_DELETED=0
    WARNINGS=0
}

# Função para realizar o backup recursivamente
function backup {
     # Reseta os contadores no início da função
    local temp_errors=0
    local temp_warnings=0
    local temp_updates=0
    local temp_copies=0
    local temp_tamanho_copies=0
    local temp_deleted=0
    local temp_tamanho_deleted=0

    excluir_array=()
    if [ -n "$EXCLUIR_FICHEIRO" ] && [ -f "$EXCLUIR_FICHEIRO" ]; then
        mapfile -t excluir_array < "$EXCLUIR_FICHEIRO"
    fi

    #Cria o diretório passado como segundo argumento se ele não existir no backup
    if [ ! -d "$2" ]; then
        if [ "$C_ATIVADO" = true ]; then
            if [ "$2" != "$DIRETORIO_BACKUP" ]; then        #Para não aparecer dois mkdirs da pasta backup
                echo "mkdir -p $2"
            fi
        else
            mkdir -p "$2"
            echo "mkdir -p $2"
        fi
    fi

    for item in "$1"/*; do
        nome_item=$(basename "$item")

        if [[ "$item" == "$DIRETORIO_BACKUP"* ]]; then
            error_exit "Erro: A pasta de backup ($DIRETORIO_BACKUP) não pode estar contida dentro da pasta de origem ($DIRETORIO_ORIGEM)."
        fi
        if lista_exclusao "$nome_item"; then
            continue

        fi

        if [ -d "$item" ]; then
            # Diretório: cria backup do diretório
            local backup_dir="$2/$nome_item"

            bash "$0" $([ "$C_ATIVADO" = true ] && echo "-c") ${EXCLUIR_FICHEIRO:+-b "$EXCLUIR_FICHEIRO"} ${REGEXPR:+-r "$REGEXPR"} "$item" "$backup_dir"
            
            temp_errors=$((temp_errors + ERRORS))
            temp_warnings=$((temp_warnings + WARNINGS))
            temp_updates=$((temp_updates + UPDATES))
            temp_copies=$((temp_copies + COPIES))
            temp_tamanho_copies=$((temp_tamanho_copies + TAMANHO_COPIES))
            temp_deleted=$((temp_deleted + DELETED))
            temp_tamanho_deleted=$((temp_tamanho_deleted + TAMANHO_DELETED))
          
            reset_contadores

        elif [ -f "$item" ]; then
            # Arquivo: realiza backup

            # Ignora itens que não correspondem à expressão regular
            if [ -n "$REGEXPR" ] && [[ ! "$nome_item" =~ $REGEXPR ]]; then
                continue
            fi

            realizar_backup "$item" "$2"
            temp_copies=$((temp_copies + COPIES))
            temp_tamanho_copies=$((temp_tamanho_copies + TAMANHO_COPIES))
            temp_updates=$((temp_updates + UPDATES))
            temp_warnings=$((temp_warnings + WARNINGS))

            reset_contadores
        fi
    done

    apagar_backups "$1" "$2"
    temp_tamanho_deleted=$((temp_tamanho_deleted + TAMANHO_DELETED))
    temp_deleted=$((temp_deleted + DELETED))
    WHILE_MESSAGES+="While backuping $1: $temp_errors Errors; $temp_warnings Warnings; $temp_updates Updated; $temp_copies Copied ("$temp_tamanho_copies"B); $temp_deleted Deleted ("$temp_tamanho_deleted"B)"
    reset_contadores
}


function realizar_backup {
    local file="$1"
    local backup_file="$2/$(basename "$file")"

    if [ -f "$backup_file" ]; then
        LAST_DATE=$(stat -c %Y "$file")
        LAST_BACKUP=$(stat -c %Y "$backup_file")


        if [ "$LAST_DATE" -gt "$LAST_BACKUP" ]; then
            # Arquivo da origem é mais recente: substitui no backup e conta como atualização
            if [ "$C_ATIVADO" = true ]; then
                echo "cp -a $file $backup_file"
            else
                cp -a "$file" "$backup_file"
                echo "cp -a $file $backup_file"
            fi
            ((UPDATES += 1))
        elif [ "$LAST_DATE" -lt "$LAST_BACKUP" ]; then
            # Emite um aviso se o backup for mais recente do que o arquivo original
            echo "WARNING: Backup entry $backup_file is newer than source $file; this should not happen"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
    # Arquivo não existe no backup: realiza cópia inicial
        TAMANHO_ORIGEM=$(stat -c %s "$file")
        if [ "$C_ATIVADO" = true ]; then
            echo "cp -a $file $backup_file"
            
        else
            
            cp -a "$file" "$backup_file"
            echo "cp -a $file $backup_file"
            COPIES=$((COPIES + 1))
        fi
        TAMANHO_COPIES=$((TAMANHO_COPIES + TAMANHO_ORIGEM))

    fi

}

# Função para apagar backups antigos recursivamente
function apagar_backups {
    
    local origem="$1"
    local backup="$2"
    #Se o backup estiver vazio ou não estiver criado (casos com o -c), não vai haver nada para remover e acaba logo a função	
    if [ ! -d "$backup" ] || [ -z "$(ls -A "$backup")" ]; then
        return      
    fi

    for item in "$backup"/*; do
        local nome_item=$(basename "$item")
        local origem_item="$origem/$nome_item"

        if [ -d "$item" ]; then
            # Diretório: verifica recursivamente
            if [ ! -d "$origem_item" ]; then
                if [ "$C_ATIVADO" = true ]; then
                
                    echo "rm -rf $item"
                else
                    TAMANHO_DELETED=$((TAMANHO_DELETED + $(stat -c %s "$item")))
                    DELETED=$((DELETED + 1))
                    echo "rm -rf $item"
                    rm -rf "$item"   
                fi
            else
                apagar_backups "$origem_item" "$item"
            fi
        elif [ -f "$item" ]; then
            # Arquivo: remove se não existir na origem
            if [ ! -f "$origem_item" ]; then
                if [ "$C_ATIVADO" = true ]; then
                    echo "rm -f $item"
                else
                    TAMANHO_DELETED=$((TAMANHO_DELETED + $(stat -c %s "$item")))
                    DELETED=$((DELETED + 1))
                    echo "rm -rf $item"
                    rm -f "$item"
                fi
            fi
        fi
    done
}

# Main script
C_ATIVADO=false
EXCLUIR_FICHEIRO=""
REGEXPR=""
ERRORS=0
WARNINGS=0
UPDATES=0
COPIES=0
TAMANHO_COPIES=0
DELETED=0
TAMANHO_DELETED=0
WHILE_MESSAGES=""

configurar_backup "$@"
reset_contadores
backup "$DIRETORIO_ORIGEM" "$DIRETORIO_BACKUP"
echo -e "$WHILE_MESSAGES"
