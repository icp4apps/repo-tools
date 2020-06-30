#!/bin/bash

test_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
base_dir=$(cd "${test_dir}/../.." && pwd)
test_config_dir=$(cd "${test_dir}/test_configurations" && pwd)
if [[ ! -d "$test_dir/result_config" ]]; then
    mkdir $test_dir/result_config
fi
result_dir=$(cd "${test_dir}/result_config" && pwd)
mkdir $test_dir/exec_config
exec_config_dir=$(cd "${test_dir}/exec_config" && pwd)

expected_src_prefix="REPO_TEST_URL"

for config_file in $test_config_dir/*.yaml; do
    filename=$(basename $config_file)
    sed -e "s#{{TEST_DIR}}#${test_dir}#g" $config_file > $exec_config_dir/$filename
done

declare -a succesful_tests
declare -a failed_tests
test_count=0
for test_file in $test_dir/*_test.yaml; do
    test_filename=$(basename $test_file)
    test_filename="${test_filename%.*}"
    test_count=$((test_count+1))
    echo "Running test for configuration: $test_file"
    success="true"
    test_input=$(yq r ${test_file} input-configuration)
    test_input_file=$exec_config_dir/$test_input
    echo "test input file: $test_input_file"
    $base_dir/scripts/crd_build.sh "$test_input_file" > "$result_dir/$test_filename-output.txt"

    # Each expected result is a stack group
    num_expected_results=$(yq r ${test_file} expected-results.output-groups[*].name | wc -l)
    if [ $num_expected_results -gt 0 ] 
    then
        echo "Found $num_expected_results results"
        for ((group_count=0;group_count<$num_expected_results;group_count++)); 
        do
            # Get expected results
            expected_group_name=$(yq r ${test_file} expected-results.output-groups[$group_count].name)
            expected_file_count=$(yq r ${test_file} expected-results.output-groups[$group_count].output-file-count)
            expected_stack_count=$(yq r ${test_file} expected-results.output-groups[$group_count].included-stacks | wc -l)

            declare -a expected_stacks
            for ((stack_count=0;stack_count<$expected_stack_count;stack_count++));
            do
                expected_stacks[$stack_count]=$(yq r ${test_file} expected-results.output-groups[$group_count].included-stacks[$stack_count].id)
            done

            # Check output
            results_dir=$base_dir/build/defile_stacks

            # Result group exists
            expected_folder="$results_dir/$expected_group_name"
            if [[ ! -d "$expected_folder" ]]; then
                echo "Result group not found: $expected_group_name, folder: $expected_folder"
                success="false"
                break
            fi

            # Expected number of CRD files generated
            CRD_count=$(ls -f $results_dir/$expected_group_name/*.yaml | wc -l)
            if [ $CRD_count -ne $expected_stack_count ]; then
                echo "Number of CRD files unexpected. Found: $CRD_count, Expected: $expected_stack_count"
                success="false"
                break
            fi

            # CRDs for expected stacks present
            for (( expected_count=0;expected_count<$expected_stack_count;expected_count++));
            do
                expected_name=${expected_stacks[$expected_count]}
                expected_file="$results_dir/$expected_group_name/$expected_name-CRD.yaml"
                if [ ! -f $expected_file ]; then
                    echo "CRD file not found. Expected: $expected_file"
                    success="false"
                    break
                fi
            done
            unset expected_stacks
        done
        if [[ "$success" != "true" ]]; then
            echo "Test failed: $test_input"
            failed_tests+=($test_input)
        else
            echo "Test passed: $test_input"
            succesful_tests+=($test_input)
        fi
    fi
done
rm -rf $exec_config_dir

passed_count=${#succesful_tests[@]}
echo "RESULT: $passed_count / $test_count tests passed."
if [[ $passed_count -ne $test_count ]]; then
    echo "Failed tests: ${failed_tests[*]}"
fi