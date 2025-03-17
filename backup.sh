#!/bin/bash

# Função para exibir mensagem de erro e sair
function error_exit {
    echo "$1" >&2        #Redireciona a mensagem para o stderr (torna-se mais adequado)
    exit 1
}

#Função para verificar se há permissões ler a diretoria original ou para escrever na diretoria de backup
function verificar_permissoes {
    if [ "$C_ATIVADO" = true ]; then
        return
    fi

    #Usa-se variáveis locais para guardar os seus valores quando a função é chamada
    local diretorio="$1"         #O primeiro argumento passado na função é a diretoria a analisar
    local tipo="$2"              #O segundo argumento indica se é para ler ou escrever na diretoria em questão

    if [ "$tipo" = "leitura" ]; then
        #Se a diretoria não tiver permissão de leitura, invoca-se a função error_exit() com a mensagem de erro
        if [ ! -r "$diretorio" ]; then       
            error_exit "Erro: Não há permissão de leitura no diretório de origem: $diretorio"
        fi
    elif [ "$tipo" = "escrita" ]; then
        #Se a diretoria não tiver permissão de escrita, invoca-se a função error_exit() com a mensagem de erro
        if [ ! -w "$diretorio" ]; then       
            error_exit "Erro: Não há permissão de escrita no diretório de backup: $diretorio"
        fi
    fi
}

#Função para verificar se um diretório existe
function verificar_diretorio {
    #Se a diretoria não existir, invoca-se a função error_exit() com a mensagem de erro
    if [ ! -d "$1" ]; then           
        error_exit "O diretório que queres dar backup não existe: $1"
    fi

    #Verifica se a diretoria que se está analisar tem permissão de leitura
    verificar_permissoes "$1" "leitura"

    #Caso a diretoria de backup não exista, cria a diretoria com o nome fornecido quando se chamou o programa
    if [ ! -d "$DIRETORIO_BACKUP" ]; then
        if [ "$C_ATIVADO" = true ]; then
            echo "mkdir -p $DIRETORIO_BACKUP"
            return                  #Como a flag -c está ativada, se a diretoria não existir, não é preciso verificar as permissões
        else
            mkdir -p "$DIRETORIO_BACKUP"
            echo "mkdir -p $DIRETORIO_BACKUP"
        fi
    fi

    #Verifica se existe permissão para escrever na diretoria de backup
    verificar_permissoes "$DIRETORIO_BACKUP" "escrita"

    #Caso a diretoria de backup seja igual à diretoria de origem, surge um erro
    if [[ "$DIRETORIO_BACKUP" == "$DIRETORIO_ORIGEM"* ]]; then
        error_exit "Erro: A pasta de backup ($DIRETORIO_BACKUP) não pode ser a pasta de origem ($DIRETORIO_ORIGEM)."
    fi
}

# Função para verificar quais foram os parâmetros dados para realizar o backup
function configurar_backup {
    while getopts ":cb:r:" opt; do
        case ${opt} in
            #A flag -c apenas mostra quais os comandos usados para realizar o backup
            c )
                C_ATIVADO=true
                ;;
            #A flag -b lê o ficheiro fornecido com os nomes de elementos que não devem ser copiados para o backup
            b )
                EXCLUIR_FICHEIRO="$OPTARG"
                ;;
            #A flag -r lê a expressão dada e verifica que só são copiados ficheiros que tenham a expressão no nome
            r )
                REGEXPR="$OPTARG"
                ;;
            #Quando são passados outros argumentos que não os definidos previamente
            \? )
                error_exit "Uso incorreto do script. Parâmetros aceitos: [-c] [-b tfile] [-r regexpr] <origem> <backup>"
                ;;
        esac
    done
    shift $((OPTIND -1))    #Move os outros argumentos para $@ (Ficam apenas as diretorias)

    #Verifica se os diretórios foram fornecidos
    if [ "$#" -ne 2 ]; then
        error_exit "Uso incorreto do script. Parâmetros aceitos: [-c] [-b tfile] [-r regexpr] <origem> <backup>"
    fi

    DIRETORIO_ORIGEM="$1"
    DIRETORIO_BACKUP="$2"

    #Verifica se a diretoria original pode ser utilizada
    verificar_diretorio "$DIRETORIO_ORIGEM"
}

#Função para verificar se o item está na lista de exclusão
function lista_exclusao {
    #O argumento passado na chamada da função é o item a verificar se está no ficheiro de exclusão
    local item="$1"
    #Vai comparar cada elemento do excluir_array, que tem os nomes do ficheiro de exclusão, com o item         
    for excluido in "${excluir_array[@]}"; do
        if [[ "$excluido" == "$item" ]]; then
            return 0        #Retorna 0 se o item estiver na lista de exclusão
        fi
    done
    return 1                #Caso o item não esteja na lista de exclusão, retorna 1
}

