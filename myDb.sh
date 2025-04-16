#!/bin/bash

#---source
########

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dbPath="$script_dir/DBs"
script_name="myDb.sh"
chmod +x "$script_dir/$script_name"



if ! grep -q "alias mydb" ~/.bashrc; then

    echo "alias mydb='source \"$script_dir/$script_name\"'" >> ~/.bashrc
    
    echo "close and open terminal . You can now run the script using 'mydb' from any terminal session."
fi

# --------------------------------------------------------------1. Create DB directory-------------------------------------------------------------------------------------
if [ ! -d "$dbPath" ]; then
    mkdir -p "$dbPath"
    echo "DB dir created"
else
    echo "DB dir already exists"
fi

# -------------------------------------------------------------------case-insensitive---------------------------------------------------------------------------------------- 
shopt -s nocasematch




####### inner################
#------------- TABLE MENU -------------

table_menu() {
    PS3="Enter your choice from Table Menu (1-8): "
    tableOptions=("Create Table" "List Tables" "Drop Table" "Insert into Table" "Select From Table" "Delete From Table" "Update Table" "Back to Main Menu")

    select option in "${tableOptions[@]}"; do
        case $option in 
        #--------------------------------------------------------------Create Table---------------------------------------------------------------------------------------------
            "Create Table")
                read -p "Enter Table Name: " tableName
                if [[ -z "$tableName" || ! "$tableName" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                    echo "Invalid table name."
                elif [ -f "$tableName" ]; then
                    echo "Table '$tableName' already exists."
                else
                    while true; do
                        read -p "Number of columns: " colNum
                        if [[ ! "$colNum" =~ ^[0-9]+$ ]]; then
                            echo "Error: Please enter a positive integer."
                        elif [[ "$colNum" -le 0 ]]; then
                            echo "Error: Number of columns must be greater than zero."
                        else
                            break
                        fi
                    done

                    columns=""
                    types=""
                    for ((i=1; i<=colNum; i++)); do
                        read -p "Enter column #$i name: " colName
                        if echo "$columns" | grep -q "$colName:"; then
                            echo "Error: Column name '$colName' already exists."
                            ((i--))
                            continue
                        fi
                        while true; do
                            read -p "Enter datatype for '$colName' (int/string): " colType
                            if [[ "$colType" != "int" && "$colType" != "string" ]]; then
                                echo "Error: Datatype must be 'int' or 'string'."
                            else
                                break
                            fi
                        done
                        columns+="$colName:"
                        types+="$colType:"
                    done

                    while true; do
                        read -p "Enter Primary Key column name: " PK
                        IFS=':' read -ra col_array <<< "$columns"
                        pk_valid=false
                        for col in "${col_array[@]}"; do
                            if [[ "$col" == "$PK" ]]; then
                                pk_valid=true
                                break
                            fi
                        done
                        if [[ "$pk_valid" == true ]]; then
                            break
                        else
                            echo "Error: Primary key '$PK' is not a valid column name."
                        fi
                    done
                    echo "$columns" > "$tableName"
                    echo "$types" >> "$tableName"
                    echo "$PK" >> "$tableName"
                    echo "Table '$tableName' created successfully."
                fi
            ;;
        #---------------------------------------------------------------List Tables---------------------------------------------------------------------------------------------
            "List Tables")
                echo "Tables in Database '$dbName':"
                ls -1p | grep -v /
            ;;
        #----------------------------------------------------------------Drop Table---------------------------------------------------------------------------------------------
            "Drop Table")
                read -p "Enter Table Name to drop: " tableName
                if [ -f "$tableName" ]; then
                    rm -f "$tableName"
                    echo "Table '$tableName' dropped successfully."
                else
                    echo "Table '$tableName' does not exist."
                fi
            ;;
        #----------------------------------------------------------------Insert-----------------------------------------------------------------------------------------
            "Insert into Table")
                read -p "Enter Table Name: " tableName
                if [ ! -f "$tableName" ]; then
                    echo "Table '$tableName' not found."
                else
                    IFS=':' read -ra cols <<< "$(sed -n '1p' "$tableName")" 
                    IFS=':' read -ra types <<< "$(sed -n '2p' "$tableName")"
                    PK=$(sed -n '3p' "$tableName")
                    if [ ${#cols[@]} -eq 0 ] || [ ${#types[@]} -eq 0 ] || [ -z "$PK" ]; then
                        echo "Error: Invalid table structure."
                    else
                        declare -A row 
                        for i in "${!cols[@]}"; do
                            while true; do
                                read -p "Enter ${cols[$i]} (${types[$i]}): " val
                                if [ "${types[$i]}" = "int" ] && ! [[ "$val" =~ ^[0-9]+$ ]]; then
                                    echo "Invalid datatype. Must be integer."
                                    continue
                                elif [ "${types[$i]}" = "string" ] && [ -z "$val" ]; then
                                    echo "Invalid datatype. String cannot be empty."
                                    continue
                                fi
                                if [ "${cols[$i]}" = "$PK" ]; then
                                    if tail -n +4 "$tableName" | grep -q "^$val:"; then
                                        echo "Primary key '$val' already exists. Please enter a different value."
                                        continue
                                    fi
                                fi
                                row["${cols[$i]}"]=$val 
                                break
                            done
                        done
                        rowData=""
                        for col in "${cols[@]}"; do
                            rowData+="${row[$col]}:"
                        done
                        echo "${rowData}" >> "$tableName"
                        echo "Row inserted successfully."
                    fi
                fi
            ;;
        #----------------------------------------------------------------Select From Table---------------------------------------------------------------------------------------------
            "Select From Table")
                while true; do
                    read -p "Enter Table Name: " tableName
                    if [[ -z "$tableName" ]]; then
                        echo "Error: Table name cannot be empty."
                    elif [ ! -f "$tableName" ]; then
                        echo "Table '$tableName' not found."
                    else
                        break
                    fi
                done
                
                IFS=':' read -ra cols <<< "$(sed -n '1p' "$tableName")"
                if [[ ${#cols[@]} -eq 0 ]]; then
                    echo "Error: No columns found in table '$tableName'."
                    break
                fi
                echo "Available columns: ${cols[*]}" | tr ' ' ', '
                
                while true; do
                    read -p "Enter columns to select (Name of Columns , press Enter for all): " selected_cols
                    if [[ -z "$selected_cols" ]]; then
                        columnNames=$(sed -n '1p' "$tableName" | sed 's/:/ | /g')
                        echo "-----------------------------------"
                        echo "$columnNames"
                        echo "-----------------------------------"
                        record_count=0
                        if tail -n +4 "$tableName" | grep -q .; then
                            while IFS=':' read -r line; do
                                field_count=$(echo "$line" | awk -F':' '{print NF}')
                                if [[ -z "$line" || "$line" =~ ^[:[:space:]]*$ ]]; then
                                    continue
                                fi
                                if [[ $field_count -lt ${#cols[@]} ]]; then
                                    continue
                                fi
                                echo "$line" | sed 's/:/ | /g'
                                ((record_count++))
                            done < <(tail -n +4 "$tableName")
                        fi
                        if [[ $record_count -eq 0 ]]; then
                            echo "No records found."
                        fi
                        echo "-----------------------------------"
                        break
                    else
                        IFS=',' read -ra sel_cols <<< "$selected_cols"
                        sel_cols=("${sel_cols[@]/#/}")
                        sel_cols=("${sel_cols[@]/%/}")
                        valid=true
                        col_indices=()
                        for sel_col in "${sel_cols[@]}"; do
                            found=false
                            for i in "${!cols[@]}"; do
                                if [[ "${cols[$i]}" == "$sel_col" ]]; then
                                    col_indices+=("$i")   
                                    found=true
                                    break
                                fi
                            done
                            if [[ "$found" == false ]]; then
                                echo "Error: Column '$sel_col' not found."
                                valid=false
                                break
                            fi
                        done
                        if [[ "$valid" == true ]]; then
                            header=""
                            for i in "${col_indices[@]}"; do
                                header+="${cols[$i]} | "
                            done
                            echo "-----------------------------------"
                            echo "${header%| }"
                            echo "-----------------------------------"
                            record_count=0
                            if tail -n +4 "$tableName" | grep -q .; then
                                while IFS=':' read -r line; do
                                    field_count=$(echo "$line" | awk -F':' '{print NF}')
                                    if [[ -z "$line" || "$line" =~ ^[:[:space:]]*$ ]]; then
                                        continue
                                    fi
                                    if [[ $field_count -lt ${#cols[@]} ]]; then
                                        continue
                                    fi
                                    IFS=':' read -r -a row <<< "$line"
                                    output=""
                                    for i in "${col_indices[@]}"; do
                                        output+="${row[$i]:-} | "
                                    done
                                    echo "${output%| }"
                                    ((record_count++))
                                done < <(tail -n +4 "$tableName")
                            fi
                            if [[ $record_count -eq 0 ]]; then
                                echo "No records found."
                            fi
                            echo "-----------------------------------"
                            break
                        fi
                    fi
                done
            ;;
        #-----------------------------------------------------------------Delete From Table---------------------------------------------------------------------------------------------
            "Delete From Table")
                read -p "Enter Table Name: " tableName
                if [ ! -f "$tableName" ]; then
                    echo "Table '$tableName' not found."
                else
                    read -p "Enter Primary Key value to delete row: " pkValue
                    lineNum=$(tail -n +4 "$tableName" | grep -n "^$pkValue:" | head -n 1 | cut -d: -f1)
                    if [ -z "$lineNum" ]; then
                        echo "Primary key '$pkValue' not found."
                    else
                        lineNum=$((lineNum + 3))
                        sed -i "${lineNum}d" "$tableName"
                        echo "Row deleted successfully."
                    fi
                fi
            ;;
        #-----------------------------------------------------------------Update Table---------------------------------------------------------------------------------------------
            "Update Table")
                read -p "Enter Table Name: " tableName
                if [ ! -f "$tableName" ]; then
                    echo "Table '$tableName' not found."
                else
                 
                    pkCol=$(sed -n '3p' "$tableName")
                    if [ -z "$pkCol" ]; then
                        echo "Error: No primary key defined for table '$tableName'."
                    else
                        read -p "Enter Primary Key value for row to update: " pkValue

                        lineNum=$(tail -n +4 "$tableName" | grep -n "^$pkValue:" | head -n 1 | cut -d: -f1)
                        if [ -z "$lineNum" ]; then
                            echo "Primary key '$pkValue' not found."
                        else

                            lineNum=$((lineNum + 3))
                            IFS=':' read -ra cols <<< "$(sed -n '1p' "$tableName")"
                            IFS=':' read -ra types <<< "$(sed -n '2p' "$tableName")"
                            if [ ${#cols[@]} -eq 0 ] || [ ${#types[@]} -eq 0 ]; then
                                echo "Error: Invalid table structure."
                            else
                                declare -A newRow

                                currentRow=$(sed -n "${lineNum}p" "$tableName")
                                IFS=':' read -ra currentValues <<< "$currentRow"
                                if [ ${#currentValues[@]} -lt ${#cols[@]} ]; then
                                    echo "Error: Invalid record format at line $lineNum."
                                else
                                    for i in "${!cols[@]}"; do
                                        while true; do
                                            read -p "New value for ${cols[$i]} (${types[$i]}), leave blank to keep current: " val

                                            if [ -z "$val" ]; then
                                                val="${currentValues[$i]:-}"
                                                break

                                            elif [ "${types[$i]}" = "int" ] && ! [[ "$val" =~ ^[0-9]+$ ]]; then
                                                echo "Invalid datatype. Must be integer."
                                                continue
                                            elif [ "${types[$i]}" = "string" ] && [ -z "$val" ]; then
                                                echo "Invalid datatype. String cannot be empty."
                                                continue

                                            elif [ "${cols[$i]}" = "$pkCol" ]; then
                                                if tail -n +4 "$tableName" | grep -q "^$val:"; then
                                                    echo "Primary key '$val' already exists. Please enter a different value."
                                                    continue
                                                fi
                                            fi
                                            break
                                        done
                                        newRow["${cols[$i]}"]=$val
                                    done
                                    updatedRow=""
                                    for col in "${cols[@]}"; do
                                        updatedRow+="${newRow[$col]}:"
                                    done
                                    if [ $lineNum -le 3 ]; then
                                        echo "Error: Cannot update table header or metadata."
                                    else
                                        sed -i "${lineNum}s|.*|${updatedRow}|" "$tableName"
                                        echo "Row updated successfully."
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            ;;
        #--------------------------------------------------------------------Back---------------------------------------------------------------------------------------------
            "Back to Main Menu")
                cd "$script_dir"
                break 2
            ;;
            *)
                echo "Invalid choice, try again."
            ;;
        esac
    done
}

###########################################################################################################################################################################################

# 2. Main menu
PS3="Enter your choice from the main menu (1-5): "
options=("Create Database" "List Databases" "Connect To Database" "Drop Database" "Exit")

while true; do
    select choice in "${options[@]}"; do
        case $choice in 

            # 2.1 - -------------------------------------------------------------------Create Database------------------------------------------------------------------------------
            "Create Database")
                while true; do
                    read -p "Enter the name of the database (or press Enter to return): " dbName
                   
                    #dbName=$(echo "$dbName" | xargs)
                   
                    dbName="${dbName//[[:space:]]/}"
                   
                    if [[ -z "$dbName" ]]; then
                        echo "Returning to the main menu..."
                        break
                    fi

                    # Validation
                    if [[ ! "$dbName" =~ ^[a-zA-Z_] ]]; then
                        echo "Error! Database name must start with a letter or underscore."

                    elif [[ ! "$dbName" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                        echo "Error! No spaces or special characters allowed."
                    
                    elif echo "$dbName" | grep -wqiE "select|insert|update|delete|create|drop|from|where|table|database|into|alter|rename|join"; then
                        echo "Error! '$dbName' is a reserved SQL keyword."
                    
                    elif [[ ${#dbName} -gt 64 ]]; then
                        echo "Error: Database name cannot exceed 64 characters."

                    #elif [[ "$dbName" =~ \  ]]; then
                       # echo "Error! Database name cannot contain spaces."

                    elif [ -d "$dbPath/$dbName" ]; then
                        echo "Error!! Database '$dbName' already exists."

                    else
                        read -p "Are you sure you want to create database '$dbName'? [y/n]: " confirm
                        if [[ ! "$confirm" =~ ^[yY] ]]; then
                            echo "Database creation cancelled."
                            continue
                        fi
                        mkdir -p "$dbPath/$dbName"
                        echo "Database '$dbName' created successfully."
                    fi
                    
                    read -p "Do you want to add another database? [y/n]: " choice
                    case $choice in
                        [yY]* ) continue ;;
                        * ) echo "Returning to the main menu..."; break ;;
                    esac
                done
                ;;
            
            # 2.2 - --------------------------------------------------------------------List Databases-----------------------------------------------------------------------------
            "List Databases")
                if [ -z "$(ls -1 "$dbPath")" ]; then
                    echo "No databases found. returning to main menu..."
                    continue
                fi
                echo "================================="
                echo "Available Databases:"
                echo "================================="
                    ls -1 "$dbPath" | awk '{print NR".", $0 }'
                echo "================================="
            ;;

            # 2.3 - --------------------------------------------------------------------Connect To Database------------------------------------------------------------------------
            "Connect To Database")

                if [ -z "$(ls -1 "$dbPath")" ]; then
                    echo "No databases found. returning to main menu..."
                    continue
                fi
                echo "================================="
                echo "Available Databases:"
                echo "================================="
                ls -1 "$dbPath" | awk '{print NR".", $0}'
                echo "================================="
                read -p "Do you want to select a database? [y/n] : " answer
                case $answer in 
                    [yY]* )
                        read -p "Enter Database Name or Number to Connect (Press Enter to return back): " input
                        if [[ -z "$input" ]]; then
                            echo "Returning to the main menu..."
                            continue
                        fi
                        case $input in 
                            ''|*[!0-9]* )
                                dbName=$input
                            ;;
                            * )
                                dbName=$(ls -1 "$dbPath" | sed -n "${input}p")
                                if [[ -z "$dbName" ]]; then
                                    echo "There is no Database with number '$input' Returning to main menu..."
                                    continue
                                fi
                            ;;
                        esac

                        if [ -d "$dbPath/$dbName" ]; then 
                            echo "Connected to Database '$dbName'."
                            if ! cd "$dbPath/$dbName"; then
                                echo "Error: can't Enter "
                                continue
                            fi
                            echo "You are now in: $(pwd)"
                            if [ -z "$(ls -A)" ]; then
                                echo "Warning: The database '$dbName' is empty"
                            fi
                            table_menu
                           
                        else 
                            echo "Database '$dbName' does not exist."
                        fi
                    ;;
                    * )
                        echo "Returning to the main menu..."
                    ;;
                esac
            ;;

            # 2.4 -----------------------------------------------------------------------Drop Database-----------------------------------------------------------------------------
            "Drop Database")
                while true; do
                    if [ -z "$(ls -1 "$dbPath")" ]; then
                    echo "No databases available to delete"
                    echo "Returning to the main menu..."
                    break
                    fi
                    echo "================================="
                    echo "Available Databases:"
                    echo "================================="
                    ls -1 "$dbPath" | awk '{print NR".", $0}'
                    echo "================================="
                    read -p "Enter Database Name or Number to delete (Press Enter to cancel): " input
                    if [[ -z "$input" ]]; then
                        echo "Returning to the main menu..."
                        break
                    fi

                    case $input in 
                        ''|*[!0-9]* )
                            dbName=$input
                        ;;
                        * )
                            dbName=$(ls -1 "$dbPath" | sed -n "${input}p")
                            if [[ -z "$dbName" ]]; then
                                echo "There is no Database with number '$input'. Returning to main menu."
                                continue
                            fi
                        ;;
                    esac

                    if [ -d "$dbPath/$dbName" ]; then
                        if [ "$(ls -A "$dbPath/$dbName")" ]; then
                            read -p "Database '$dbName' is not empty, drop anyway? [y/n]: " answer
                            case $answer in 
                                [yY]* )
                                    rm -rf "$dbPath/$dbName"
                                    echo "Database '$dbName' and all its tables deleted successfully."
                                    if [ -z "$(ls -1 "$dbPath")" ]; then
                                            echo "No more databases left to delete."
                                            break
                                    fi
                                    read -p "Do you want to delete another database? [y/n]: " delete
                                    case $delete in
                                        [yY]* ) continue ;; 
                                        * ) echo "Returning to the main menu..."; break ;; 
                                    esac
                                ;;
                                * )
                                    echo "Deletion cancelled. Returning to main menu..."
                                    break 
                                ;;
                            esac
                        else
                            rm -rf "$dbPath/$dbName"
                            echo "Database '$dbName' deleted successfully."
                            
                            read -p "Do you want to delete another database? [y/n]: " delete
                            case $delete in
                                [yY]* )continue ;; 
                                * )
                                    echo "Returning to the main menu..."
                                    break  
                            esac
                        fi
                    else
                        echo "Database '$dbName' does not exist."
                    fi
                done
            ;;


            # 2.5 - ------------------------------------------------------------------------Exit--------------------------------------------------------------------
            "Exit")
                read -p "Are you sure you want to exit? [y/n]: " answer
                case $answer in 
                    [yY]* )
                        echo "Exiting... byyye :)"
                        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
                           
                            exit 0
                        else
                            
                            return 0
                        fi

                    ;;
                    * )
                        echo "Returning to the main menu..."
                    ;;
                esac
            ;;

            *)  
                echo "Error! enter number between 1 to 5."
            ;;
        esac
    done
done


