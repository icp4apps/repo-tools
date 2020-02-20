# repo-tools
This repository contains the tools and configuration templates required to compose an Appsody Repository.

## Appsody Repository
An Appsody repository is a collection of meta-data for a group of stacks. An example is the default [Appsody index](https://github.com/appsody/stacks/releases/latest/download/incubator-index.yaml).

## repo-tools structure
The repo-tools repository contains three folders:
1) config - This folder contains the configuration file that defines the content of the Appsody repository to be composed.
2) scripts - This folder contains the scripts that will compose the Appsody repository
3) example_config - This folder contains sample configuration files and previews of the resulting Appsody repository.


## Defining your configuration
Before building an Appsody repository you need to build a configuration file that identifies what you wish to include.

The format of the configuration file is as follows:

```
# Template for repo-tools configuration
name: <Repository name>
description: <Repository description> 
version: <Repository version>
stacks:
  - name: <Repository index name>
    repos:
      - url: <Reference to index file>
      exclude:
          - <stack name>
        include:
          - <stack name>
image-org: <Organisation containing images within registry>
image-registry: <Image registry hosting images>
nginx-image-name: <Image name for the generated nginx image, defaults to repo-index>
```
where:  
`name:` is an identifier for this particular configuration  
`description:` is a description of the configuration  
`version:` is a version for the configuration, may align with a repository release.  
`stacks: - name:` is the name of a repository to be built.  
`stacks:   repos:` is an array of urls to stack indexes / repositories to be included in this repository index  
`stacks:   repos:    -url:    exclude:` is an array of stack names to exclude from the refrenced stack repository. This field is optional and should be left blank if filtering is not required.  
`stacks:   repos:    -url:    include:` is an array of stack names to include from the refrenced stack repository. This field is optional and should be left blank if filtering is not required.  
`image-org:` is the name of the organisation within the image registry which will store the docker images for included stacks. This field is optional and controls the behaviour of the repository build, further details are avalable below.  
`image-registry:` is the url of the image registry being used to store stack docker images. This field is optional and controls the behaviour of the repository build, further details are avalable below.  
`nginx-image-name:` is the name assigned to the generated nginx image, defaults to repo-index.   

**NOTE -** `exclude`/`include` are mutually exclusive, if both fields are populated an error will be thrown.

You can find an [example configuration](https://github.com/appsody/repo-tools/blob/master/example_config/example_repo_config.yaml) within the example_config folder.

## Generating an Appsody repository
repo-tools provides several options for generating an Appsody repository:

### 1) Composition of public stacks / repositories.
If the stacks and repositories you are including are all publically available then repo-tools can simply compose a new repository file that uses references to the existing stack asset locations. When this type of build is required simply leave the `image-org` and `image-registry` fields of your configuration empty. The composed repository files will be stored in the `assets` folder generated when the tools are run.

### 2) Packaging private stacks / repositories.
If your stacks / repositories are hosted in a private environment that your deployment environment and tools cannot access, such as GitHub Enterprise,  you can leverage the repo-tools to create an NGINX image that can serve the assets required to make use of your stacks from within the deployment environment. When this type of build is required configure the `image-org` field to be the name of the org within your target registry and the `image-registry` field to be the URL of the actual registry the images will be placed in. You can optionally configure the name of the resulting image using the `nginx-image-name` field. Once run your local docker registry will contain the generated NGINX image which can be pushed to the registry your deployment environment will access. Once deployed the image will server the repository index files that were created as part of the build.

## Running the tools

To run the tools follow these staight forward steps:

1) Create your configuration file and place it in the config folder.
2) From the base folder of the repository run the build tool using the command `./scripts/hub_build.sh <config file>`. You do not need to specify the path to the file.
3) Once the script has completed you can host the generated assets in a location your tooling / developers can access or, if using private repositories, push the nginx image to your image registry and deploy it.