# Função para realizar o backup recursivamente
function backup {
    excluir_array=()            #Array para armazenar arquivos a serem excluídos
    #Se tiver sido passado um ficheiro de exclusão e ele seja um ficheiro,
    #Cada linha irá para o excluir_array
    if [ -n "$EXCLUIR_FICHEIRO" ] && [ -f "$EXCLUIR_FICHEIRO" ]; then
        mapfile -t excluir_array < "$EXCLUIR_FICHEIRO"  
    fi

    verificar_permissoes "$1" "leitura"    #Verifica se a diretoria considerada origem tem permissão de leitura
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
    verificar_permissoes "$2" "escrita"    #Verifica se a diretoria considerada backup tem permissão de escrita
    #Verifica cada item que está na diretoria passada como primeiro argumento
    for item in "$1"/*; do
        nome_item=$(basename "$item")       #Remove as diretorias que fazem parte do nome do item, fica só o seu nome

        #Se o item estiver na lista de exclusão, ignora-se e passa para o próximo item
        if lista_exclusao "$nome_item"; then
            continue
        fi

        #Se for uma diretoria, volta a chamar a função backup para fazer o backup dessa diretoria
        if [ -d "$item" ]; then
            local backup_dir="$2/$nome_item"
            backup "$item" "$backup_dir"

        #Se for um ficheiro, faz o backup do ficheiro normalmente
        elif [ -f "$item" ]; then
            #Se o nome do ficheiro não tiver a expressão dada, é ignorado e passa para o próximo item
            if [ -n "$REGEXPR" ] && [[ ! "$nome_item" =~ $REGEXPR ]]; then
                continue
            fi

            realizar_backup "$item" "$2"    #Realiza o backup do ficheiro
        fi
    done
    apagar_backups "$1" "$2"        #Apaga arquivos antigos no diretório de backup
}

#Função para realizar a cópia de um ficheiro para o backup
function realizar_backup {
    local file="$1"                             #Guarda o nome do ficheiro 
    local backup_file="$2/$(basename "$file")"  #Cria o novo nome do ficheiro no backup, já com o caminho correto
   
    #Se o ficheiro estiver no backup, vai buscar a data de modificação e a data em que foi para o backup
    if [ -f "$backup_file" ]; then
        LAST_DATE=$(stat -c %Y "$file")
        LAST_BACKUP=$(stat -c %Y "$backup_file")

        #Se as datas forem diferentes, copia o ficheiro para o backup outra vez
        if [ "$LAST_DATE" -gt "$LAST_BACKUP" ]; then
            if [ "$C_ATIVADO" = true ]; then
                echo "cp -a $file $backup_file"
            else
                cp -a "$file" "$backup_file"
                echo "cp -a $file $backup_file"
            fi

        elif [ "$LAST_DATE" -lt "$LAST_BACKUP" ]; then
            echo "WARNING: Backup entry $backup_file is newer than source $file; this should not happen"
        fi
    #Se o ficheiro ainda não estiver no backup, verifica se foi usado o -c para ver se tem de se copiar o ficheiro para o backup
    else
        if [ "$C_ATIVADO" = true ]; then
            echo "cp -a $file $backup_file"
        else
            cp -a "$file" "$backup_file"
            echo "cp -a $file $backup_file"
        fi
    fi
}

#Função para apagar backups que entretanto deixaram de estar na diretoria original
function apagar_backups {
    local origem="$1"
    local backup="$2"

    #Se o backup estiver vazio, não vai haver nada para remover e acaba logo a função	
    if [ ! -d "$backup" ] || [ -z "$(ls -A "$backup")" ]; then
        return      
    fi


    #Verifica se cada item do backup, também está na diretoria original
    for item in "$backup"/*; do
        local nome_item=$(basename "$item")         #Remove as diretorias que fazem parte do nome do item, fica só o seu nome
        local origem_item="$origem/$nome_item"      #Cria o caminho do item na na diretoria original

        if [ -d "$item" ]; then
            #Se o item for uma diretoria e não estiver na diretoria original, elimina-se
            if [ ! -d "$origem_item" ]; then
                if [ "$C_ATIVADO" = true ]; then
                    echo "rm -rf $item"
                else
                    echo "rm -rf $item"
                    rm -rf "$item"
                fi
            #Se a diretoria ainda estiver no original, invoca-se novamente a função para verificar o que está dentro da diretoria
            else
                apagar_backups "$origem_item" "$item"
            fi
        #Se for um ficheiro, verifica se não está na diretoria original para depois o apagar 
        elif [ -f "$item" ]; then
            if [ ! -f "$origem_item" ]; then
                if [ "$C_ATIVADO" = true ]; then
                    echo "rm -f $item"
                else
                    echo "rm -rf $item"
                    rm -f "$item"
                fi
            fi
        fi
    done
}

# Main script
#Assume-se que inicialmente nenhuma flag é utilizada, só verificamos que existem na função verificar_backup() 
C_ATIVADO=false                         
EXCLUIR_FICHEIRO=""
REGEXPR=""

configurar_backup "$@"                  # Configura os parâmetros de backup com todos os argumentos passados
backup "$DIRETORIO_ORIGEM" "$DIRETORIO_BACKUP"  # Realiza o backup
