#!/bin/bash

exec_hooks() {
    local dir=$1
    if [ -d $dir ]
    then
        echo " == Running $(basename $dir) scripts"
        for x in $dir/*
        do
            if [ -x $x ]
            then
               echo " ==== Running $(basename $x)"
               . $x
            else
                echo skipping $(basename $x)
            fi
        done
        echo " == Done $(basename $dir) scripts"
    fi
}

script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
base_dir=$(cd "${script_dir}/.." && pwd)
crd_template=$base_dir/templates/stack_crd_template.yaml

if [ $# -gt 0 ]
then
   filename=$1
   if [ -f $filename ] 
   then 
       configfile=$filename
   else
       if [ -f $base_dir/$filename ] 
       then
           configfile=$base_dir/$filename
       else
           if  [ -f $base_dir/config/$filename ]
           then
               configfile=$base_dir/config/$filename
           fi
       fi
   fi
else
    configfile=""   
fi

if [ ! "$configfile" == "" ] 
then
    echo "Config file: $configfile"

    # expose an extension point for running before main 'build' processing
    exec_hooks $script_dir/pre_build.d/devfile_stacks

    build_dir="${base_dir}/build/devfile_stacks"
    if [ -z $ASSETS_DIR ]
    then
        assets_dir="${base_dir}/assets/devfile_stacks"
    else
        assets_dir=$ASSETS_DIR
    fi

    mkdir -p ${assets_dir}
    mkdir -p ${build_dir}

    rm $build_dir/image_list > /dev/null 2>&1 

    INDEX_LIST=""
    
    # count the number of stack_groups in the index file
    num_groups=$(yq r ${configfile} stack_groups[*].name | wc -l)
    if [ $num_groups -gt 0 ] 
    then
        for ((group_count=0;group_count<$num_groups;group_count++)); 
        do
            group_name=$(yq r ${configfile} stack_groups[$group_count].name)
            mkdir -p $build_dir/$group_name
            
            echo "Creating stack CRDs for $group_name"
            
            num_urls=$(yq r ${configfile} stack_groups[$group_count].repos[*].url | wc -l)
            
            declare -a included
            declare -a excluded
            
            for ((url_count=0;url_count<$num_urls;url_count++)); 
            do
                url=$(yq r ${configfile} stack_groups[$group_count].repos[$url_count].url)

                repository_url=$(dirname $url)
                fetched_index_file=$(basename $url)
                echo "== fetching $url"
                (curl -s -L ${url} -o $build_dir/$group_name/$fetched_index_file)

                echo "== Adding stacks from index $url"
                unset included
                unset excluded
                
                # check if we have any included stacks
                included_stacks=$(yq r ${configfile} stack_groups[$group_count].repos[$url_count].include)
                if [ ! "${included_stacks}" == "null" ]
                then
                    num_included=$(yq r ${configfile} stack_groups[$group_count].repos[$url_count].include | wc -l)
                    for ((included_count=0;included_count<$num_included;included_count++));
                    do
                        included=("${included[@]}" "$(yq r ${configfile} stack_groups[$group_count].repos[$url_count].include[$included_count]) ")
                    done
                else
                	unset included   
                fi

                # check if we have any excluded stacks
                declare -a excluded
                excluded_stacks=$(yq r ${configfile} stack_groups[$group_count].repos[$url_count].exclude)
                if [ ! "${excluded_stacks}" == "null" ]
                then
                    num_excluded=$(yq r ${configfile} stack_groups[$group_count].repos[$url_count].exclude | wc -l)
                    for ((excluded_count=0;excluded_count<$num_excluded;excluded_count++));
                    do
                        excluded=("${excluded[@]}" "$(yq r ${configfile} stack_groups[$group_count].repos[$url_count].exclude[$excluded_count]) ")
                    done
                else
                    unset excluded
                fi

                echo "included: ${included[@]}"
                echo "excluded: ${excluded[@]}"
                
                # count the stacks within the index
                index_file=$build_dir/$group_name/$fetched_index_file
                num_index_stacks=$(jq length $index_file)
                  	   
                for ((index_stack_count=0;index_stack_count<$num_index_stacks;index_stack_count++));
                do
                    stack_name=$(jq .[$index_stack_count].name $index_file | tr -d '"')
                    relative_path=$(jq .[$index_stack_count].links.self $index_file | tr -d '"')
                    # Relative path always leads with a /
                    devfile_path=$repository_url$relative_path

                    echo "processing stack: $stack_name"
                    
                    # check to see if stack is included
                    if [ "${included}" == "" ] || [[ " ${included[@]} " =~ " ${stack_name} " ]]
                    then
                        generate_stack_CRD=true
                        # check to see if stack is excluded (if we have not include)
                        if [[ " ${excluded[@]} " =~ " ${stack_name} " ]]
                        then
                            generate_stack_CRD=false
                            echo "==== Excluding stack $stack_name "
                        fi
                    else
                        echo "==== Excluding stack $stack_name "
                        generate_stack_CRD=false
                    fi    
                    
                    if [ $generate_stack_CRD == true ]
                    then
                        crd_file="$build_dir/$group_name/$stack_name-CRD.yaml"
                        # Write stack CRD
                        cp -f $crd_template $crd_file
                        $(yq w -i $crd_file metadata.name $stack_name)
                        $(yq w -i $crd_file spec.name $stack_name)
                        $(yq w -i $crd_file spec.devfile $devfile_path)
                    fi
                done
            done
        done
    fi

    # expose an extension point for running after main 'build' processing
    exec_hooks $script_dir/post_build.d/devfile_stacks
else
    echo "A config file needs to be specified. Please run using: "
    echo "./scripts/crd_build.sh <config_filename>"
fi
