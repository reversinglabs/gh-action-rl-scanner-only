#! /bin/bash -l

# we must have the mandatory environment variables:
# RLSECURE_ENCODED_LICENSE=<base64 encoded license file>
# RLSECURE_SITE_KEY=<site key>

# we may have the environment variables:
# RLSECURE_PROXY_SERVER    Optional. Server URL for local proxy configuration.
# RLSECURE_PROXY_PORT      Optional. Network port for local proxy configuration.
# RLSECURE_PROXY_USER      Optional. User name for proxy authentication.
# RLSECURE_PROXY_PASSWORD  Optional. Password for proxy authentication.

# we need a mandatory input path to a single artifact to scan
# test if the file is readable and not empty

EXIT_FATAL=101

FILE_TO_SCAN=""
REPORT_DIR=""

usage()
{
    echo "Usage: $0 -f <file-to-scan> -r <report-directory>" >&2
    exit 1
}

fatal()
{
    local msg="$1"

    echo "description=FATAL: ${msg}" >> $GITHUB_OUTPUT
    echo "status=error" >> $GITHUB_OUTPUT
    echo "Error: $msg" >> $GITHUB_STEP_SUMMARY

    exit ${EXIT_FATAL}
}

parameters()
{
    while getopts ":f:r:" o
    do
        case "${o}" in
            f)  # the file to scan
                f=${OPTARG}
                [ ! -f "${f}" ] && {
                    echo "ERROR: the file specified '${f}' cannot be found, the file to scan must exist already" >&2
                    usage
                }
                ;;

            r) # the report directory, must not already exist
                r=${OPTARG}
                [ -e "${r}" ] && {
                    echo "ERROR: '${r}' already exists, please specify a directory path that does not yet exist" >&2
                    usage
                }
                ;;

            *)
                usage
                ;;
        esac
    done

    shift $((OPTIND-1))

    [ -z "${r}" ] && {
        r="MyReportDir"
        [ -e "${r}" ] && {
            echo "ERROR: '${r}' already exists, please specify a directory path that does not yet exist" >&2
            usage
        }
    }

    [ -z "${f}" ] && {
        echo "Error: no input file specified" >&2
        usage
    }

    FILE_TO_SCAN="${f}"
    REPORT_DIR="${r}"
}

testEnvVarsMandatory()
{
    [ -z "${RLSECURE_ENCODED_LICENSE}" ] && {
        fatal "no value provided for the mandatory environment variable: 'RLSECURE_ENCODED_LICENSE'"
    }

    [ -z "${RLSECURE_SITE_KEY}" ] && {
        fatal "no value provided for the mandatory environment variable: 'RLSECURE_SITE_KEY'"
    }
}

# ----------------------------
prepare()
{
    xFile=$( basename "${FILE_TO_SCAN}" )
    xDir=$( dirname "${FILE_TO_SCAN}" )
    xDir=$( realpath $xDir )

    rm -rf "${REPORT_DIR}"
    mkdir "${REPORT_DIR}" -m 777
    xReport=$( realpath "${REPORT_DIR}" )
}

testInputArtifactToScan()
{
    local item="${FILE_TO_SCAN}"

    [ ! -f "$item" ] && {
        fatal "file not found: '$item'"
    }

    [ ! -r "$item" ] && {
        fatal "file not readable: '$item'"
    }

    [ ! -s "$item" ] && {
        fatal "file has zero length: '$item'"
    }
}

main()
{
    parameters $*
    prepare
    testEnvVarsMandatory

    testInputArtifactToScan

    rl-scan \
        --package-path="${FILE_TO_SCAN}" \
        --report-path=${REPORT_DIR} \
        --report-format=all 2>/tmp/2 1>/tmp/1
    RR=$? # preserve the exit code for later

    # we are only interested in the PASS / FAIL line for the OUTPUT
    STATUS=$( grep "Scan result:" /tmp/1 )
    [ -z "$STATUS" ] && {
        local msg="No scan result found in the scanner command output"
        echo "::error::$msg"
        echo "description=$msg" >> $GITHUB_OUTPUT
        echo "status=error" >> $GITHUB_OUTPUT
        echo "Error: $msg" >> $GITHUB_STEP_SUMMARY

        cat /tmp/2
        cat /tmp/1
        exit 101
    }

    chmod -R o+w "${REPORT_DIR}" # so items owned by root can be removed on local runners
    
    echo "stdout"
    cat /tmp/1
    
    echo "stderr"
    cat /tmp/2
    
    if [ "$RR" != "0" ]
    then
        echo "::error::$STATUS"
        echo "status=failure" >> $GITHUB_OUTPUT
    else
        echo "::notice::$STATUS"
        echo "status=success" >> $GITHUB_OUTPUT
    fi

    echo "description=$STATUS" >> $GITHUB_OUTPUT
    echo "$STATUS" >> $GITHUB_STEP_SUMMARY
    exit $RR
}

# we pass all args to the function
main $*
