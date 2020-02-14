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
```
where:  
`name:` is an identifier for this particular configuration  
`description:` is a description of the configuration  
`version:` is a version for the configuration, may align with a repository release.  
`stacks: - name:` is the name of a repository to be built  
`stacks:   repos:` is an array of urls to stack indexes / repositories to be included in this repository index  
`stacks:   repos:    -url:    exclude:` is an array of stack names to exclude from the refrenced stack repository. This field is optional and should be left blank if filtering is not required.  
`stacks:   repos:    -url:    include:` is an array of stack names to include from the refrenced stack repository. This field is optional and should be left blank if filtering is not required.  
`image-org:` is the name of the organisation within the image registry which will store the docker images for included stacks. This field is optional and controls the behaviour of the repository build, further details are avalable below.  
`image-registry:` is the url of the image registry being used to store stack docker images. This field is optional and controls the behaviour of the repository build, further details are avalable below.  

**NOTE -** `exclude`/`include` are mutually exclusive, if both fields are populated an error will be thrown.

You can find an [example configuration](https://github.com/appsody/repo-tools/blob/master/example_config/example_repo_config.yaml) within the example_config folder.

## Generating an Appsody repository
repo-tools provides several options for generating an Appsody repository:

### 1) Composition of public stacks / repositories.
If the stacks and repositories you are including are all publically available then repo-tools can simply compose a new repository file that uses references to the existing stack asset locations. When this type of build is required simply leave the `image-org` and `image-registry` fields of your configuration empty. The composed repository files will be stored in the `assets` folder generated when the tools are run.

Further options to follow......

## Releasing the generated repositories.
Once your index files are generated they simply need hosting in a location that can be accessed by your developer tools.

To be continued.....