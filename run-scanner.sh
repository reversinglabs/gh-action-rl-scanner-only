#! /bin/bash

# PARAMS: passed via the environment
#
# REPORT_PATH: a optional directory path
# MY_ARTIFACT_TO_SCAN_PATH: a file path
# RL_STORE: a directory path (default "")
# RL_PACKAGE_URL: a optional purl string (default: "") # may contain @ or /
# RL_DIFF_WITH: a optional purl string (default "") # may contain @ or /
# RL_VERBOSE: a optional bool (default false)
# RLSECURE_PROXY_SERVER: a optional string (default "") # server dns or ip
# RLSECURE_PROXY_PORT: a optional string (default "") # numeric
# RLSECURE_PROXY_USER: a optional string (default "")
# RLSECURE_PROXY_PASSWORD: a optional string (default "") could contain special chars

cleanup()
{
    # suspicious chars are mainly `$><|&;
    # if $ is allowed then $( should not be allowed (exept for passwords)

    # for bool we can remove `$><|;&
    RL_VERBOSE=${RL_VERBOSE//[\`\$><|;&]/}

    # file or dir paths may not have `$><|;& so remove
    REPORT_PATH=${REPORT_PATH//[\`\$><|;&]/}
    MY_ARTIFACT_TO_SCAN_PATH=${MY_ARTIFACT_TO_SCAN_PATH//[\`\$><|;&]/}
    RL_STORE=${RL_STORE//[\`\$><|;&]/}

    # purl (name and version) may not have ` so remove
    RL_PACKAGE_URL=${RL_PACKAGE_URL//[\`]/}
    RL_DIFF_WITH=${RL_DIFF_WITH//[\`]/}

    # the proxy params are passed explicitly via the environment

    # a server is either ip4 or ip6 or dns; safe to remove $`><|;&
    RLSECURE_PROXY_SERVER=${RLSECURE_PROXY_SERVER//[\`\$><|;&]/}

    # a port is always numeric, remove all other chars
    RLSECURE_PROXY_PORT=${RLSECURE_PROXY_PORT//[^0-9]/}

    # a user may not contain: `$><|&;
    RLSECURE_PROXY_USER=${RLSECURE_PROXY_USER//[\`\$><|;&]/}

    # a pass is more difficult as it can contain almost anything
    # in this case we can export it and forward it to docker via the environment
}

do_verbose()
{
    cat <<!
REPORT_PATH:              ${REPORT_PATH:-No path specified}
MY_ARTIFACT_TO_SCAN_PATH: ${MY_ARTIFACT_TO_SCAN_PATH:-No path specified}

RL_STORE:                 ${RL_STORE:-No path specified for RL_STORE: no diff scan can be executed}
RL_PACKAGE_URL:           ${RL_PACKAGE_URL:-No package URL given: no diff scan can be executed}
RL_DIFF_WITH:             ${RL_DIFF_WITH:-No diff with was requested}

RLSECURE_PROXY_SERVER:    ${RLSECURE_PROXY_SERVER:-No proxy server was provided}
RLSECURE_PROXY_PORT:      ${RLSECURE_PROXY_PORT:-No proxy port was provided}
RLSECURE_PROXY_USER:      ${RLSECURE_PROXY_USER:-No proxy user was provided}
RLSECURE_PROXY_PASSWORD:  ${RLSECURE_PROXY_PASSWORD:-No proxy password was provided}
!
}

validate_params()
{
    if [ -z "${REPORT_PATH}" ]
    then
        echo "::error FATAL: no 'report-path' provided"
        exit 101
    fi

    if [ -z "${MY_ARTIFACT_TO_SCAN_PATH}" ]
    then
        echo "::error FATAL: no 'artifact-to-scan' provided"
        exit 101
    fi

    if [ -z "${RLSECURE_ENCODED_LICENSE}" ]
    then
        echo "::error FATAL: no 'RLSECURE_ENCODED_LICENSE' is set in your environment"
        exit 101
    fi

    if [ -z "${RLSECURE_SITE_KEY}" ]
    then
        echo "::error FATAL: no 'RLSECURE_SITE_KEY' is set in your environment"
        exit 101
    fi
}

prep_report()
{
    if [ -d "${REPORT_PATH}" ]
    then
        if rmdir "${REPORT_PATH}"
        then
            :
        else
            echo "::error FATAL: your current REPORT_PATH is not empty"
            exit 101
        fi
    fi

    mkdir -p "${REPORT_PATH}"
}

prep_paths()
{
    R_PATH=$( realpath "${REPORT_PATH}" )

    A_PATH=$( realpath "${MY_ARTIFACT_TO_SCAN_PATH}" )
    A_DIR=$( dirname "${A_PATH}" )
    A_FILE=$( basename "${A_PATH}" )

    if [ ! -z "${RL_STORE}" ]
    then
        RL_STORE=$(realpath ${RL_STORE})
    fi
}

extractProjectFromPackageUrl()
{
    echo "${RL_PACKAGE_URL}" |
    awk '{
        sub(/@.*/,"")       # remove the @Version part
        split($0, a , "/")  # we expect $Project/$Package
        print a[1]          # print Project
    }'
}

extractPackageFromPackageUrl()
{
    echo "${RL_PACKAGE_URL}" |
    awk '{
        sub(/@.*/,"")       # remove the @Version part
        split($0, a , "/")  # we expect $Project/$Package
        print a[2]          # print Package
    }'
}

makeDiffWith()
{
    DIFF_WITH=""

    if [ -z "$RL_STORE" ]
    then
        return
    fi

    if [ -z "${RL_PACKAGE_URL}" ]
    then
        return
    fi

    if [ -z "${RL_DIFF_WITH}" ]
    then
        return
    fi

    # Split the package URL and find Project and Package
    Project=$( extractProjectFromPackageUrl )
    Package=$( extractPackageFromPackageUrl )

    if [ ! -d "$RL_STORE/.rl-secure/projects/${Project}/packages/${Package}/versions/${RL_DIFF_WITH}" ]
    then
        echo "::notice That version has not been scanned yet: ${RL_DIFF_WITH} in project: ${Project} and package: ${Package}"
        echo "::notice No diff scan will be executed, only ${RL_PACKAGE_URL} will be scanned"
        return
    fi

    DIFF_WITH="--diff-with=${RL_DIFF_WITH}"
}

prep_proxy_data()
{
    PROXY_DATA=""

    # for docker we dont have to specify the value of a env var if it is already exported
    if [ ! -z "${RLSECURE_PROXY_SERVER}" ]
    then
        export RLSECURE_PROXY_SERVER
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_SERVER"
    fi

    if [ ! -z "${RLSECURE_PROXY_PORT}" ]
    then
        export RLSECURE_PROXY_PORT
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_PORT"
    fi

    if [ ! -z "${RLSECURE_PROXY_USER}" ]
    then
        export RLSECURE_PROXY_USER
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_USER"
    fi

    if [ ! -z "${RLSECURE_PROXY_PASSWORD}" ]
    then
        export RLSECURE_PROXY_PASSWORD
        PROXY_DATA="${PROXY_DATA} -e RLSECURE_PROXY_PASSWORD"
    fi
}

scan_with_store()
{
    local - # auto restore the next line on function end
    set +e # we do our own error handling in this func
    set -x

    export RLSECURE_ENCODED_LICENSE
    export RLSECURE_SITE_KEY

    # rl-store will be initialized if it is empty
    docker run --rm -u $(id -u):$(id -g) \
        -e "RLSECURE_ENCODED_LICENSE" \
        -e "RLSECURE_SITE_KEY" \
        ${PROXY_DATA} \
        -v "${A_DIR}/:/packages:ro" \
        -v "${R_PATH}/:/report" \
        -v "${RL_STORE}/:/rl-store" \
        reversinglabs/rl-scanner:latest \
            rl-scan \
                --rl-store=/rl-store \
                --purl="${RL_PACKAGE_URL}" \
                --replace \
                --package-path="/packages/${A_FILE}" \
                --report-path=/report \
                --report-format=all --pack-safe \
                ${DIFF_WITH} 1>1 2>2
    RR=$?
    STATUS=$( grep 'Scan result:' 1 )
}

scan_no_store()
{
    local - # auto restore the next line on function end
    set +e # we do our own error handling in this func

    docker run --rm -u $(id -u):$(id -g) \
        -e "RLSECURE_ENCODED_LICENSE" \
        -e "RLSECURE_SITE_KEY" \
        ${PROXY_DATA} \
        -v "${A_DIR}/:/packages:ro" \
        -v "${R_PATH}/:/report" \
        reversinglabs/rl-scanner:latest \
            rl-scan \
                --package-path="/packages/${A_FILE}" \
                --report-path=/report \
                --report-format=all --pack-safe 1>1 2>2
    RR=$?
    STATUS=$( grep 'Scan result:' 1 )
}

what_scan_type()
{
    if [ -z "${RL_STORE}" ]
    then
        return 0
    fi

    if [ -z "${RL_PACKAGE_URL}" ]
    then
        return 0
    fi

    return 1
}

showStdOutErr()
{
    echo "::notice ## Stdout of reversinglabs/rl-scanner"
    cat 1
    echo

    echo "::notice ## Stderr of reversinglabs/rl-scanner"
    cat 2
    echo
}

test_missing_status()
{
    [ -z "$STATUS" ] && {
        showStdOutErr

        msg="Fatal: cannot find the scan result in the output"
        echo "::error::$msg"
        echo "$msg" >> $GITHUB_STEP_SUMMARY

        echo "description=$msg" >> $GITHUB_OUTPUT
        echo "status=error" >> $GITHUB_OUTPUT

        exit 101
    }
}

set_status_PassFail()
{
    echo "description=$STATUS" >> $GITHUB_OUTPUT
    echo "$STATUS" >> $GITHUB_STEP_SUMMARY

    echo "$STATUS" | grep -q FAIL
    if [ "$?" == "0" ]
    then
        echo "status=failure" >> $GITHUB_OUTPUT
        echo "::error::$STATUS"
    else
        echo "status=success" >> $GITHUB_OUTPUT
        echo "::notice::$STATUS"
    fi
}

main()
{
    cleanup # sanitize input passed from the environment

    if [ "${RL_VERBOSE}" != "false" ]
    then
        do_verbose
    fi

    validate_params
    prep_report
    prep_paths
    prep_proxy_data

    makeDiffWith

    if what_scan_type
    then
        scan_no_store
    else
        scan_with_store
    fi

    if [ "${RL_VERBOSE}" != "false" ]
    then
        showStdOutErr
    fi

    test_missing_status
    set_status_PassFail

    exit ${RR}
}

main "$@"
