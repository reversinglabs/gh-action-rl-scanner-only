# ReversingLabs GitHub Action: rl-scanner-only

ReversingLabs provides officially supported GitHub Actions for faster and easier deployment of the `rl-secure` solution in CI/CD workflows.

The `rl-scanner-only` action uses the official [reversinglabs/rl-scanner](https://hub.docker.com/r/reversinglabs/rl-scanner) Docker image to scan a single build artifact with `rl-secure`, generate the analysis report, and display the analysis status as one of the checks in the GitHub interface.

This action is most suitable for experienced users who want to integrate it into more complex workflows.
If you're looking for a solution with more functionality out-of-the-box, try the ReversingLabs [rl-scanner-composite](https://github.com/reversinglabs/gh-action-rl-scanner-composite) GitHub Action.


## What is rl-secure?

`rl-secure` is a CLI tool that's part of the [Spectra Assure platform](https://www.reversinglabs.com/products/software-supply-chain-security) - a new ReversingLabs solution for software supply chain protection.

With `rl-secure`, you can:

- Scan your software release packages on-premises and in your CI/CD pipelines to prevent threats from reaching production.
- Compare package versions to ensure no vulnerabilities are introduced in the open source libraries and third-party components you use.
- Prevent private keys, tokens, credentials and other sensitive information from leaking into production.
- Improve developer experience and ensure compliance with security best practices.
- Generate actionable analysis reports to help you prioritize and remediate issues in collaboration with your DevOps and security teams.


## How this action works

The `rl-scanner-only` action relies on a few different [contexts](https://docs.github.com/en/actions/learn-github-actions/contexts) to access and reuse information across its steps.

This action expects that the build artifact is produced in the current workspace before the action is called.
It requires specifying the path of the artifact as the input to the action.
The path must be relative to the root of the GitHub repository.

Optionally, users can specify the report directory name.
If it is specified, the action saves all supported analysis report formats for the artifact into the report directory.
The directory path must be relative to the `github.workspace`.

If the report directory name is not specified, the action saves the analysis reports into the default directory.

When called, the action runs a set of commands that pull the latest version of the `reversinglabs/rl-scanner` Docker image and scan the provided artifact inside a container.
When the security scan is done, the container automatically shuts down, and the action outputs the analysis result as a status message (PASS, FAIL, ERROR).

## Requirements

1. **A valid rl-secure license with site key**. If you don't already have a site-wide deployment license, follow the instructions in [the official rl-secure documentation](https://docs.secure.software/cli/deployment/rl-deploy-quick-start#prepare-the-license-and-site-key) to get it from ReversingLabs. You don't need to activate the license - just save the license file and the site key for later use. You must convert your license file into a Base64-encoded string to use it with the Docker image.

2. **Your rl-secure license information added as secrets** to your GitHub organization or repository. Use predefined [environment variables](#environment-variables) to provide the secrets to the action.

**Note for GitHub Enterprise users:** GitHub Actions must be enabled and appropriately configured for the repository where you want to use this action. If you don't have access to the [repository settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository), contact your GitHub organization administrators for help.


## Environment variables

This action requires the `rl-secure` license data to be passed via the environment using the following environment variables.


| Environment variable | Description |
| :--------- | :------ |
| `RLSECURE_ENCODED_LICENSE` | Required. The `rl-secure` license file as a Base64-encoded string. Users must encode the contents of your license file, and provide the resulting string with this variable. |
| `RLSECURE_SITE_KEY` | Required. The `rl-secure` license site key. The site key is a string generated by ReversingLabs and sent to users with the license file. |


ReversingLabs strongly recommends following best security practices and [defining these secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#using-encrypted-secrets-in-a-workflow
) on the level of your GitHub organization or repository.


## How to use this GitHub Action

The most common use-case for this action is to add it to the "test" stage in a workflow, after the build artifact has been created.

To use the `rl-secure` security scanning functionality, a valid site-wide deployment license is required.
This type of license has two parts: the site key and the license file.
ReversingLabs sends both parts of the license to users on request.
Users must then encode the license file with the Base64 algorithm.
The Base64-encoded license string and the site key must be provided to the action using [environment variables](#environment-variables).


### Configure a package store

A package store is a special directory where `rl-secure` can permanently keep your analyzed build artifacts and their scan results.
When created, a package store is automatically organized into [a predefined structure](https://docs.secure.software/cli/commands/create#example-structure-of-a-package-store) where every analyzed artifact is registered as a **package version** and assigned a **package URL (purl)** in the format `[pkg:type/]<project></package><@version>`.

A package store is a prerequisite for [comparing build artifacts](#compare-artifacts) because the diff scan requires specifying artifacts by their package URLs and saving analysis results for each artifacts.

To configure a package store, use the `rl-store` parameter. This requires either a path on the runner (if only one runner is used) or a shared storage location with NFS or CIFS (if scanning will be performed on multiple runners). **Configuring a package store only make sense on self-hosted runners.**

When a package store is configured, you must provide the package URL (purl) with the `rl-package-url` parameter when scanning an artifact to register it in the package store.
Likewise, if you want to use the `rl-package-url` parameter, you must also set the `rl-store`.


### Compare artifacts

The `rl-secure` CLI and the `rl-scanner` Docker image both allow comparing the analysis results of two artifacts in the same `<project>/<package>` context.
This comparison is also known as the **diff scan**.

To perform a diff scan, `rl-secure` needs to preserve the results of previous scans in a package store.
When using a package store, analysis results for every scanned artifact are accessible with the package URL in the format `<project>/<package>@<version>`.
This lets you compare the scan results of an artifact against a previously scanned artifact in the same project and package.

To compare artifacts, use the `rl-diff-with` parameter when scanning an artifact to specify the package URL of a previous version to compare against.
The diff scan action will verify that the requested version was actually scanned before, and ignore the request for a diff scan if there are no results for the requested `<project>/<package>@<version>`.


### Optional proxy configuration

In some cases, proxy configuration may be needed to deploy and use `rl-secure`.
You can configure proxy settings with the `rl-proxy-*` parameters for any self-hosted runner, including local GitHub Enterprise setups.

When using the `rl-proxy-server` parameter, you must also specify the port with `rl-proxy-port`.

If the proxy requires authentication, the proxy credentials for authentication can be configured with `rl-proxy-user` and `rl-proxy-password`.

### Inputs

| Input parameter | Required | Description |
| :--------- | :------ | :------ |
| `artifact-to-scan` | Yes | The software package (build artifact) you want to scan. Provide the artifact file path relative to the `github.workspace` |
| `report-path` | No | The directory where the action will store analysis reports for the build artifact. The directory must be empty. Provide the directory path relative to the `github.workspace`. Default value is `MyReportDir` |
| `rl-store` | No | If using a package store, use this parameter to provide the path to a directory where the package store has been initialized.  |
| `rl-package-url` | No | If using a package store, use this parameter to specify the package URL (PURL) for the scanned artifact. |
| `rl-diff-with` | No | If using a package store, use this parameter to specify the PURL of a previously scanned version of the artifact to compare (diff) against. The previous version must exist in the same project and package as the scanned artifact. |
| `rl-verbose` | No | Set to`true` to provide more feedback in the output while running the scan. Disabled by default. |
| `rl-proxy-server` | No | Server URL for proxy configuration (IP address or DNS name). |
| `rl-proxy-port` | No | Network port on the proxy server for proxy configuration. Required if `rl-proxy-server` is used. |
| `rl-proxy-user` | No | User name for proxy authentication. |
| `rl-proxy-password` | No | Password for proxy authentication. Required if `rl-proxy-user` is used. |


### Outputs

| Output parameter | Description |
| :--------- | :------ |
| `description` | The result of the action - a string terminating in FAIL or PASS. |
| `status` | The single-word status (as is used by the GitHub Status API), representing the result of the action. It can be any of the following: success, failure, error. **Success** indicates that the resulting string contains PASS. **Failure** indicates the resulting string contains FAIL. **Error** indicates that something went wrong during the scan and the action was not able to retrieve the resulting string. |

### Artifacts

The action creates the reports in directory: `${{ inputs.report-path }}`.

Users can control the `report-path` as an input parameter.


## Examples

The following example is a basic GitHub workflow that runs on pull requests (PRs) and commit pushes to the `main` branch in your repository.

The workflow checks out your repository, builds an artifact, scans it with `rl-secure`, and displays the analysis results.


```
name: Example rl-secure workflow
run-name: rl-scanner-only

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  checkout-build-scan-only:
    runs-on: ubuntu-latest

    permissions:
      statuses: write
      pull-requests: write

    steps:
      # Need to check out data before we can do anything
      - uses: actions/checkout@v4

      # Replace this with your build process
      # Need to produce one file as the build artifact in scanfile=<relative file path>
      - name: Create build artifact
        id: build

        shell: bash

        run: |
          # Prepare the build process
          python3 -m pip install --upgrade pip
          pip install example
          python3 -m pip install --upgrade build
          # Run the build
          python3 -m build
          # Produce a single artifact to scan and set the scanfile output parameter
          echo "scanfile=$( ls dist/*.whl )" >> $GITHUB_OUTPUT

      # Use the rl-scanner-only action
      - name: Scan build artifact
        id: rl-scan

        env:
          RLSECURE_ENCODED_LICENSE: ${{ secrets.RLSECURE_ENCODED_LICENSE }}
          RLSECURE_SITE_KEY: ${{ secrets.RLSECURE_SITE_KEY }}

        uses: reversinglabs/gh-action-rl-scanner-only@v1

        with:
          artifact-to-scan: ${{ steps.build.outputs.scanfile }}
          report-path: "My_Report_Dir"

      # The report needs to be displayed even if the scan fails, so we're using a conditional expression to specify that
      - name: Show analysis report
        if: success() || failure()
        shell: bash
        run: |
          ls -la
          ls -l 'My_Report_Dir'
```

### Scan a build artifact

The following example will scan a build artifact called `project-1.0.1.tgz` and produce the analysis report in `${{ inputs.report-path }}/report` that can be picked up from the workspace.


```
- name: Scan packages with rl-secure
  id: scan
  env:
    RLSECURE_ENCODED_LICENSE: ${{ secrets.RLSECURE_ENCODED_LICENSE }}
    RLSECURE_SITE_KEY: ${{ secrets.RLSECURE_SITE_KEY }}
  uses: reversinglabs/gh-action-rl-scanner-only@v1
  with:
    artifact-to-scan: 'project-1.0.1.tgz'
```


### Use the output from the scan

Use an explicit `if` condition so that the status always gets extracted if the scan result is PASS or FAIL, as in the following example.


```
- name: Get the scan status output
  if: success() || failure()
  run: |
    echo "The status is: '${{ steps.scan.outputs.status }}'"
    echo "The description is: '${{ steps.scan.outputs.description }}'"

```


### Upload the analysis report

Use an explicit `if` condition so that the report always gets uploaded if the scan result is PASS or FAIL, as in the following example.

For this, you need to use the external action `actions/upload-artifact`.

```
- name: Archive the report
  if: success() || failure()
  uses: actions/upload-artifact@v3
  with:
    name: report
    path: ${{ inputs.report-path }}
```

Alternatively, you can use the [rl-scanner-composite](https://github.com/reversinglabs/gh-action-rl-scanner-composite) GitHub Action that provides a more seamless approach than `rl-scanner-only`.
It uploads the report automatically without requiring separate configuration in your workflows.
The `rl-scanner-composite` action also uploads the SARIF report for the analyzed artifacts, allowing you to manage code scanning alerts in your repository.


## Limitations

If you want to use this action in a [reusable workflow](https://docs.github.com/en/actions/using-workflows/reusing-workflows), keep in mind that such workflows don't share or inherit the workspace with any previous jobs or steps.

This action needs direct access to the build artifact.
You can only use it in a reusable workflow if a previous job that builds the artifact also uploads the artifact to GitHub.
Then the reusable workflow where you use this action needs to download the artifact and scan it.

Read more about [storing workflow data as artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts#uploading-build-and-test-artifacts) in the GitHub documentation.

## Useful resources

- The official `reversinglabs/rl-scanner` Docker image [on Docker Hub](https://hub.docker.com/r/reversinglabs/rl-scanner)
- [Supported file formats](https://docs.secure.software/concepts/filetypes) and [language coverage](https://docs.secure.software/concepts/language-coverage) for `rl-secure`
- The [rl-scanner-composite](https://github.com/reversinglabs/gh-action-rl-scanner-composite) GitHub Action
- Introduction to [secure software release processes](https://www.reversinglabs.com/solutions/secure-software-release-processes) with ReversingLabs
- [Software supply chain security for application security teams](https://3375217.fs1.hubspotusercontent-na1.net/hubfs/3375217/Documents/Business-Brief-Software-Supply-Chain-Security-for-Application-Security-Teams.pdf) (link to a PDF document)
