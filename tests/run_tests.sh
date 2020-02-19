#!/bin/bash

test_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
base_dir=$(cd "${test_dir}/.." && pwd)
test_config_dir=$(cd "${test_dir}/test_configurations" && pwd)
mkdir $test_dir/result_config
result_dir=$(cd "${test_dir}/result_config" && pwd)

for config_file in $test_dir/test_configurations/*.yaml; do
    sed -e "s#{{TEST_DIR}}#${test_dir}#g" $config_file > ./temp.yaml
    mv ./temp.yaml $config_file
done

declare -a succesful_tests
declare -a failed_tests
test_count=0
for test_file in $test_dir/*_test.yaml; do
    test_count=$((test_count+1))
    echo "Running test for configuration: $test_file"
    success="true"
    test_input=$(yq r ${test_file} input-configuration)
    test_input_file=$test_config_dir/$test_input
    echo "test input file: $test_input_file"
    $base_dir/scripts/hub_build.sh "$test_input_file"

    num_expected_results=$(yq r ${test_file} expected-results[*].output-file | wc -l)
    if [ $num_expected_results -gt 0 ] 
    then
        echo "Found $num_expected_results results"
        for ((result_count=0;result_count<$num_expected_results;result_count++)); 
        do
            #Get expected results
            result_file_name=$(yq r ${test_file} expected-results[$result_count].output-file)
            expected_stack_count=$(yq r ${test_file} expected-results[$result_count].number-of-stacks)
            expected_image_org=$(yq r ${test_file} expected-results[$result_count].image-org)
            expected_image_registry=$(yq r ${test_file} expected-results[$result_count].image-registry)
            expected_host_path=$(yq r ${test_file} expected-results[$result_count].host-path)
            declare -a included_stacks
            expected_stack_included_count=$(yq r ${test_file} expected-results[$result_count].included-stacks[*].id | wc -l)
            for ((stack_count=0;stack_count<$expected_stack_included_count;stack_count++));
            do
                included_stacks[$stack_count]=$(yq r ${test_file} expected-results[$result_count].included-stacks[$stack_count].id)
            done
            #Get actual results
            result_file=$base_dir/assets/$result_file_name
            results_stack_count=$(yq r ${result_file} stacks[*].id | wc -l)
            declare -a result_stacks
            for ((stack_count=0;stack_count<$results_stack_count;stack_count++));
            do
                result_stacks[$stack_count]=$(yq r ${result_file} stacks[$stack_count].id)
            done
            
            #To Do - Work out reading image org / image registry / host url
            
            #Compare results
            if [[ $results_stack_count -ne $expected_stack_count ]]; then
                echo "  Error - Unexpected number of stacks in result"
                success="false"
            fi
            for ((index=0;index<$expected_stack_count;index++));
            do
                expected_stack=${included_stacks[$index]}
                stack_found="false"
                for ((result_count=0;result_count<$results_stack_count;result_count++));
                do
                    result_stack=${result_stacks[$result_count]}
                    if [[ "$expected_stack" == "$result_stack" ]]; then
                        stack_found="true"
                        break
                    fi
                done
                if [[ "$stack_found" == "false" ]]; then
                    echo "  Error - Missing stack in results, stack found: $stack_found"
                    success="false"
                fi
            done

        done
        if [[ "$success" != "true" ]]; then
            echo "Test failed: $test_input"
            failed_tests+=($test_input)
        else
            echo "Test passed: $test_input"
            succesful_tests+=($test_input)
        fi
        mv $result_file $result_dir/$result_file_name
    fi
done

passed_count=${#succesful_tests[@]}
echo "RESULT: $passed_count / $test_count tests passed."
if [[ $passed_count -ne $test_count ]]; then
    echo "Failed tests: ${failed_tetss[*]}"
fi