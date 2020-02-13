#!/bin/bash

script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
base_dir=$(cd "${script_dir}/.." && pwd)

# Allow multiple stacks to be selected
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

echo "Config file: $configfile"

if [ ! "$configfile" == "" ] 
then
    build_dir="${base_dir}/build"
    if [ -z $ASSETS_DIR ]
    then
        assets_dir="${base_dir}/assets"
    else
        assets_dir=$ASSETS_DIR
    fi

    mkdir -p ${assets_dir}
    mkdir -p ${build_dir}

    REPO_LIST=""
    INDEX_LIST=""
        
    image_org=$(yq r ${configfile} image-org)
    image_registry=$(yq r ${configfile} image-registry)
    
    if [ "${image_org}" != "null" ] ||  [ "${image_registry}" != "null" ]
    then
        export BUILD_ALL=true
        export BUILD=true
        
        if [ "${image_org}" != "null" ]
        then
            export IMAGE_REGISTRY_ORG="${image_org}"
        fi
        if [ "${image_registry}" != "null" ]
        then
            export IMAGE_REGISTRY="${image_registry}"
        fi
        
        export prefetch_dir="${base_dir}/build/prefetch"
        mkdir -p ${prefetch_dir}
        mkdir -p ${build_dir}/index-src
    fi
    
    # count the number of stacks in the index file
    num_stacks=$(yq r ${configfile} stacks[*].name | wc -l)
    if [ $num_stacks -gt 0 ] 
    then
        for ((stack_count=0;stack_count<$num_stacks;stack_count++)); 
        do
            stack_name=$(yq r ${configfile} stacks[$stack_count].name)
            if [ ! -z $BUILD ] && [ $BUILD == true ]
            then
                mkdir -p $base_dir/$stack_name
            fi
            
            REPO_LIST+="${stack_name} "
            
            echo "Creating consolidated index for $stack_name"

            index_file_temp=$assets_dir/$stack_name-index.yaml
            echo "apiVersion: v2" > $index_file_temp
            echo "stacks:" >> $index_file_temp
            
            num_urls=$(yq r ${configfile} stacks[$stack_count].repos[*].url | wc -l)
            
            for ((url_count=0;url_count<$num_urls;url_count++)); 
            do
                url=$(yq r ${configfile} stacks[$stack_count].repos[$url_count].url)
                fetched_index_file=$(basename $url)
                INDEX_LIST+="${url} "
                echo "== fetching $url"
                (curl -s -L ${url} -o $build_dir/$fetched_index_file)
                
                echo "==  Adding stacks from index $url"

                # count the stacks within the index
                num_index_stacks=$(yq r $build_dir/$fetched_index_file stacks[*].id | wc -l)
                     
                all_stacks=$build_dir/all_stacks.yaml
                one_stack=$build_dir/one_stack.yaml

                # setup a yaml with just the stack info 
                # and new yaml with everything but stacks
                yq r $build_dir/$fetched_index_file stacks | yq p - stacks > $all_stacks

                stack_added="false"
                  	   
                for ((index_stack_count=0;index_stack_count<$num_index_stacks;index_stack_count++));
                do
                    stack_id=$(yq r ${build_dir}/${fetched_index_file} stacks[$index_stack_count].id)
                    stack_version=$(yq r ${build_dir}/${fetched_index_file} stacks[$index_stack_count].version)
                        
                    yq r $all_stacks stacks.[$index_stack_count] > $one_stack
                    
                    # check if stack has already been added to consolidated index
                    num_added_stacks=$(yq r $index_file_temp stacks[*].id | wc -l)
                    for ((added_stack_count=0;added_stack_count<$num_added_stacks;added_stack_count++));
                    do
                        added_stack_id=$(yq r $index_file_temp stacks[$added_stack_count].id)
                        added_stack_version=$(yq r $index_file_temp stacks[$added_stack_count].version)
                        if [ "${stack_id}" == "${added_stack_id}" ]
                        then
                            if [ "${stack_version}" == "${added_stack_version}" ]
                            then
                                stack_added="true"
                            fi
                        fi
                    done
                    
                    if [ "${stack_added}" == "true" ]
                    then
                        # if already added then log warning message
                        echo "==== ERROR - stack $stack_id $stack_version already added to index"
                    else
                        # if not already added then add to consolidated index
                        echo "====  We are adding stack $stack_id $stack_version"
                        yq p -i $one_stack stacks.[+]                        
                        yq m -a -i $index_file_temp $one_stack
                    fi
                    
                    if [ ! -z $BUILD ] && [ $BUILD == true ]
                    then
                        for x in $(cat $one_stack | grep -E 'url:|src:' )
                        do
                            if [ $x != 'url:' ] && [ $x != 'src:' ] && [ $x != '""' ]
                            then
                                filename=$(basename $x)
                                if [ ! -f $prefetch_dir/$filename ]
                                then
                                    echo "====== Downloading $prefetch_dir/$filename" 
                                    curl -s -L $x -o $prefetch_dir/$filename
                                fi
                            fi
                        done
                        
#                        stack_source=$(yq r $build_dir/$fetched_index_file stacks[$stack_count].src)
#                        if [ "${stack_source}" != "null" ] && [ "${stack_source}" != "" ]
#                        then
#                            echo "stack source for $stack_id stack is '$stack_source'"
#                            if [ ! -d $base_dir/$repo_name/$stack_id ]
#                            then
#                                mkdir -p $base_dir/$repo_name/$stack_id
#                                source_file=$(basename $stack_source)
#                                (curl -s -L ${stack_source} -o $prefetch_dir/$source_file)
#                                tar -xf $prefetch_dir/$source_file -C $base_dir/$repo_name/$stack_id > /dev/null 2>&1
#                            fi
#                        fi
                    fi
                done
                    
                if [ -f  $all_stacks ]
                then
                    rm -f $all_stacks
                fi
                if [ -f  $one_stack ]
                then
                    rm -f $one_stack
                fi
                if [ -f $build_dir/$fetched_index_file ]
                then
                    rm -f $build_dir/$fetched_index_file
                fi
            done
        done
    fi
    export REPO_LIST=${REPO_LIST[@]}
    INDEX_LIST=$(echo "$INDEX_LIST" | xargs -n1 | sort -u | xargs)
    export INDEX_LIST=${INDEX_LIST[@]}
    
    if [ "$CODEWIND_INDEX" == "true" ]
    then
        python3 $script_dir/create_codewind_index.py $DISPLAY_NAME_PREFIX
    
        if [ -d ${build_dir}/index-src ]
        then
            # iterate over each repo
            for codewind_file in $assets_dir/*.json
            do
                # flat json used by static appsody-index for codewind
                index_src=$build_dir/index-src/$(basename "$codewind_file")

                sed -e "s|${RELEASE_URL}/.*/|{{EXTERNAL_URL}}/|" $codewind_file > $index_src
            done
        fi
    fi
fi